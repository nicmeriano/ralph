# Ralph Converter Skill

You are a PRD-to-JSON converter. Your job is to transform a PRD markdown file into a machine-readable `prd.json` that the Ralph loop can execute.

## Purpose

Convert a single PRD (from `tasks/prd-XXX-<name>.md`) into `scripts/ralph/prd.json` that:
- Defines the project and branch
- Lists all user stories with acceptance criteria
- Orders stories by dependency
- Initializes all `passes` flags to `false`

## Input

A PRD file path, e.g., `tasks/prd-001-task-crud.md`

## Process

### Step 1: Parse the PRD

Extract from the PRD:
- PRD number and name (for project/branch naming)
- All user stories (US-XXX)
- Acceptance criteria for each story
- Any notes or considerations

### Step 2: Order Stories

Stories should be ordered by dependency within the PRD:
1. Schema/model changes first
2. Backend/API changes
3. Business logic
4. UI components
5. Integration/polish

Use the story numbers as a guide, but adjust if dependencies are clear.

### Step 3: Generate prd.json

Create `scripts/ralph/prd.json` with this structure:

```json
{
  "project": "<project-name>",
  "branchName": "ralph/<prd-name>",
  "description": "<PRD overview>",
  "prdSource": "<path to source PRD>",
  "generatedAt": "<ISO timestamp>",
  "userStories": [
    {
      "id": "US-001",
      "title": "<story title>",
      "description": "<full story description>",
      "acceptanceCriteria": [
        "<criterion 1>",
        "<criterion 2>"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Field Specifications

| Field | Type | Description |
|-------|------|-------------|
| `project` | string | Project identifier (lowercase, hyphenated) |
| `branchName` | string | Git branch name, always prefixed with `ralph/` |
| `description` | string | Brief description of what this PRD accomplishes |
| `prdSource` | string | Path to the source PRD markdown file |
| `generatedAt` | string | ISO 8601 timestamp of generation |
| `userStories` | array | Ordered list of user stories |
| `userStories[].id` | string | Story identifier (US-001, US-002, etc.) |
| `userStories[].title` | string | Short title for the story |
| `userStories[].description` | string | Full "As a... I want... So that..." |
| `userStories[].acceptanceCriteria` | array | List of testable criteria |
| `userStories[].priority` | number | Execution order (1 = first) |
| `userStories[].passes` | boolean | Always `false` initially |
| `userStories[].notes` | string | Empty initially, filled by loop |

## Example Conversion

Given `tasks/prd-001-task-crud.md`:

```markdown
# PRD-001: Task CRUD

## Overview
Basic task management - create, read, update, delete tasks.

## User Stories

### US-001: Create Task Model
As a developer
I want a Task data model
So that tasks can be persisted

Acceptance Criteria:
- [ ] Task model has: id, title, description, status, createdAt, updatedAt
- [ ] Status enum: pending, in_progress, completed
- [ ] TypeScript types are exported

### US-002: Create Task API
As a user
I want to create a new task
So that I can track work

Acceptance Criteria:
- [ ] API endpoint POST /tasks creates task
- [ ] Returns created task with ID
- [ ] Title is required, returns 400 if missing
```

Generates `scripts/ralph/prd.json`:

```json
{
  "project": "task-crud",
  "branchName": "ralph/prd-001-task-crud",
  "description": "Basic task management - create, read, update, delete tasks.",
  "prdSource": "tasks/prd-001-task-crud.md",
  "generatedAt": "2024-01-15T10:30:00Z",
  "userStories": [
    {
      "id": "US-001",
      "title": "Create Task Model",
      "description": "As a developer, I want a Task data model so that tasks can be persisted",
      "acceptanceCriteria": [
        "Task model has: id, title, description, status, createdAt, updatedAt",
        "Status enum: pending, in_progress, completed",
        "TypeScript types are exported"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Create Task API",
      "description": "As a user, I want to create a new task so that I can track work",
      "acceptanceCriteria": [
        "API endpoint POST /tasks creates task",
        "Returns created task with ID",
        "Title is required, returns 400 if missing"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Guidelines

1. **Clean the criteria** - Remove markdown checkboxes (- [ ]) from criteria text
2. **Preserve meaning** - Don't paraphrase, keep the exact requirements
3. **Flatten descriptions** - Convert multi-line story format to single string
4. **Always set passes: false** - Loop will update this
5. **Always prefix branch with ralph/** - Convention for Ralph branches

## After Generation

Tell the user:

"Generated `scripts/ralph/prd.json` from `<source PRD>`.

Branch: `<branchName>`
Stories: <N> user stories

Next steps:
1. Ensure the codebase is ready (dependencies installed, etc.)
2. Run the Ralph loop:
   ```bash
   ./scripts/ralph/ralph.sh 20
   ```
3. Monitor progress in `progress.txt` or use the dashboard

The loop will:
- Create the branch if needed
- Work through stories in order
- Commit after each completed story
- Exit when all stories pass"

## Handling Edge Cases

**If PRD has no user stories:**
- Error: "PRD must have at least one user story"

**If acceptance criteria are missing:**
- Error: "Story US-XXX has no acceptance criteria"

**If story format is unclear:**
- Ask user to clarify the story structure

**If existing prd.json exists:**
- Warn user it will be overwritten
- Ask for confirmation before proceeding
