# Feature Selection Agent

Analyze available features and select the best one to work on.

## Input

Read `.ralph/features.json` to see all features with their status and descriptions.

## Selection Priority (in order)

### 1. Resume in-progress work
Any feature with `status: "in_progress"` takes highest priority - always resume unfinished work.

### 2. Infer dependencies from names and descriptions
For `pending` features, analyze names and descriptions to determine logical order:

**Foundation/Setup features FIRST** - look for keywords like:
- "setup", "init", "initialize", "scaffold", "bootstrap"
- "project", "foundation", "infrastructure", "config"
- "base", "core" (when it means foundational, not core functionality)

**Then build features** - look for:
- "build", "create", "implement", "add"
- Features that would logically depend on setup being complete

**Example ordering:**
- `project-setup` → before → `user-authentication` → before → `user-dashboard`
- `database-init` → before → `crud-operations`
- `app-scaffold` → before → `feature-implementation`

### 3. Skip problematic features
- Skip features with `status: "completed"`
- Consider skipping features with >50% failure rate (failedCount / storyCount)

## Analysis Process

1. Read `.ralph/features.json`
2. Filter out completed features
3. If any feature is `in_progress`, select it immediately
4. For pending features, analyze names and descriptions:
   - Identify setup/initialization features (these go first)
   - Identify features that sound like they depend on others
   - Select the most foundational pending feature
5. If unclear, prefer features with fewer stories (simpler first)

## Output

Output ONLY the selected feature name wrapped in tags:
```
<selected>feature-name</selected>
```

No other output. Just the tag with the feature name.
