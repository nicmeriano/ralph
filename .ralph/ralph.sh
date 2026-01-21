#!/bin/bash
# Ralph 2.0 - Autonomous Development Loop
# Main loop controller script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.json"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompt.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
SANDBOX=true
DASHBOARD_PORT=3456
DASHBOARD_AUTO_START=true
MAX_ITERATIONS_MULTIPLIER=1.5
CLAUDE_MODEL="sonnet"
CLAUDE_PERMISSION_MODE="acceptEdits"
CREATE_PR_ON_COMPLETION=true
RUN_ONCE=false
MAX_ITERATIONS=""
DASHBOARD_PID=""

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[ralph]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ralph]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[ralph]${NC} $1"
}

log_error() {
    echo -e "${RED}[ralph]${NC} $1"
}

# Load configuration from config.json
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        SANDBOX=$(jq -r '.sandbox // true' "$CONFIG_FILE")
        DASHBOARD_PORT=$(jq -r '.dashboardPort // 3456' "$CONFIG_FILE")
        DASHBOARD_AUTO_START=$(jq -r '.dashboardAutoStart // true' "$CONFIG_FILE")
        MAX_ITERATIONS_MULTIPLIER=$(jq -r '.maxIterationsMultiplier // 1.5' "$CONFIG_FILE")
        CLAUDE_MODEL=$(jq -r '.claudeModel // "sonnet"' "$CONFIG_FILE")
        CLAUDE_PERMISSION_MODE=$(jq -r '.claudePermissionMode // "acceptEdits"' "$CONFIG_FILE")
        CREATE_PR_ON_COMPLETION=$(jq -r '.createPROnCompletion // true' "$CONFIG_FILE")
    fi
}

# Parse command line arguments
parse_args() {
    FEATURE_NAME=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --once)
                RUN_ONCE=true
                shift
                ;;
            --max-iterations)
                MAX_ITERATIONS="$2"
                shift 2
                ;;
            --port)
                DASHBOARD_PORT="$2"
                shift 2
                ;;
            --sandbox)
                SANDBOX="$2"
                shift 2
                ;;
            --no-dashboard)
                DASHBOARD_AUTO_START=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$FEATURE_NAME" ]]; then
                    FEATURE_NAME="$1"
                else
                    log_error "Multiple feature names provided"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

show_help() {
    cat << EOF
${BOLD}Ralph 2.0 - Autonomous Development Loop${NC}

${BOLD}Usage:${NC}
    ralph <feature-name> [options]

${BOLD}Options:${NC}
    --once                  Run single iteration only
    --max-iterations N      Set maximum iterations (default: stories * 1.5)
    --port N                Dashboard port (default: 3456)
    --sandbox true|false    Enable/disable Docker sandbox (default: true)
    --no-dashboard          Don't auto-start the dashboard
    -h, --help              Show this help message

${BOLD}Examples:${NC}
    ralph auth-feature              # Run loop for auth-feature
    ralph auth-feature --once       # Single iteration
    ralph auth-feature --max-iterations 15
    ralph auth-feature --sandbox false

${BOLD}Configuration:${NC}
    All options can be set in .ralph/config.json
    CLI arguments override config values
EOF
}

# Validate feature exists
validate_feature() {
    local feature="$1"
    local prd_file="$SCRIPT_DIR/features/$feature/prd.json"

    if [[ ! -f "$prd_file" ]]; then
        log_error "Feature '$feature' not found"
        log_error "Expected PRD at: $prd_file"
        echo ""
        log_info "Available features:"
        if [[ -d "$SCRIPT_DIR/features" ]]; then
            for dir in "$SCRIPT_DIR/features"/*; do
                if [[ -d "$dir" ]] && [[ -f "$dir/prd.json" ]]; then
                    echo "  - $(basename "$dir")"
                fi
            done
        else
            echo "  (none)"
        fi
        exit 1
    fi
}

# Get story count from PRD
get_story_count() {
    local prd_file="$1"
    jq '.userStories | length' "$prd_file"
}

# Get completed story count
get_completed_count() {
    local prd_file="$1"
    jq '[.userStories[] | select(.passes == true)] | length' "$prd_file"
}

# Calculate max iterations
calculate_max_iterations() {
    local prd_file="$1"
    local story_count=$(get_story_count "$prd_file")

    if [[ -n "$MAX_ITERATIONS" ]]; then
        echo "$MAX_ITERATIONS"
    else
        echo "scale=0; ($story_count * $MAX_ITERATIONS_MULTIPLIER) / 1" | bc
    fi
}

# Check if all stories are complete
all_complete() {
    local prd_file="$1"
    local total=$(get_story_count "$prd_file")
    local completed=$(get_completed_count "$prd_file")

    [[ "$completed" -eq "$total" ]]
}

# Show progress bar
show_progress() {
    local prd_file="$1"
    local iteration="$2"
    local max_iter="$3"

    local total=$(get_story_count "$prd_file")
    local completed=$(get_completed_count "$prd_file")
    local percent=0

    if [[ "$total" -gt 0 ]]; then
        percent=$((completed * 100 / total))
    fi

    local bar_width=30
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # Get current story info
    local current_story=$(jq -r '.userStories[] | select(.status == "in_progress") | .id + ": " + .title' "$prd_file" 2>/dev/null || echo "")

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Ralph Loop Progress${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Stories:    ${GREEN}$completed${NC}/$total completed"
    echo -e "  Iteration:  $iteration/$max_iter"
    echo -e "  Progress:   [${GREEN}$bar${NC}] $percent%"
    if [[ -n "$current_story" ]]; then
        echo -e "  Current:    ${YELLOW}$current_story${NC}"
    fi
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Start dashboard server
start_dashboard() {
    local feature="$1"

    if [[ "$DASHBOARD_AUTO_START" != "true" ]]; then
        return
    fi

    # Check if port is already in use
    if lsof -Pi :$DASHBOARD_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warn "Port $DASHBOARD_PORT already in use, dashboard may already be running"
        return
    fi

    log_info "Starting dashboard..."

    # Try python first, then npx serve
    if command -v python3 &> /dev/null; then
        cd "$SCRIPT_DIR/dashboard"
        python3 -m http.server "$DASHBOARD_PORT" > /dev/null 2>&1 &
        DASHBOARD_PID=$!
        cd - > /dev/null
    elif command -v npx &> /dev/null; then
        npx serve "$SCRIPT_DIR/dashboard" -l "$DASHBOARD_PORT" > /dev/null 2>&1 &
        DASHBOARD_PID=$!
    else
        log_warn "No server available (python3 or npx), dashboard disabled"
        return
    fi

    sleep 1
    echo ""
    echo -e "  ${BOLD}Dashboard:${NC} ${CYAN}http://localhost:$DASHBOARD_PORT/?feature=$feature${NC}"
    echo ""
}

# Stop dashboard server
stop_dashboard() {
    if [[ -n "$DASHBOARD_PID" ]]; then
        kill "$DASHBOARD_PID" 2>/dev/null || true
    fi
}

# Generate prompt from template
generate_prompt() {
    local feature="$1"
    local prd_file="$SCRIPT_DIR/features/$feature/prd.json"
    local branch_name=$(jq -r '.branchName // "ralph/'"$feature"'"' "$prd_file")

    local prompt=$(cat "$PROMPT_TEMPLATE")
    prompt="${prompt//\{\{FEATURE_NAME\}\}/$feature}"
    prompt="${prompt//\{\{BRANCH_NAME\}\}/$branch_name}"
    prompt="${prompt//\{\{PROJECT_ROOT\}\}/$PROJECT_ROOT}"

    echo "$prompt"
}

# Run single iteration
run_iteration() {
    local feature="$1"
    local iteration="$2"
    local prompt=$(generate_prompt "$feature")
    local output=""

    log_info "Starting iteration $iteration..."

    if [[ "$SANDBOX" == "true" ]]; then
        # Run with Docker sandbox
        if command -v docker &> /dev/null; then
            output=$(docker run --rm -i \
                -v "$PROJECT_ROOT:/workspace" \
                -w /workspace \
                claude-sandbox:latest \
                claude --print --permission-mode "$CLAUDE_PERMISSION_MODE" -p "$prompt" 2>&1) || true
        else
            log_warn "Docker not available, falling back to direct execution"
            output=$(claude --print --permission-mode "$CLAUDE_PERMISSION_MODE" -p "$prompt" 2>&1) || true
        fi
    else
        # Direct execution without sandbox
        output=$(claude --print --permission-mode "$CLAUDE_PERMISSION_MODE" -p "$prompt" 2>&1) || true
    fi

    # Check for completion signal
    if echo "$output" | grep -q '<promise>COMPLETE</promise>'; then
        return 0  # All done
    fi

    return 1  # Continue loop
}

# Create PR on completion
create_pr() {
    local feature="$1"
    local prd_file="$SCRIPT_DIR/features/$feature/prd.json"
    local branch_name=$(jq -r '.branchName // "ralph/'"$feature"'"' "$prd_file")
    local description=$(jq -r '.description // ""' "$prd_file")

    if [[ "$CREATE_PR_ON_COMPLETION" != "true" ]]; then
        return
    fi

    if ! command -v gh &> /dev/null; then
        log_warn "GitHub CLI not available, skipping PR creation"
        return
    fi

    log_info "Creating pull request..."

    # Get default branch
    local default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "main")

    # Create PR
    gh pr create \
        --title "feat: $feature" \
        --body "## Summary
$description

## Stories Completed
$(jq -r '.userStories[] | "- [x] " + .id + ": " + .title' "$prd_file")

---
🤖 Generated by Ralph Loop" \
        --base "$default_branch" \
        --head "$branch_name" || log_warn "PR creation failed (may already exist)"
}

# Update iteration count in PRD
update_iteration_count() {
    local prd_file="$1"
    local iteration="$2"

    local tmp_file=$(mktemp)
    jq ".metadata.currentIteration = $iteration" "$prd_file" > "$tmp_file"
    mv "$tmp_file" "$prd_file"
}

# Cleanup on exit
cleanup() {
    stop_dashboard
}

trap cleanup EXIT

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Load config first
    load_config

    # Parse CLI args (overrides config)
    parse_args "$@"

    # Validate feature name provided
    if [[ -z "$FEATURE_NAME" ]]; then
        log_error "No feature name provided"
        show_help
        exit 1
    fi

    # Validate feature exists
    validate_feature "$FEATURE_NAME"

    local prd_file="$SCRIPT_DIR/features/$FEATURE_NAME/prd.json"
    local max_iter=$(calculate_max_iterations "$prd_file")

    # Update max iterations in PRD
    local tmp_file=$(mktemp)
    jq ".metadata.maxIterations = $max_iter" "$prd_file" > "$tmp_file"
    mv "$tmp_file" "$prd_file"

    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║               Ralph 2.0 - Development Loop                ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Feature:     ${CYAN}$FEATURE_NAME${NC}"
    echo -e "  Mode:        ${RUN_ONCE:+Single iteration}${RUN_ONCE:-Loop (max $max_iter iterations)}"
    echo -e "  Sandbox:     ${SANDBOX}"
    echo ""

    # Start dashboard
    start_dashboard "$FEATURE_NAME"

    # Get branch name and switch to it
    local branch_name=$(jq -r '.branchName // "ralph/'"$FEATURE_NAME"'"' "$prd_file")

    # Ensure we're on the feature branch
    if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        log_info "Creating branch: $branch_name"
        git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"
    else
        git checkout "$branch_name" 2>/dev/null || true
    fi

    if [[ "$RUN_ONCE" == "true" ]]; then
        # Single iteration mode
        show_progress "$prd_file" 1 1
        run_iteration "$FEATURE_NAME" 1
        log_success "Single iteration complete"
    else
        # Loop mode
        local iteration=1

        while [[ $iteration -le $max_iter ]]; do
            show_progress "$prd_file" "$iteration" "$max_iter"

            # Check if already complete
            if all_complete "$prd_file"; then
                log_success "All stories complete!"
                create_pr "$FEATURE_NAME"
                break
            fi

            update_iteration_count "$prd_file" "$iteration"

            if run_iteration "$FEATURE_NAME" "$iteration"; then
                log_success "Feature complete! All stories passing."
                create_pr "$FEATURE_NAME"
                break
            fi

            ((iteration++))
        done

        if [[ $iteration -gt $max_iter ]]; then
            log_warn "Max iterations ($max_iter) reached"
            local completed=$(get_completed_count "$prd_file")
            local total=$(get_story_count "$prd_file")
            log_info "Progress: $completed/$total stories completed"
        fi
    fi

    # Final progress
    show_progress "$prd_file" "$iteration" "$max_iter"

    log_success "Ralph loop finished"
}

main "$@"
