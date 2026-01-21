# Ralph 2.0

Autonomous development loop powered by Claude. Takes plans and converts them into executable features that run autonomously.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/nicomeriano/ralph/main/install.sh | bash
```

## Usage

```bash
# Initialize Ralph in your project
ralph init

# Run the development loop (auto-selects feature)
ralph start

# Run for a specific feature
ralph start --feature my-feature

# Single iteration only
ralph start --once

# Custom settings
ralph start --feature my-feature --max-iterations 15 --port 4000
```

## How It Works

1. **Create a plan** in Claude Code
2. **Run `/ralph:plan`** to convert the plan into features with tasks
3. **Run `/ralph:start`** or `ralph start` to begin the autonomous loop
4. **Watch the dashboard** as Ralph completes tasks one by one

## Claude Skills

| Skill | Description |
|-------|-------------|
| `/ralph:plan` | Convert plans into Ralph features with properly sized tasks |
| `/ralph:start` | Start the autonomous development loop |

Use `--once` flag with `/ralph:start` for single iteration mode.

## Project Structure

```
.ralph/
├── features/                    # All features being worked on
│   ├── my-feature.prd.json     # PRD for this feature (flat structure)
│   └── progress.txt            # Cumulative learning log
├── ralph.sh                     # Main loop script
├── prompt.md                    # Agent instructions
├── config.json                  # Configuration
└── dashboard/
    └── index.html              # Real-time progress dashboard
```

## CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--feature <name>` | auto-select | Specify feature to work on |
| `--once` | false | Run single iteration |
| `--max-iterations N` | tasks × 1.5 | Max loop iterations |
| `--sandbox` | true | Run in Docker sandbox |
| `--port N` | 3456 | Dashboard port |
| `--no-dashboard` | false | Don't auto-start dashboard |

## Configuration

Edit `.ralph/config.json`:

```json
{
  "sandbox": true,
  "dashboardPort": 3456,
  "dashboardAutoStart": true,
  "maxIterationsMultiplier": 1.5,
  "claudeModel": "sonnet",
  "createPROnCompletion": true
}
```

## Requirements

- [Claude CLI](https://claude.ai/claude-code) installed
- `jq` for JSON parsing
- `bc` for calculations
- Python 3 or Node.js (for dashboard server)
- Git
- GitHub CLI (`gh`) for PR creation (optional)

## License

MIT
