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

# Run the development loop for a feature
ralph my-feature

# Single iteration only
ralph my-feature --once

# Custom settings
ralph my-feature --max-iterations 15 --port 4000
```

## How It Works

1. **Create a plan** in Claude Code
2. **Run `/ralph-features`** to convert the plan into features with user stories
3. **Run `ralph <feature>`** to start the autonomous loop
4. **Watch the dashboard** as Ralph completes stories one by one

## Project Structure

```
.ralph/
├── features/                    # All features being worked on
│   └── my-feature/
│       ├── prd.json            # Stories for this feature
│       └── progress.txt        # Learning log
├── ralph.sh                     # Main loop script
├── ralph-once.sh               # Single iteration wrapper
├── prompt.md                   # Agent instructions
├── config.json                 # Configuration
├── dashboard/
│   └── index.html              # Real-time progress dashboard
└── templates/
    ├── prd.template.json       # Template for new features
    └── progress.template.txt   # Template for progress files
```

## CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--once` | false | Run single iteration |
| `--max-iterations N` | stories × 1.5 | Max loop iterations |
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

## Claude Skill

The `/ralph-features` skill converts Claude Code plans into Ralph features:

- Parses `## Phase N: Name` as features
- Parses `### Task N.N: Title` as user stories
- Parses `- [ ] Item` as acceptance criteria
- Asks clarifying questions if needed
- Generates proper PRD structure

## Requirements

- [Claude CLI](https://claude.ai/claude-code) installed
- `jq` for JSON parsing
- `bc` for calculations
- Python 3 or Node.js (for dashboard server)
- Git
- GitHub CLI (`gh`) for PR creation (optional)

## License

MIT
