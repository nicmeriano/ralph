#!/bin/bash
# Ralph 2.0 - Autonomous Development Loop
# Main loop controller script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.json"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompt.md"
FEATURES_INDEX="$SCRIPT_DIR/features.json"
PROGRESS_FILE="$SCRIPT_DIR/features/progress.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
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
AUTO_SELECT_FEATURE=false

log_info() { echo -e "${BLUE}[ralph]${NC} $1"; }
log_success() { echo -e "${GREEN}[ralph]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[ralph]${NC} $1"; }
log_error() { echo -e "${RED}[ralph]${NC} $1"; }

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

parse_args() {
    FEATURE_NAME=""
    COMMAND=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            start) COMMAND="start"; AUTO_SELECT_FEATURE=true; shift ;;
            --feature) FEATURE_NAME="$2"; AUTO_SELECT_FEATURE=false; shift 2 ;;
            --once) RUN_ONCE=true; shift ;;
            --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
            --port) DASHBOARD_PORT="$2"; shift 2 ;;
            --sandbox) SANDBOX="$2"; shift 2 ;;
            --no-dashboard) DASHBOARD_AUTO_START=false; shift ;;
            -h|--help) show_help; exit 0 ;;
            -*) log_error "Unknown option: $1"; exit 1 ;;
            *) [[ -z "$FEATURE_NAME" ]] && FEATURE_NAME="$1" || { log_error "Multiple features"; exit 1; }; shift ;;
        esac
    done
}

show_help() {
    cat << EOF
Ralph 2.0 - Autonomous Development Loop

Usage:
    ralph start [options]               Auto-select feature and run loop
    ralph start --feature <name>        Run loop for specific feature
    ralph <feature-name> [options]      Run loop for feature (legacy)

Options:
    --feature <name>        Lock to specific feature (with start command)
    --once                  Run single iteration only
    --max-iterations N      Set maximum iterations
    --port N                Dashboard port (default: 3456)
    --sandbox true|false    Enable/disable Docker sandbox
    --no-dashboard          Don't auto-start the dashboard
    -h, --help              Show this help
EOF
}

# Build features index from flat *.prd.json files
build_features_index() {
    local features_dir="$SCRIPT_DIR/features"
    local index_file="$FEATURES_INDEX"
    [[ ! -d "$features_dir" ]] && { log_error "No features directory"; exit 1; }
    local features_array="[]"
    shopt -s nullglob
    for prd_file in "$features_dir"/*.prd.json; do
        if [[ -f "$prd_file" ]]; then
            local filename=$(basename "$prd_file")
            local name="${filename%.prd.json}"
            local description=$(jq -r '.description // ""' "$prd_file")
            local dependencies=$(jq -c '.dependencies // []' "$prd_file")
            # Support both tasks and userStories for backwards compatibility
            local task_count=$(jq '(.tasks // .userStories // []) | length' "$prd_file")
            local completed_count=$(jq '[(.tasks // .userStories // [])[] | select(.passes == true)] | length' "$prd_file")
            local failed_count=$(jq '[(.tasks // .userStories // [])[] | select(.status == "failed")] | length' "$prd_file")
            local status="pending"
            [[ "$completed_count" -eq "$task_count" ]] && [[ "$task_count" -gt 0 ]] && status="completed"
            [[ "$completed_count" -gt 0 ]] || [[ $(jq '[(.tasks // .userStories // [])[] | select(.status == "in_progress")] | length' "$prd_file") -gt 0 ]] && status="in_progress"
            local feature_entry=$(jq -n --arg name "$name" --arg description "$description" --arg status "$status" --argjson taskCount "$task_count" --argjson completedCount "$completed_count" --argjson failedCount "$failed_count" --argjson dependencies "$dependencies" '{name:$name,description:$description,status:$status,taskCount:$taskCount,completedCount:$completedCount,failedCount:$failedCount,dependencies:$dependencies}')
            features_array=$(echo "$features_array" | jq --argjson entry "$feature_entry" '. + [$entry]')
        fi
    done
    shopt -u nullglob
    echo "{\"features\": $features_array}" | jq '.' > "$index_file"
}

claude_select_feature() {
    build_features_index
    [[ ! -f "$FEATURES_INDEX" ]] && { log_error "Could not build features index"; exit 1; }
    local non_completed=$(jq -r '.features[] | select(.status != "completed") | .name' "$FEATURES_INDEX")
    [[ -z "$non_completed" ]] && { log_success "All features complete!"; exit 0; }
    log_info "Analyzing features..."
    local selector_prompt="$SCRIPT_DIR/feature-selector-prompt.md"
    [[ ! -f "$selector_prompt" ]] && { log_error "Feature selector prompt not found"; exit 1; }
    local output=$(claude --print -p "$(cat "$selector_prompt")" 2>&1) || true
    local selected=$(echo "$output" | grep -oP '(?<=<selected>)[^<]+(?=</selected>)' | head -1)
    [[ -z "$selected" ]] && { log_error "Claude did not select a feature"; exit 1; }
    [[ ! -f "$SCRIPT_DIR/features/$selected.prd.json" ]] && { log_error "Selected feature '$selected' does not exist"; exit 1; }
    echo "$selected"
}

validate_feature() {
    local prd_file="$SCRIPT_DIR/features/$1.prd.json"
    if [[ ! -f "$prd_file" ]]; then
        log_error "Feature '$1' not found at: $prd_file"
        log_info "Available features:"
        shopt -s nullglob
        for f in "$SCRIPT_DIR/features"/*.prd.json; do
            echo "  - $(basename "$f" .prd.json)"
        done
        shopt -u nullglob
        exit 1
    fi
}

# Support both tasks and userStories
get_task_count() { jq '(.tasks // .userStories // []) | length' "$1"; }
get_completed_count() { jq '[(.tasks // .userStories // [])[] | select(.passes == true)] | length' "$1"; }
get_failed_count() { jq '[(.tasks // .userStories // [])[] | select(.status == "failed")] | length' "$1"; }
calculate_max_iterations() {
    local task_count=$(get_task_count "$1")
    [[ -n "$MAX_ITERATIONS" ]] && echo "$MAX_ITERATIONS" || echo "scale=0; ($task_count * $MAX_ITERATIONS_MULTIPLIER) / 1" | bc
}
all_complete() { [[ "$(get_completed_count "$1")" -eq "$(get_task_count "$1")" ]]; }

show_progress() {
    local prd_file="$1" iteration="$2" max_iter="$3"
    local total=$(get_task_count "$prd_file") completed=$(get_completed_count "$prd_file") failed=$(get_failed_count "$prd_file")
    local percent=0; [[ "$total" -gt 0 ]] && percent=$((completed * 100 / total))
    local bar_width=30 filled=$((percent * bar_width / 100)) empty=$((bar_width - filled))
    local bar=""; for ((i=0; i<filled; i++)); do bar+="█"; done; for ((i=0; i<empty; i++)); do bar+="░"; done
    local current=$(jq -r '(.tasks // .userStories // [])[] | select(.status == "in_progress") | .id + ": " + .title' "$prd_file" 2>/dev/null || echo "")
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Ralph Loop Progress${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Tasks:      ${GREEN}$completed${NC}/$total"
    [[ "$failed" -gt 0 ]] && echo -e "  Failed:     ${RED}$failed${NC} tasks"
    echo -e "  Iteration:  $iteration/$max_iter"
    echo -e "  Progress:   [${GREEN}$bar${NC}] $percent%"
    [[ -n "$current" ]] && echo -e "  Current:    ${YELLOW}$current${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

start_dashboard() {
    [[ "$DASHBOARD_AUTO_START" != "true" ]] && return
    lsof -Pi :$DASHBOARD_PORT -sTCP:LISTEN -t >/dev/null 2>&1 && { log_warn "Port $DASHBOARD_PORT in use"; return; }
    log_info "Starting dashboard..."
    if command -v python3 &>/dev/null; then
        cd "$SCRIPT_DIR/dashboard"; python3 -m http.server "$DASHBOARD_PORT" >/dev/null 2>&1 & DASHBOARD_PID=$!; cd - >/dev/null
    elif command -v npx &>/dev/null; then
        npx serve "$SCRIPT_DIR/dashboard" -l "$DASHBOARD_PORT" >/dev/null 2>&1 & DASHBOARD_PID=$!
    fi
    sleep 1; echo -e "\n  ${BOLD}Dashboard:${NC} ${CYAN}http://localhost:$DASHBOARD_PORT/?feature=$1${NC}\n"
}

stop_dashboard() { [[ -n "$DASHBOARD_PID" ]] && kill "$DASHBOARD_PID" 2>/dev/null || true; }

generate_prompt() {
    local feature="$1" prd_file="$SCRIPT_DIR/features/$feature.prd.json"
    local branch_name=$(jq -r '.branchName // "ralph/'"$feature"'"' "$prd_file")
    local prompt=$(cat "$PROMPT_TEMPLATE")
    prompt="${prompt//\{\{FEATURE_NAME\}\}/$feature}"
    prompt="${prompt//\{\{BRANCH_NAME\}\}/$branch_name}"
    prompt="${prompt//\{\{PROJECT_ROOT\}\}/$PROJECT_ROOT}"
    echo "$prompt"
}

run_iteration() {
    local prompt=$(generate_prompt "$1") output=""
    log_info "Starting iteration $2..."
    if [[ "$SANDBOX" == "true" ]] && command -v docker &>/dev/null; then
        output=$(docker run --rm -i -v "$PROJECT_ROOT:/workspace" -w /workspace claude-sandbox:latest claude --print --permission-mode "$CLAUDE_PERMISSION_MODE" -p "$prompt" 2>&1) || true
    else
        output=$(claude --print --permission-mode "$CLAUDE_PERMISSION_MODE" -p "$prompt" 2>&1) || true
    fi
    echo "$output" | grep -q '<promise>COMPLETE</promise>' && return 0
    echo "$output" | grep -q '<promise>BRANCH_ERROR</promise>' && { log_error "Branch verification failed"; return 2; }
    return 1
}

create_pr() {
    local feature="$1" prd_file="$SCRIPT_DIR/features/$feature.prd.json"
    [[ "$CREATE_PR_ON_COMPLETION" != "true" ]] && return
    command -v gh &>/dev/null || { log_warn "gh CLI not found"; return; }
    local branch_name=$(jq -r '.branchName // "ralph/'"$feature"'"' "$prd_file")
    local description=$(jq -r '.description // ""' "$prd_file")
    local default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "main")
    log_info "Creating PR..."
    gh pr create --title "feat: $feature" --body "## Summary
$description

## Tasks Completed
$(jq -r '(.tasks // .userStories // [])[] | select(.passes == true) | "- [x] " + .id + ": " + .title' "$prd_file")

## Failed Tasks
$(jq -r '(.tasks // .userStories // [])[] | select(.status == "failed") | "- [ ] " + .id + ": " + .title + " (failed " + (.failureCount | tostring) + " times)"' "$prd_file")

---
Generated by Ralph Loop" --base "$default_branch" --head "$branch_name" || log_warn "PR creation failed"
}

update_iteration_count() {
    local tmp=$(mktemp); jq ".metadata.currentIteration = $2" "$1" > "$tmp"; mv "$tmp" "$1"
}

cleanup() { stop_dashboard; }
trap cleanup EXIT

main() {
    load_config
    parse_args "$@"
    if [[ "$COMMAND" == "start" ]] && [[ "$AUTO_SELECT_FEATURE" == "true" ]] && [[ -z "$FEATURE_NAME" ]]; then
        log_info "Auto-selecting feature..."
        FEATURE_NAME=$(claude_select_feature)
        [[ -z "$FEATURE_NAME" ]] && { log_error "No eligible features found"; exit 1; }
        log_success "Selected feature: $FEATURE_NAME"
    fi
    [[ -z "$FEATURE_NAME" ]] && { log_error "No feature provided"; show_help; exit 1; }
    validate_feature "$FEATURE_NAME"

    local prd_file="$SCRIPT_DIR/features/$FEATURE_NAME.prd.json"
    local max_iter=$(calculate_max_iterations "$prd_file")
    local tmp=$(mktemp); jq ".metadata.maxIterations = $max_iter" "$prd_file" > "$tmp"; mv "$tmp" "$prd_file"

    echo -e "\n${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║               Ralph 2.0 - Development Loop                ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "  Feature:     ${CYAN}$FEATURE_NAME${NC}"
    echo -e "  Mode:        ${RUN_ONCE:+Single iteration}${RUN_ONCE:-Loop (max $max_iter iterations)}"
    echo -e "  Sandbox:     $SANDBOX\n"

    start_dashboard "$FEATURE_NAME"

    local branch_name=$(jq -r '.branchName // "ralph/'"$FEATURE_NAME"'"' "$prd_file")
    git rev-parse --verify "$branch_name" >/dev/null 2>&1 || git checkout -b "$branch_name" 2>/dev/null || true
    git checkout "$branch_name" 2>/dev/null || true

    if [[ "$RUN_ONCE" == "true" ]]; then
        show_progress "$prd_file" 1 1
        run_iteration "$FEATURE_NAME" 1
        log_success "Single iteration complete"
    else
        local iteration=1
        while [[ $iteration -le $max_iter ]]; do
            show_progress "$prd_file" "$iteration" "$max_iter"
            all_complete "$prd_file" && { log_success "All tasks complete!"; create_pr "$FEATURE_NAME"; break; }
            update_iteration_count "$prd_file" "$iteration"
            local result=0
            run_iteration "$FEATURE_NAME" "$iteration" || result=$?
            [[ $result -eq 0 ]] && { log_success "Feature complete!"; create_pr "$FEATURE_NAME"; break; }
            [[ $result -eq 2 ]] && { log_error "Stopping due to branch error"; break; }
            ((iteration++))
        done
        [[ $iteration -gt $max_iter ]] && { log_warn "Max iterations reached"; log_info "Progress: $(get_completed_count "$prd_file")/$(get_task_count "$prd_file") completed, $(get_failed_count "$prd_file") failed"; }
    fi

    show_progress "$prd_file" "$iteration" "$max_iter"
    build_features_index
    log_success "Ralph loop finished"
}

main "$@"
