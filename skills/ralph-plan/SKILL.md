---
name: ralph:plan
description: Convert plans into Ralph features with user stories. Usage: /ralph:plan @path/to/plan.md or /ralph:plan <inline description>
---

# /ralph:plan - Plan to Features Converter

You are a skill that converts Claude Code plans into Ralph features with properly structured tasks.

## Input Handling

This skill accepts flexible input:

1. **File reference**: `/ralph:plan @path/to/plan.md` - Parse the referenced plan file
2. **Inline description**: `/ralph:plan Build a user authentication system` - Create features from the description
3. **No arguments**: `/ralph:plan` - Search for plans in `~/.claude/plans/*.md` and `.claude/plans/*.md`

## Step 0: Ensure Ralph is Ready

**Before generating features, ensure Ralph is installed and initialized:**

### 1. Check if ralph CLI is installed

```bash
which ralph
```

If not found:
- Inform user: "Ralph CLI not found. Installing..."
- Run: `curl -fsSL https://raw.githubusercontent.com/nicmeriano/ralph/main/install.sh | bash`
- Source the shell config to get ralph in PATH:
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```

### 2. Check if project is initialized

Check if `.ralph/` directory exists.

If not:
- Inform user: "Initializing Ralph in this project..."
- Run: `ralph init`

### 3. Verify git is initialized

Check if `.git/` exists.

If not:
- Inform user: "Initializing git repository..."
- Run: `git init`

## Project Scaffolding (New Projects Only)

When generating features for a **new project** (no existing `.ralph/features/` or empty features directory):

**Always create a `project-setup` feature first** with these tasks:

```json
{
  "name": "project-setup",
  "branchName": "ralph/project-setup",
  "description": "Initialize project structure and essential tooling for Ralph development",
  "dependencies": [],
  "createdAt": "...",
  "updatedAt": "...",
  "tasks": [
    {
      "id": "T-001",
      "title": "Initialize git repository and basic structure",
      "description": "Set up proper git repository so that Ralph can create branches and commits",
      "category": "config",
      "acceptanceCriteria": [
        "Git repository is initialized (.git/ exists)",
        "Basic project structure exists (src/ or appropriate directory)",
        ".gitignore file exists with appropriate ignores"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-002",
      "title": "Create project configuration with essential scripts",
      "description": "Set up package.json or equivalent config so verification commands can run",
      "category": "config",
      "acceptanceCriteria": [
        "package.json (or equivalent) exists with project name and version",
        "Scripts section includes: test, lint, typecheck (or equivalents)",
        "Dependencies are installed"
      ],
      "estimatedFiles": 1,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-003",
      "title": "Set up verification commands",
      "description": "Configure verification scripts to validate changes before committing",
      "category": "config",
      "acceptanceCriteria": [
        "Test command runs without error (even if no tests yet)",
        "Lint command runs without error",
        "Typecheck command runs without error (if using typed language)"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-004",
      "title": "Set up git pre-commit hooks for verification",
      "description": "Install git hooks to automatically run tests, lint, and typecheck on commit",
      "category": "config",
      "acceptanceCriteria": [
        "Pre-commit hook is installed and executable",
        "Hook runs lint on staged files",
        "Hook runs typecheck before commit",
        "Hook runs tests before commit"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "Can use husky, simple-git-hooks, or plain .git/hooks/pre-commit script",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-005",
      "title": "Create initial commit",
      "description": "Commit all setup files so Ralph has a clean starting point",
      "category": "config",
      "acceptanceCriteria": [
        "All setup files are committed",
        "Commit message follows conventional format",
        "Working tree is clean after commit"
      ],
      "estimatedFiles": 0,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ],
  "metadata": {
    "totalTasks": 5,
    "completedTasks": 0,
    "failedTasks": 0,
    "currentIteration": 0,
    "maxIterations": 8
  }
}
```

**This feature is required because Ralph needs:**
- A git repository to create branches and commits
- Verification scripts to validate changes
- Git hooks to enforce quality on every commit
- The ability to commit code

**Do NOT ask the user if they want to include this** - it's a prerequisite for Ralph to function.

## Workflow

### 1. Detect Plans

Based on input:

- **If `@path/to/file` provided**: Read and parse that specific file
- **If inline text provided**: Use the description to generate features
- **If no arguments**: Look for plan files in:
  - `~/.claude/plans/*.md`
  - `.claude/plans/*.md`
  - Current conversation context (if the user has discussed a plan)

### 2. Parse Plan Structure

Extract features and tasks from the plan using these patterns:

| Pattern | Becomes |
|---------|---------|
| `## Phase N: Name` | Feature boundary |
| `### Task N.N: Title` | Task |
| `- [ ] Item` | Acceptance criterion |

### 3. Ask Clarifying Questions

Before generating, ask clarifying questions using **lettered options** so users can respond quickly (e.g., "1A, 2C, 3B"):

**Example questions:**

```
1. What is the primary goal?
   A. New greenfield project
   B. Add feature to existing codebase
   C. Refactor existing code
   D. Other: [please specify]

2. What tech stack are you using?
   A. Next.js + TypeScript
   B. Node.js + Express
   C. Python + FastAPI
   D. Other: [please specify]

3. How should we handle authentication?
   A. JWT tokens with refresh
   B. Session-based auth
   C. OAuth only (social login)
   D. Skip for now, add later
```

Also ask about:
- **Ambiguous scope**: "Should X be part of feature A or B?"
- **Missing criteria**: "What defines 'done' for this task?"
- **Task sizing**: "This seems large - should we split it?"

## Task Sizing: The Number One Rule

**Each task must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Claude instance per iteration with no memory of previous work. If a task is too big, the LLM runs out of context before finishing.

### Right-sized tasks:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list
- Create a single API endpoint

### Too big (split these):
- "Build the entire dashboard" → Split into: schema, queries, UI, filters
- "Add authentication" → Split into: schema, middleware, login UI, session
- "Refactor the API" → Split into one task per endpoint
- "Create user management" → Split into: model, CRUD API, list UI, detail UI

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

### Per-Feature Limits:
- **4-12 tasks per feature** (not fewer, not more)
- If a feature has fewer than 4 tasks, consider combining with another feature
- If a feature has more than 12 tasks, split into multiple features

### Per-Task Limits:
- **Max 4 acceptance criteria** per task
- **Max 4 files touched** per task (use `estimatedFiles` field)
- If a task exceeds these, split it

### Split Pattern:
When splitting large tasks, follow this layer order:
1. model/schema →
2. API/backend →
3. UI/frontend →
4. tests

**Examples of splitting:**
- "Build user authentication" → Split into: "Create User model", "Create login API", "Create login UI", "Add auth tests"
- "Add dashboard" → Split into: "Create dashboard layout", "Add dashboard widgets", "Connect dashboard to API"

## Acceptance Criteria: Must Be Verifiable

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "POST /api/tasks returns 201 with task object"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"
- "Is performant"

### Note on verification:
- Typecheck, lint, and tests run automatically via pre-commit hooks (set up in project-setup)
- For UI tasks, include "Verify in browser" when visual confirmation is needed
- Focus acceptance criteria on business logic and observable behavior

## Task Ordering

Tasks execute in order. Earlier tasks must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that doesn't exist yet)
2. Schema change

### Category Assignment

Assign categories based on the work type:
- `core` - Core business logic, models, schemas
- `api` - API endpoints, routes, handlers
- `ui` - User interface components
- `logic` - Algorithms, utilities, helpers
- `testing` - Test files, test utilities
- `config` - Configuration, setup, infrastructure

### Dependency Management

Set the `dependencies` array to list features that must be completed first:

```json
{
  "name": "user-dashboard",
  "dependencies": ["project-setup", "user-authentication"],
  ...
}
```

**Rules:**
- `project-setup` should have `dependencies: []` (no dependencies)
- Most features should depend on `project-setup`
- Order features logically: setup → core → api → ui

## PRD Schema

Generate PRDs using this exact schema:

```json
{
  "name": "feature-name",
  "branchName": "ralph/feature-name",
  "description": "High-level feature description",
  "dependencies": ["other-feature-name"],
  "createdAt": "2026-01-21T10:00:00Z",
  "updatedAt": "2026-01-21T10:00:00Z",
  "tasks": [
    {
      "id": "T-001",
      "title": "Short descriptive title",
      "description": "What this task accomplishes",
      "category": "core|api|ui|logic|testing|config",
      "acceptanceCriteria": [
        "Specific, testable criterion 1",
        "Specific, testable criterion 2"
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
    "totalTasks": 5,
    "completedTasks": 0,
    "failedTasks": 0,
    "currentIteration": 0,
    "maxIterations": 8
  }
}
```

## Features Index Schema

Also generate/update `.ralph/features.json`:

```json
{
  "features": [
    {
      "name": "feature-name",
      "description": "Feature description",
      "status": "pending|in_progress|completed",
      "taskCount": 5,
      "completedCount": 0,
      "failedCount": 0,
      "dependencies": ["other-feature"]
    }
  ]
}
```

## ID Generation

- Tasks: `T-001`, `T-002`, etc.
- Keep IDs sequential within each feature
- Start from 001 for each new feature

## Execution Steps

When `/ralph:plan` is invoked:

1. **Ensure Ralph is Ready** (Step 0 above)
   - Install ralph CLI if missing
   - Initialize project if needed
   - Initialize git if needed

2. **Handle Input**: Parse file reference, inline text, or search for plans

3. **Check for New Project**: If `.ralph/features/` is empty or doesn't exist, prepare to include `project-setup` feature first

4. **Ask Clarifying Questions**: Use lettered options for quick responses

5. **Present Summary**: Show detected features and task count

6. **Generate Files** (FLAT STRUCTURE):
   ```
   .ralph/features/
   ├── project-setup.prd.json      # Flat PRD file
   ├── auth-system.prd.json        # Flat PRD file
   └── progress.txt                # Cumulative progress log

   .ralph/features.json            # Updated feature index
   ```

7. **Report Results**:
   ```
   Created 2 features from plan:

   project-setup.prd.json
      - 5 tasks (required for new projects)
      - Dependencies: none
      - Categories: config

   auth-system.prd.json
      - 6 tasks
      - Dependencies: project-setup
      - Categories: core, api, ui
      - Estimated iterations: 9
   ```

8. **Offer to Start Loop**:

   After generating features, **always offer to start the Ralph loop immediately**:

   ```
   Would you like to start the Ralph loop now?

   Available features:
     1. project-setup (5 tasks) - Required first
     2. auth-system (6 tasks) - Depends on: project-setup

   Options:
     - /ralph:start              - Auto-select and run loop
     - /ralph:start auth-system  - Start specific feature
     - Skip for now              - Just generate files
   ```

   If the user chooses to start:
   - Execute `.ralph/ralph.sh start` or `.ralph/ralph.sh start --feature <name>` directly
   - This runs the loop within the current Claude session
   - No need to exit Claude and run manually

## Example: Task Status Feature

This example shows properly sized tasks with verifiable criteria:

**Input Plan:**
```markdown
Add task status tracking with filtering
```

**Output PRD** (saved to `.ralph/features/task-status.prd.json`):
```json
{
  "name": "task-status",
  "branchName": "ralph/task-status",
  "description": "Add status field to tasks with filtering capability",
  "dependencies": ["project-setup"],
  "createdAt": "2026-01-21T10:00:00Z",
  "updatedAt": "2026-01-21T10:00:00Z",
  "tasks": [
    {
      "id": "T-001",
      "title": "Add status column to tasks table",
      "description": "Add status enum column with migration",
      "category": "core",
      "acceptanceCriteria": [
        "Migration adds status column to tasks table",
        "Status column has type enum('pending', 'in_progress', 'completed')",
        "Default value is 'pending'"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-002",
      "title": "Update task server actions for status",
      "description": "Add updateStatus action and include status in queries",
      "category": "api",
      "acceptanceCriteria": [
        "updateTaskStatus(id, status) action exists",
        "getTasks() returns status field",
        "getTaskById() returns status field"
      ],
      "estimatedFiles": 1,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-003",
      "title": "Add status badge to task list items",
      "description": "Display status as colored badge in task rows",
      "category": "ui",
      "acceptanceCriteria": [
        "TaskRow component shows status badge",
        "Badge color: gray=pending, blue=in_progress, green=completed",
        "Badge is clickable to cycle status"
      ],
      "estimatedFiles": 2,
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "T-004",
      "title": "Add status filter dropdown",
      "description": "Dropdown to filter tasks by status",
      "category": "ui",
      "acceptanceCriteria": [
        "Filter dropdown above task list",
        "Options: All, Pending, In Progress, Completed",
        "Selecting filter updates displayed tasks"
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
    "totalTasks": 4,
    "completedTasks": 0,
    "failedTasks": 0,
    "currentIteration": 0,
    "maxIterations": 6
  }
}
```

## Notes

- **Task order matters** - Ralph executes tasks in order, respect dependencies
- **Flat file structure** - PRDs are saved as `<feature-name>.prd.json` directly in features/
- **Cumulative progress** - Single `progress.txt` file shared across all features
- Calculate `maxIterations` as `totalTasks * 1.5`
- Timestamp format: ISO 8601 (e.g., `2026-01-21T10:00:00Z`)
- **Always offer to start the loop** after generating - this is the smoother workflow

## Browser Testing Note

If any tasks have `category: "ui"`, mention that browser testing is available:

```
Note: UI tasks detected. To enable browser testing:
1. Install dev-browser: https://github.com/SawyerHood/dev-browser
2. Set browserTesting.enabled = true in .ralph/config.json
3. Configure devServerCommand and devServerPort
```
