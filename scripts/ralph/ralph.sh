#!/bin/bash

# Ralph Loop Controller
# Spawns fresh Claude instances until all PRD constraints are satisfied

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
CLAUDE_MD="$SCRIPT_DIR/CLAUDE.md"
PROGRESS_FILE="$REPO_ROOT/progress.txt"
COMPLETE_SIGNAL="<promise>COMPLETE</promise>"

# Default max iterations
MAX_ITERATIONS=${1:-20}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     RALPH LOOP CONTROLLER                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if [ ! -f "$PRD_FILE" ]; then
    echo -e "${RED}Error: prd.json not found at $PRD_FILE${NC}"
    echo "Run the Ralph skill first to generate prd.json from a PRD markdown file."
    exit 1
fi

if [ ! -f "$CLAUDE_MD" ]; then
    echo -e "${RED}Error: CLAUDE.md not found at $CLAUDE_MD${NC}"
    exit 1
fi

# Check if claude-code is available
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: claude command not found${NC}"
    echo "Make sure Claude Code CLI is installed and in your PATH."
    exit 1
fi

# Extract project info from prd.json
PROJECT_NAME=$(jq -r '.project // "unknown"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "ralph/feature"' "$PRD_FILE")
TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE")

echo -e "${YELLOW}Project:${NC} $PROJECT_NAME"
echo -e "${YELLOW}Branch:${NC} $BRANCH_NAME"
echo -e "${YELLOW}Total Stories:${NC} $TOTAL_STORIES"
echo -e "${YELLOW}Max Iterations:${NC} $MAX_ITERATIONS"
echo ""

# Function to count completed stories
count_completed() {
    jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE"
}

# Function to check if all stories are complete
all_complete() {
    local completed=$(count_completed)
    [ "$completed" -eq "$TOTAL_STORIES" ]
}

# Function to display progress
show_progress() {
    local completed=$(count_completed)
    local percent=$((completed * 100 / TOTAL_STORIES))
    local bar_width=40
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))

    printf "${GREEN}"
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%% (%d/%d)${NC}\n" "$percent" "$completed" "$TOTAL_STORIES"
}

# Main loop
iteration=1

while [ $iteration -le $MAX_ITERATIONS ]; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ITERATION $iteration / $MAX_ITERATIONS${NC}"
    show_progress
    echo ""

    # Check if already complete
    if all_complete; then
        echo -e "${GREEN}✓ All stories complete! Exiting loop.${NC}"
        break
    fi

    # Log iteration start
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Iteration $iteration started" >> "$PROGRESS_FILE"

    # Run Claude with the prompt
    echo -e "${BLUE}Spawning Claude instance...${NC}"

    # Execute Claude with the CLAUDE.md prompt
    # The prompt tells Claude to read prd.json, pick a task, implement, test, and update state
    OUTPUT=$(cd "$REPO_ROOT" && cat "$CLAUDE_MD" | claude --print 2>&1) || true

    # Check for completion signal in output
    if echo "$OUTPUT" | grep -q "$COMPLETE_SIGNAL"; then
        echo -e "${GREEN}✓ Received completion signal!${NC}"

        # Verify all stories actually pass
        if all_complete; then
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                    ALL STORIES COMPLETE!                     ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            show_progress

            # Log completion
            echo "$(date '+%Y-%m-%d %H:%M:%S') | PRD COMPLETE - All $TOTAL_STORIES stories passed" >> "$PROGRESS_FILE"

            exit 0
        else
            echo -e "${YELLOW}Warning: Completion signal received but not all stories pass.${NC}"
            echo "Continuing loop..."
        fi
    fi

    # Brief pause between iterations
    echo ""
    echo -e "${YELLOW}Iteration $iteration complete. Pausing briefly...${NC}"
    sleep 2

    ((iteration++))
done

# Check final state
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}LOOP FINISHED${NC}"
show_progress

if all_complete; then
    echo -e "${GREEN}✓ All stories complete!${NC}"
    exit 0
else
    completed=$(count_completed)
    echo -e "${YELLOW}⚠ Reached max iterations. $completed/$TOTAL_STORIES stories complete.${NC}"
    echo "You may run the loop again to continue."
    exit 1
fi
