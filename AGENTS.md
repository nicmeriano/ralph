# Ralph Knowledge Base

This file contains patterns, conventions, and learnings discovered by Ralph loop agents. It grows over time as agents work on the codebase.

## Project Overview

This repository contains the Ralph Loop system - an autonomous, spec-driven development workflow.

## Directory Structure

```
ralph/
├── scripts/ralph/       # Loop controller and agent prompt
│   ├── ralph.sh         # Main loop script
│   ├── CLAUDE.md        # Agent instructions per iteration
│   └── prd.json         # Current PRD being executed (generated)
├── skills/              # Claude Code skills
│   ├── spec/            # Spec Generator skill
│   ├── prd/             # PRD Generator skill
│   └── ralph/           # PRD to JSON converter skill
├── specs/               # High-level specifications
├── tasks/               # PRD markdown files
├── dashboard/           # Real-time monitoring web app
├── progress.txt         # Append-only learning log
└── AGENTS.md            # This file - knowledge base
```

## Conventions

### Git

- Branch naming: `ralph/<prd-name>` (e.g., `ralph/prd-001-task-crud`)
- Commit messages: `feat(US-XXX): <description>` or `fix(US-XXX): <description>`
- Always include Co-Authored-By for Ralph commits

### File Naming

- Specs: `specs/spec-<project-name>.md`
- PRDs: `tasks/prd-<NNN>-<capability-name>.md`
- Generated JSON: `scripts/ralph/prd.json`

### User Story IDs

- Format: `US-XXX` where XXX is zero-padded (US-001, US-002)
- IDs are scoped to individual PRDs (each PRD starts at US-001)

## Patterns Discovered

<!-- Agents: Add patterns you discover here -->

### Pattern: [Name]
**Context:** When this pattern applies
**Solution:** What to do
**Example:** Code or command example

---

## Gotchas

<!-- Agents: Add gotchas and warnings here -->

### Gotcha: [Name]
**Problem:** What can go wrong
**Solution:** How to avoid or fix it

---

## Commands Reference

### Running the Loop
```bash
./scripts/ralph/ralph.sh 20  # Run up to 20 iterations
```

### Checking Progress
```bash
# View progress log
cat progress.txt

# Check prd.json status
jq '.userStories[] | {id, title, passes}' scripts/ralph/prd.json
```

### Dashboard
```bash
npx serve . && open http://localhost:3000/dashboard/
```

---

*Last updated: Initial setup*
