#!/bin/bash
# Ralph 2.0 - Global Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/nicmeriano/ralph/main/install.sh | bash

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

# Detect source directory (repo checkout or curl install)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
TEMP_DIR=""
CLEANUP_TEMP=false

# If we can't find the source files, clone the repo
if [[ -z "$SCRIPT_DIR" ]] || [[ ! -d "$SCRIPT_DIR/bin" ]]; then
    echo -e "${BLUE}[1/5]${NC} Downloading Ralph..."
    TEMP_DIR=$(mktemp -d)
    CLEANUP_TEMP=true
    git clone --depth 1 https://github.com/nicmeriano/ralph.git "$TEMP_DIR" 2>/dev/null || {
        echo -e "${RED}Error: Failed to clone Ralph repository${NC}"
        exit 1
    }
    SCRIPT_DIR="$TEMP_DIR"
else
    echo -e "${BLUE}[1/5]${NC} Installing from local repository..."
fi

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_TEMP" == "true" ]] && [[ -n "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Create directories
echo -e "${BLUE}[2/5]${NC} Creating directories..."
mkdir -p "$RALPH_HOME/templates"
mkdir -p "$RALPH_HOME/dashboard"
mkdir -p "$BIN_DIR"
mkdir -p "$SKILL_DIR_PLAN"
mkdir -p "$SKILL_DIR_START"

# Copy bin scripts
echo -e "${BLUE}[3/5]${NC} Installing ralph CLI..."
cp "$SCRIPT_DIR/bin/ralph" "$BIN_DIR/ralph"
chmod +x "$BIN_DIR/ralph"

# Copy ralph runtime files to RALPH_HOME
cp "$SCRIPT_DIR/bin/ralph.sh" "$RALPH_HOME/ralph.sh"
cp "$SCRIPT_DIR/bin/ralph-once.sh" "$RALPH_HOME/ralph-once.sh"
chmod +x "$RALPH_HOME/ralph.sh"
chmod +x "$RALPH_HOME/ralph-once.sh"

# Copy prompts (with renamed files for backwards compatibility)
cp "$SCRIPT_DIR/prompts/agent-iteration.md" "$RALPH_HOME/prompt.md"
cp "$SCRIPT_DIR/prompts/feature-selector.md" "$RALPH_HOME/feature-selector-prompt.md"

# Copy config
cp "$SCRIPT_DIR/config/config.default.json" "$RALPH_HOME/config.json"

# Copy templates
echo -e "${BLUE}[4/5]${NC} Installing templates..."
cp "$SCRIPT_DIR/templates/"* "$RALPH_HOME/templates/"

# Copy dashboard
cp "$SCRIPT_DIR/dashboard/index.html" "$RALPH_HOME/dashboard/index.html"

# Copy skills from source of truth
echo -e "${BLUE}[5/5]${NC} Installing Claude skills..."
cp "$SCRIPT_DIR/skills/ralph-plan/SKILL.md" "$SKILL_DIR_PLAN/SKILL.md"
cp "$SCRIPT_DIR/skills/ralph-start/SKILL.md" "$SKILL_DIR_START/SKILL.md"

# Clean up old skills if they exist
rm -rf "$HOME/.claude/skills/ralph-features" 2>/dev/null || true
rm -rf "$HOME/.claude/skills/ralph-start-once" 2>/dev/null || true

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
echo ""
echo -e "${BOLD}Options:${NC}"
echo "  --once                             Run a single iteration"
echo ""
echo -e "${BOLD}File Structure:${NC}"
echo "  .ralph/features/<name>.prd.json    Flat PRD files"
echo "  .ralph/features/progress.txt       Cumulative progress log"
echo ""
