#!/bin/bash
# Ralph 2.0 - Global Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<repo>/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           Ralph 2.0 - Global Installer                    ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Installation directories
RALPH_HOME="$HOME/.ralph"
BIN_DIR="$HOME/.local/bin"
SKILL_DIR_PLAN="$HOME/.claude/skills/ralph-plan"
SKILL_DIR_START="$HOME/.claude/skills/ralph-start"
SKILL_DIR_START_ONCE="$HOME/.claude/skills/ralph-start-once"

# Create directories
echo -e "${BLUE}[1/6]${NC} Creating directories..."
mkdir -p "$RALPH_HOME/templates"
mkdir -p "$RALPH_HOME/dashboard"
mkdir -p "$BIN_DIR"
mkdir -p "$SKILL_DIR_PLAN"
mkdir -p "$SKILL_DIR_START"
mkdir -p "$SKILL_DIR_START_ONCE"

# ============================================================================
# Create ralph CLI command
# ============================================================================
echo -e "${BLUE}[2/6]${NC} Installing ralph CLI..."

cat > "$BIN_DIR/ralph" << 'RALPH_CLI'
#!/bin/bash
# Ralph 2.0 CLI

set -e

RALPH_HOME="$HOME/.ralph"

show_help() {
    cat << EOF
Ralph 2.0 - Autonomous Development Loop

Usage:
    ralph init                              Initialize .ralph/ in current project
    ralph start                             Auto-select feature and run loop
    ralph start --feature <name>            Run loop for specific feature
    ralph <feature-name> [options]          Run loop for feature (legacy)

Commands:
    init            Initialize .ralph/ directory in current project
    start           Auto-select a feature based on dependencies and run
    <feature>       Run the development loop for the specified feature (legacy)

Options:
    --feature <name>        Lock to specific feature (with start command)
    --once                  Run single iteration only
    --max-iterations N      Set maximum iterations (default: tasks * 1.5)
    --port N                Dashboard port (default: 3456)
    --sandbox true|false    Enable/disable Docker sandbox (default: true)
    --no-dashboard          Don't auto-start the dashboard
    -h, --help              Show this help message

Examples:
    ralph init
    ralph start                         # Auto-select feature
    ralph start --feature auth-system   # Run specific feature
    ralph auth-feature                  # Legacy syntax
    ralph auth-feature --once
    ralph auth-feature --max-iterations 15

For more info: https://github.com/<repo>
EOF
}

init_ralph() {
    if [[ -d ".ralph" ]]; then
        echo "Ralph already initialized in this project (.ralph/ exists)"
        exit 1
    fi

    echo "Initializing Ralph in $(pwd)..."

    # Create directory structure
    mkdir -p .ralph/features
    mkdir -p .ralph/dashboard
    mkdir -p .ralph/templates

    # Copy templates from global installation
    if [[ -d "$RALPH_HOME" ]]; then
        cp "$RALPH_HOME/ralph.sh" .ralph/
        cp "$RALPH_HOME/ralph-once.sh" .ralph/
        cp "$RALPH_HOME/prompt.md" .ralph/
        cp "$RALPH_HOME/feature-selector-prompt.md" .ralph/
        cp "$RALPH_HOME/config.json" .ralph/
        cp "$RALPH_HOME/dashboard/index.html" .ralph/dashboard/
        cp "$RALPH_HOME/templates/"* .ralph/templates/

        # Create cumulative progress file
        cp "$RALPH_HOME/templates/progress.template.txt" .ralph/features/progress.txt

        chmod +x .ralph/ralph.sh
        chmod +x .ralph/ralph-once.sh
    else
        echo "Error: Ralph templates not found at $RALPH_HOME"
        echo "Please reinstall Ralph"
        exit 1
    fi

    echo ""
    echo "✅ Ralph initialized successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Use /ralph:plan in Claude Code to generate features from a plan"
    echo "  2. Or manually create: .ralph/features/my-feature.prd.json"
    echo "  3. Run: ralph start --feature my-feature"
    echo ""
}

# Main logic
case "${1:-}" in
    "")
        show_help
        exit 0
        ;;
    "init")
        init_ralph
        ;;
    "-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        # Run the feature loop
        if [[ ! -f ".ralph/ralph.sh" ]]; then
            echo "Error: Not a Ralph project (no .ralph/ralph.sh found)"
            echo "Run 'ralph init' first"
            exit 1
        fi
        exec .ralph/ralph.sh "$@"
        ;;
esac
RALPH_CLI

chmod +x "$BIN_DIR/ralph"

# ============================================================================
# Create template files
# ============================================================================
echo -e "${BLUE}[3/6]${NC} Installing templates..."

# ralph.sh (main loop script)
cat > "$RALPH_HOME/ralph.sh" << 'RALPH_SH'
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
🤖 Generated by Ralph Loop" --base "$default_branch" --head "$branch_name" || log_warn "PR creation failed"
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
RALPH_SH

chmod +x "$RALPH_HOME/ralph.sh"

# ralph-once.sh
cat > "$RALPH_HOME/ralph-once.sh" << 'RALPH_ONCE'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/ralph.sh" "$@" --once
RALPH_ONCE

chmod +x "$RALPH_HOME/ralph-once.sh"

# feature-selector-prompt.md
cat > "$RALPH_HOME/feature-selector-prompt.md" << 'SELECTOR_MD'
# Feature Selection Agent

Analyze available features and select the best one to work on.

## Input

Read `.ralph/features.json` to see all features with their status, descriptions, and dependencies.

## Selection Priority (in order)

### 1. Resume in-progress work
Any feature with `status: "in_progress"` takes highest priority - always resume unfinished work.

### 2. Check explicit dependencies FIRST
For `pending` features, check the `dependencies` array.

**A feature is BLOCKED if:**
- It has dependencies listed in its `dependencies` array
- ANY of those dependencies has `status` != `"completed"`

**Skip blocked features** and move to the next candidate.

### 3. Infer dependencies from names and descriptions (fallback)
If no explicit `dependencies` array exists, analyze names and descriptions to determine logical order.

**Foundation/Setup features FIRST** - look for keywords like:
- "setup", "init", "initialize", "scaffold", "bootstrap"
- "project", "foundation", "infrastructure", "config"

### 4. Skip problematic features
- Skip features with `status: "completed"`
- Consider skipping features with >50% failure rate

## Output

Output ONLY the selected feature name wrapped in tags:
```
<selected>feature-name</selected>
```

No other output. Just the tag with the feature name.
SELECTOR_MD

# config.json
cat > "$RALPH_HOME/config.json" << 'CONFIG_JSON'
{
  "sandbox": true,
  "dashboardPort": 3456,
  "dashboardAutoStart": true,
  "maxIterationsMultiplier": 1.5,
  "claudeModel": "sonnet",
  "claudePermissionMode": "acceptEdits",
  "commitPrefix": "feat",
  "coAuthor": "Ralph Loop <ralph@loop.dev>",
  "testCommands": {
    "default": "npm test",
    "typecheck": "npm run typecheck",
    "lint": "npm run lint"
  },
  "createPROnCompletion": true,
  "browserTesting": {
    "enabled": false,
    "devServerCommand": "npm run dev",
    "devServerPort": 3000,
    "waitForServerMs": 5000
  }
}
CONFIG_JSON

# prompt.md
cat > "$RALPH_HOME/prompt.md" << 'PROMPT_MD'
# Ralph Iteration Agent

You are Ralph, an autonomous development agent working on feature **{{FEATURE_NAME}}** on branch **{{BRANCH_NAME}}**.

## Your Mission

Complete one task per iteration. You decide which task to work on based on priority, dependencies, and what makes sense given the codebase patterns.

## Files to Read First

1. `.ralph/features/progress.txt` - **READ THE CODEBASE PATTERNS SECTION FIRST**
2. `.ralph/features/{{FEATURE_NAME}}.prd.json` - The PRD with all tasks

## Iteration Protocol

### Step 0: Verify Branch

```bash
current_branch=$(git branch --show-current)
expected_branch="{{BRANCH_NAME}}"

if [[ "$current_branch" != "$expected_branch" ]]; then
    git checkout "$expected_branch" || git checkout -b "$expected_branch"
fi
```

**If branch switch fails:** Output `<promise>BRANCH_ERROR</promise>` and exit.

### Step 1: Understand Context
- Read `progress.txt` patterns section first
- Read the PRD to see all tasks
- Read `AGENTS.md` if it exists

### Step 2: Select a Task

Pick the highest priority task where `passes: false`. Consider dependencies and logical order.

**Handling Failed Tasks:**
- If `failureCount >= 3`, **skip the task** - it needs human intervention
- When retrying, address the specific `lastFailureReason`

### Step 3: Mark Task In Progress
Update the PRD: set `status` to `"in_progress"`

### Step 4: Implement the Task
Follow acceptance criteria. Use discovered patterns. Keep changes minimal.
Respect the `estimatedFiles` field.

### Step 5: Verify
Run typecheck/tests/lint as applicable.

### Step 6: Update Documentation (MANDATORY)
If you have learnings, add them to `AGENTS.md` in the project root.

### Step 7: Record Outcome

**If PASSES:**
1. Set `status` to `"done"`, `passes` to `true`, `completedAt` to ISO timestamp
2. Commit: `git commit -m "feat: [ID] - [Title]

   Co-Authored-By: Ralph Loop <ralph@loop.dev>"`

**If FAILS:**
1. Set `status` to `"failed"`, increment `failureCount`, set `lastFailureReason`
2. Don't commit broken code
3. Revert: `git checkout -- .`

### Step 8: Log Learnings
Append to `.ralph/features/progress.txt`

### Step 9: Check Completion
If ALL tasks have `passes: true`, output:
```
<promise>COMPLETE</promise>
```

## PRD Schema Reference

```json
{
  "name": "feature-name",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "dependencies": ["other-feature"],
  "tasks": [
    {
      "id": "T-001",
      "title": "Task title",
      "description": "What this task accomplishes",
      "category": "core|api|ui|logic|testing|config",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending|in_progress|done|failed",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ]
}
```
PROMPT_MD

# prd.template.json
cat > "$RALPH_HOME/templates/prd.template.json" << 'PRD_TEMPLATE'
{
  "name": "{{FEATURE_NAME}}",
  "branchName": "ralph/{{FEATURE_NAME}}",
  "description": "Feature description goes here",
  "dependencies": [],
  "createdAt": "{{CREATED_AT}}",
  "updatedAt": "{{CREATED_AT}}",
  "tasks": [
    {
      "id": "T-001",
      "title": "Task title",
      "description": "What this task accomplishes",
      "category": "core",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ],
  "metadata": {
    "totalTasks": 1,
    "completedTasks": 0,
    "failedTasks": 0,
    "currentIteration": 0,
    "maxIterations": 2
  }
}
PRD_TEMPLATE

# progress.template.txt (cumulative format)
cat > "$RALPH_HOME/templates/progress.template.txt" << 'PROGRESS_TEMPLATE'
# Ralph Progress Log

## Codebase Patterns
<!--
Shared patterns discovered across all features.
Future iterations should read this section FIRST.
-->

- (No patterns discovered yet)

---

<!-- Feature sections are appended below as work progresses -->
PROGRESS_TEMPLATE

# ============================================================================
# Create dashboard
# ============================================================================
echo -e "${BLUE}[4/6]${NC} Installing dashboard..."

cat > "$RALPH_HOME/dashboard/index.html" << 'DASHBOARD_HTML'
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ralph Dashboard</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/basecoatui/dist/basecoat.min.css">
    <style>
        :root { --ralph-primary: #6366f1; --ralph-success: #22c55e; --ralph-failed: #dc2626; }
        body { min-height: 100vh; background: var(--background); font-family: system-ui, sans-serif; }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; }
        .logo { display: flex; align-items: center; gap: 0.75rem; }
        .logo-icon { width: 40px; height: 40px; background: linear-gradient(135deg, var(--ralph-primary), #a855f7); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; }
        .logo-text { font-size: 1.5rem; font-weight: 700; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
        .stat-card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; }
        .stat-label { font-size: 0.875rem; color: var(--muted-foreground); margin-bottom: 0.5rem; }
        .stat-value { font-size: 2rem; font-weight: 700; }
        .progress-section { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem; }
        .progress-bar-container { background: var(--muted); border-radius: 9999px; height: 12px; overflow: hidden; margin-top: 1rem; }
        .progress-bar-fill { height: 100%; background: linear-gradient(90deg, var(--ralph-primary), #a855f7); border-radius: 9999px; transition: width 0.5s; }
        .current-task-banner { background: linear-gradient(135deg, var(--ralph-primary), #a855f7); border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem; color: white; }
        .current-task-banner.empty { background: var(--card); border: 1px solid var(--border); color: var(--muted-foreground); }
        .pulse { animation: pulse 2s infinite; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.7; } }
        .task-list { display: flex; flex-direction: column; gap: 1rem; }
        .task-card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.25rem; }
        .task-card.in-progress { border-color: var(--ralph-primary); border-width: 2px; }
        .task-card.done { border-color: var(--ralph-success); opacity: 0.8; }
        .task-card.failed { border-color: var(--ralph-failed); background: rgba(220, 38, 38, 0.05); }
        .task-header { display: flex; justify-content: space-between; margin-bottom: 0.75rem; }
        .task-id { font-family: monospace; font-size: 0.75rem; color: var(--muted-foreground); }
        .task-title { font-weight: 600; margin-bottom: 0.5rem; }
        .badge { display: inline-flex; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 500; }
        .badge-pending { background: var(--muted); color: var(--muted-foreground); }
        .badge-in-progress { background: var(--ralph-primary); color: white; }
        .badge-done { background: var(--ralph-success); color: white; }
        .badge-failed { background: var(--ralph-failed); color: white; }
        .no-feature { text-align: center; padding: 4rem 2rem; color: var(--muted-foreground); }
        .refresh-indicator { display: flex; align-items: center; gap: 0.5rem; font-size: 0.75rem; color: var(--muted-foreground); }
        .refresh-dot { width: 8px; height: 8px; background: var(--ralph-success); border-radius: 50%; animation: blink 2s infinite; }
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
        .failure-box { margin-top: 0.75rem; padding: 0.75rem; background: rgba(220, 38, 38, 0.1); border: 1px solid var(--ralph-failed); border-radius: 8px; font-size: 0.875rem; }
    </style>
</head>
<body>
    <div class="container" id="app">
        <header class="header">
            <div class="logo"><div class="logo-icon">🤖</div><span class="logo-text">Ralph Dashboard</span></div>
            <div style="display:flex;align-items:center;gap:1rem;">
                <select id="feature-select" class="input" style="min-width:200px;"><option value="">Select feature...</option></select>
                <div class="refresh-indicator"><div class="refresh-dot"></div><span>Auto-refresh</span></div>
            </div>
        </header>
        <div id="content"><div class="no-feature"><h2>No Feature Selected</h2><p>Add <code>?feature=name</code> to URL</p></div></div>
    </div>
    <script>
        const urlParams = new URLSearchParams(window.location.search);
        const feature = urlParams.get('feature');
        if (feature) { document.getElementById('feature-select').innerHTML = `<option value="${feature}" selected>${feature}</option>`; loadData(); }
        async function loadData() {
            try {
                // Flat file structure: features/<name>.prd.json
                const prd = await (await fetch(`../features/${feature}.prd.json`)).json();
                let progress = 'No activity yet.';
                try { progress = await (await fetch(`../features/progress.txt`)).text(); } catch(e) {}
                render(prd, progress);
            } catch(e) { document.getElementById('content').innerHTML = `<div class="no-feature"><h2>Feature Not Found</h2><p>${e.message}</p></div>`; }
        }
        function render(prd, progress) {
            // Support both tasks and userStories for backwards compatibility
            const tasks = prd.tasks || prd.userStories || [], total = tasks.length;
            const completed = tasks.filter(s=>s.passes).length;
            const failed = tasks.filter(s=>s.status==='failed').length;
            const percent = total > 0 ? Math.round((completed/total)*100) : 0;
            const inProgress = tasks.find(s=>s.status==='in_progress');
            document.getElementById('content').innerHTML = `
                <div class="stats-grid">
                    <div class="stat-card"><div class="stat-label">Completed</div><div class="stat-value" style="color:var(--ralph-success)">${completed}/${total}</div></div>
                    <div class="stat-card"><div class="stat-label">Failed</div><div class="stat-value" style="color:${failed > 0 ? 'var(--ralph-failed)' : 'var(--muted-foreground)'}">${failed}</div></div>
                    <div class="stat-card"><div class="stat-label">Iteration</div><div class="stat-value">${prd.metadata?.currentIteration||0}/${prd.metadata?.maxIterations||'-'}</div></div>
                    <div class="stat-card"><div class="stat-label">Progress</div><div class="stat-value">${percent}%</div></div>
                </div>
                <div class="progress-section"><div style="display:flex;justify-content:space-between"><span>Progress</span><span>${percent}%</span></div><div class="progress-bar-container"><div class="progress-bar-fill" style="width:${percent}%"></div></div></div>
                ${inProgress ? `<div class="current-task-banner pulse"><div style="font-size:0.75rem;opacity:0.8">Currently Working On</div><div style="font-size:1.25rem;font-weight:600">${inProgress.id}: ${inProgress.title}</div></div>` : '<div class="current-task-banner empty">No task in progress</div>'}
                <div class="task-list">${tasks.map(s=>`<div class="task-card ${s.status}"><div class="task-header"><div><span class="task-id">${s.id}</span><div class="task-title">${s.title}</div></div><span class="badge badge-${s.status}">${formatStatus(s.status)}</span></div>${s.status === 'failed' && s.lastFailureReason ? `<div class="failure-box"><strong style="color:var(--ralph-failed)">❌ Last Failure (attempt ${s.failureCount || 1}):</strong> ${s.lastFailureReason}</div>` : ''}</div>`).join('')}</div>`;
        }
        function formatStatus(s) { return {pending:'⏳ Pending',in_progress:'🔄 In Progress',done:'✅ Done',failed:'❌ Failed'}[s]||s; }
        document.getElementById('feature-select').onchange = e => { if(e.target.value) window.location.search = `?feature=${e.target.value}`; };
        setInterval(() => { if(feature) loadData(); }, 2000);
    </script>
</body>
</html>
DASHBOARD_HTML

# ============================================================================
# Create Claude skills
# ============================================================================
echo -e "${BLUE}[5/6]${NC} Installing Claude skills..."

# /ralph:plan skill
cat > "$SKILL_DIR_PLAN/SKILL.md" << 'SKILL_MD'
---
name: ralph:plan
description: Convert plans into Ralph features with user stories. Usage: /ralph:plan @path/to/plan.md or /ralph:plan <inline description>
---

# /ralph:plan - Plan to Features Converter

You are a skill that converts Claude Code plans into Ralph features with properly structured tasks.

## Input Handling

1. **File reference**: `/ralph:plan @path/to/plan.md`
2. **Inline description**: `/ralph:plan Build a user authentication system`
3. **No arguments**: `/ralph:plan` - Search for plans in plan directories

## Step 0: Ensure Ralph is Ready

1. Check if ralph CLI is installed (`which ralph`). If not, install it.
2. Check if `.ralph/` directory exists. If not, run `ralph init`
3. Check if `.git/` exists. If not, run `git init`

## Project Scaffolding (New Projects Only)

When generating features for a new project (no existing features):

**Always create a `project-setup` feature first** with tasks for:
- Initialize git repository and basic structure
- Create package.json / project config with essential scripts
- Set up verification commands (test, lint, typecheck)
- Set up git pre-commit hooks for verification
- Create initial commit

This is required because Ralph needs git, verification scripts, and hooks to function.

## Task Sizing Rules (CRITICAL)

**Per-Feature Limits:**
- **4-12 tasks per feature** (not fewer, not more)

**Per-Task Limits:**
- **Max 4 acceptance criteria** per task
- **Max 4 files touched** per task (use `estimatedFiles` field)

**Split Pattern:** model → API → UI → tests

## PRD Schema

```json
{
  "name": "feature-name",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "dependencies": ["other-feature"],
  "createdAt": "ISO timestamp",
  "updatedAt": "ISO timestamp",
  "tasks": [
    {
      "id": "T-001",
      "title": "Task title",
      "description": "What this task accomplishes",
      "category": "core|api|ui|logic|testing|config",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ],
  "metadata": {
    "totalTasks": N,
    "completedTasks": 0,
    "failedTasks": 0,
    "currentIteration": 0,
    "maxIterations": N * 1.5
  }
}
```

## Output Files (FLAT STRUCTURE)

```
.ralph/features/
├── project-setup.prd.json      # Flat PRD file
├── auth-system.prd.json        # Flat PRD file
└── progress.txt                # Cumulative progress log

.ralph/features.json            # Feature index
```

## After Generating

Offer to start the Ralph loop:
- `/ralph:start` - Auto-select and run loop
- `/ralph:start <feature>` - Start specific feature
SKILL_MD

# /ralph:start skill
cat > "$SKILL_DIR_START/SKILL.md" << 'SKILL_MD'
---
name: ralph:start
description: Start the Ralph development loop. Auto-selects a feature or specify one.
---

# /ralph:start - Start Ralph Loop

## Usage

- `/ralph:start` - Auto-select feature based on dependencies and status
- `/ralph:start my-feature` - Start specific feature

## Execution

1. **Verify Ralph is initialized**: Check `.ralph/` exists
2. **Check for features**: Scan `.ralph/features/` for `*.prd.json` files
3. **Run the loop**:
   - With feature: `.ralph/ralph.sh start --feature <name>`
   - Auto-select: `.ralph/ralph.sh start`

## Feature Selection

1. Resume in-progress first
2. Check dependencies - skip blocked features
3. Start pending next
4. Skip completed
SKILL_MD

# /ralph:start-once skill
cat > "$SKILL_DIR_START_ONCE/SKILL.md" << 'SKILL_MD'
---
name: ralph:start-once
description: Run a single Ralph iteration. Useful for debugging or manual control.
---

# /ralph:start-once - Single Ralph Iteration

## Usage

- `/ralph:start-once` - Auto-select feature, single iteration
- `/ralph:start-once my-feature` - Single iteration on specific feature

## Execution

1. **Verify Ralph is initialized**: Check `.ralph/` exists
2. **Run single iteration**:
   - With feature: `.ralph/ralph.sh start --feature <name> --once`
   - Auto-select: `.ralph/ralph.sh start --once`
SKILL_MD

echo -e "${BLUE}[6/6]${NC} Cleaning up old skill if exists..."
# Remove old ralph-features skill if it exists
rm -rf "$HOME/.claude/skills/ralph-features" 2>/dev/null || true

# ============================================================================
# Done!
# ============================================================================
echo ""
echo -e "${GREEN}✅ Ralph installed successfully!${NC}"
echo ""

# Always show PATH setup instructions
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  IMPORTANT: Add ralph to your PATH${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Run this command to add ralph to your PATH:"
echo ""
echo -e "  ${CYAN}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc${NC}"
echo ""
echo "Or for bash:"
echo ""
echo -e "  ${CYAN}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc${NC}"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}Quick Start:${NC}"
echo "  cd your-project"
echo "  ralph init"
echo ""
echo -e "${BOLD}Commands:${NC}"
echo "  ralph init                         Initialize Ralph in a project"
echo "  ralph start                        Auto-select feature and run"
echo "  ralph start --feature <name>       Run specific feature"
echo "  ralph <feature> --once             Single iteration (legacy)"
echo ""
echo -e "${BOLD}Claude Skills:${NC}"
echo "  /ralph:plan                        Generate features from a plan"
echo "  /ralph:start                       Start the development loop"
echo "  /ralph:start-once                  Run a single iteration"
echo ""
echo -e "${BOLD}File Structure:${NC}"
echo "  .ralph/features/<name>.prd.json    Flat PRD files"
echo "  .ralph/features/progress.txt       Cumulative progress log"
echo ""
