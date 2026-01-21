---
name: ralph-features
description: Convert Claude Code plans into Ralph features with user stories
---

# /ralph-features - Plan to Features Converter

You are a skill that converts Claude Code plans into Ralph features with properly structured user stories.

## Workflow

### 1. Detect Plans

Look for plan files in these locations:
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
- **Dependencies**: "Does story X need Y completed first?"
- **Story sizing**: "This seems large - should we split it?"

### 4. Story Sizing Rules

Each story should be completable in one iteration:
- **Max 5 acceptance criteria** per story
- **Max 4 files touched** per story
- **Split pattern**: model → API → UI → tests
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
  "dependencies": [],
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
      "dependencies": [],
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

When `/ralph-features` is invoked:

1. **Check for Ralph**: Verify `.ralph/` exists, suggest `ralph init` if not

2. **Find Plans**: Search for plan files, show what was found

3. **Present Summary**: Show detected features and story count

4. **Ask Questions**: Clarify any ambiguities

5. **Generate Files**:
   ```
   .ralph/features/<feature-name>/
   ├── prd.json        # Generated PRD
   └── progress.txt    # Empty progress log

   .ralph/features.json  # Updated feature index
   ```

6. **Report Results**:
   ```
   Created 2 features from plan:

   📁 .ralph/features/auth-system/
      - 5 user stories
      - Categories: core, api, ui
      - Estimated iterations: 8

   📁 .ralph/features/dashboard/
      - 3 user stories
      - Categories: ui, logic
      - Estimated iterations: 5
   ```

7. **Offer to Start Loop**:

   After generating features, **always offer to start the Ralph loop immediately**:

   ```
   Would you like to start the Ralph loop now?

   Available features:
     1. auth-system (5 stories) - No dependencies
     2. dashboard (3 stories) - Depends on: auth-system

   Options:
     • ralph start              - Auto-select based on dependencies
     • ralph start --feature auth-system  - Start specific feature
     • Skip for now            - Just generate files
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
  "dependencies": [],
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
- The `dependencies` field allows Ralph to auto-select features in the correct order

## Browser Testing Note

If any stories have `category: "ui"`, mention that browser testing is available:

```
Note: UI stories detected. To enable browser testing:
1. Install dev-browser: https://github.com/SawyerHood/dev-browser
2. Set browserTesting.enabled = true in .ralph/config.json
3. Configure devServerCommand and devServerPort
```
