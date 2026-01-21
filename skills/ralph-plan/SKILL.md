---
name: ralph:plan
description: Convert plans into Ralph features with user stories. Usage: /ralph:plan @path/to/plan.md or /ralph:plan <inline description>
---

# /ralph:plan - Plan to Features Converter

You are a skill that converts Claude Code plans into Ralph features with properly structured user stories.

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

**Always create a `project-setup` feature first** with these stories:

```json
{
  "name": "project-setup",
  "branchName": "ralph/project-setup",
  "description": "Initialize project structure and essential tooling for Ralph development",
  "createdAt": "...",
  "updatedAt": "...",
  "userStories": [
    {
      "id": "US-001",
      "title": "Initialize git repository and basic structure",
      "description": "As a developer, I want the project to have a proper git repository so that Ralph can create branches and commits",
      "category": "config",
      "acceptanceCriteria": [
        "Git repository is initialized (.git/ exists)",
        "Basic project structure exists (src/ or appropriate directory)",
        ".gitignore file exists with appropriate ignores"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "US-002",
      "title": "Create project configuration with essential scripts",
      "description": "As a developer, I want package.json or equivalent config so that verification commands can run",
      "category": "config",
      "acceptanceCriteria": [
        "package.json (or equivalent) exists with project name and version",
        "Scripts section includes: test, lint, typecheck (or equivalents)",
        "Dependencies are installed"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "US-003",
      "title": "Set up verification commands",
      "description": "As Ralph, I need verification scripts to validate changes before committing",
      "category": "config",
      "acceptanceCriteria": [
        "Test command runs without error (even if no tests yet)",
        "Lint command runs without error",
        "Typecheck command runs without error (if using typed language)"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    },
    {
      "id": "US-004",
      "title": "Create initial commit",
      "description": "As a developer, I want an initial commit so that Ralph has a clean starting point",
      "category": "config",
      "acceptanceCriteria": [
        "All setup files are committed",
        "Commit message follows conventional format",
        "Working tree is clean after commit"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ],
  "metadata": {
    "totalStories": 4,
    "completedStories": 0,
    "failedStories": 0,
    "currentIteration": 0,
    "maxIterations": 6
  }
}
```

**This feature is required because Ralph needs:**
- A git repository to create branches and commits
- Verification scripts to validate changes
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

Extract features and stories from the plan using these patterns:

| Pattern | Becomes |
|---------|---------|
| `## Phase N: Name` | Feature boundary |
| `### Task N.N: Title` | User story |
| `- [ ] Item` | Acceptance criterion |
| `As a... I want... So that...` | User story description |

### 3. Ask Clarifying Questions

Before generating, ask about:
- **Ambiguous scope**: "Should X be part of feature A or B?"
- **Missing criteria**: "What defines 'done' for this story?"
- **Story sizing**: "This seems large - should we split it?"

### 4. Story Sizing Rules

Each story should be completable in one iteration:
- **Max 5 acceptance criteria** per story
- **Max 4 files touched** per story
- **Split pattern**: model -> API -> UI -> tests
- If a task touches more than 4 files, split it

### 5. Category Assignment

Assign categories based on the work type:
- `core` - Core business logic, models
- `api` - API endpoints, routes, handlers
- `ui` - User interface components
- `logic` - Algorithms, utilities
- `testing` - Test files, test utilities
- `config` - Configuration, setup

## PRD Schema

Generate PRDs using this exact schema:

```json
{
  "name": "feature-name",
  "branchName": "ralph/feature-name",
  "description": "High-level feature description",
  "createdAt": "2026-01-20T10:00:00Z",
  "updatedAt": "2026-01-20T10:00:00Z",
  "userStories": [
    {
      "id": "US-001",
      "title": "Short descriptive title",
      "description": "As a [user type], I want [goal] so that [benefit]",
      "category": "core|api|ui|logic|testing|config",
      "acceptanceCriteria": [
        "Specific, testable criterion 1",
        "Specific, testable criterion 2"
      ],
      "passes": false,
      "status": "pending",
      "notes": "",
      "failureCount": 0,
      "lastFailureReason": "",
      "completedAt": null
    }
  ],
  "metadata": {
    "totalStories": 5,
    "completedStories": 0,
    "failedStories": 0,
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
      "storyCount": 5,
      "completedCount": 0,
      "failedCount": 0
    }
  ]
}
```

## ID Generation

- Stories: `US-001`, `US-002`, etc.
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

4. **Present Summary**: Show detected features and story count

5. **Ask Questions**: Clarify any ambiguities

6. **Generate Files**:
   ```
   .ralph/features/<feature-name>/
   ├── prd.json        # Generated PRD
   └── progress.txt    # Empty progress log

   .ralph/features.json  # Updated feature index
   ```

7. **Report Results**:
   ```
   Created 2 features from plan:

   📁 .ralph/features/project-setup/
      - 4 user stories (required for new projects)
      - Categories: config

   📁 .ralph/features/auth-system/
      - 5 user stories
      - Categories: core, api, ui
      - Estimated iterations: 8
   ```

8. **Offer to Start Loop**:

   After generating features, **always offer to start the Ralph loop immediately**:

   ```
   Would you like to start the Ralph loop now?

   Available features:
     1. project-setup (4 stories) - Required first
     2. auth-system (5 stories)
     3. dashboard (3 stories)

   Options:
     • /ralph:start              - Auto-select and run loop
     • /ralph:start auth-system  - Start specific feature
     • Skip for now              - Just generate files
   ```

   If the user chooses to start:
   - Execute `.ralph/ralph.sh start` or `.ralph/ralph.sh start --feature <name>` directly
   - This runs the loop within the current Claude session
   - No need to exit Claude and run manually

## Example Transformation

**Input Plan:**
```markdown
## Phase 1: Authentication

### Task 1.1: User Model
Create the user model with email and password fields.
- [ ] Create User schema
- [ ] Add password hashing
- [ ] Add validation

### Task 1.2: Login API
Implement login endpoint.
- [ ] POST /api/login endpoint
- [ ] JWT token generation
- [ ] Error handling
```

**Output PRD:**
```json
{
  "name": "authentication",
  "branchName": "ralph/authentication",
  "description": "User authentication system with login functionality",
  "userStories": [
    {
      "id": "US-001",
      "title": "User Model",
      "description": "As a developer, I want a User model so that I can store user credentials",
      "category": "core",
      "acceptanceCriteria": [
        "User schema exists with email and password fields",
        "Passwords are hashed before storage",
        "Email validation is enforced"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": ""
    },
    {
      "id": "US-002",
      "title": "Login API",
      "description": "As a user, I want to login so that I can access protected resources",
      "category": "api",
      "acceptanceCriteria": [
        "POST /api/login endpoint exists",
        "Valid credentials return JWT token",
        "Invalid credentials return 401 error"
      ],
      "passes": false,
      "status": "pending",
      "failureCount": 0,
      "lastFailureReason": ""
    }
  ]
}
```

## Notes

- **Story order is NOT execution order** - Ralph autonomously decides priority
- Generate `progress.txt` from template with feature name
- Calculate `maxIterations` as `totalStories * 1.5`
- Timestamp format: ISO 8601 (e.g., `2026-01-20T10:00:00Z`)
- **Always offer to start the loop** after generating - this is the smoother workflow

## Browser Testing Note

If any stories have `category: "ui"`, mention that browser testing is available:

```
Note: UI stories detected. To enable browser testing:
1. Install dev-browser: https://github.com/SawyerHood/dev-browser
2. Set browserTesting.enabled = true in .ralph/config.json
3. Configure devServerCommand and devServerPort
```
