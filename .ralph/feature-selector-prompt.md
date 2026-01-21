# Feature Selection Agent

Analyze available features and select the best one to work on.

## Input

Read `.ralph/features.json` to see all features with their status, descriptions, and dependencies.

## Selection Priority (in order)

### 1. Resume in-progress work
Any feature with `status: "in_progress"` takes highest priority - always resume unfinished work.

### 2. Check explicit dependencies FIRST
For `pending` features, check the `dependencies` array:

```json
{
  "name": "user-dashboard",
  "dependencies": ["user-authentication"],
  ...
}
```

**A feature is BLOCKED if:**
- It has dependencies listed in its `dependencies` array
- ANY of those dependencies has `status` != `"completed"`

**Skip blocked features** and move to the next candidate.

### 3. Infer dependencies from names and descriptions (fallback)
If no explicit `dependencies` array exists, analyze names and descriptions to determine logical order:

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

### 4. Skip problematic features
- Skip features with `status: "completed"`
- Consider skipping features with >50% failure rate (failedCount / taskCount)

## Analysis Process

1. Read `.ralph/features.json`
2. Filter out completed features
3. If any feature is `in_progress`, select it immediately
4. For pending features:
   a. **Check explicit dependencies first** - skip any feature whose dependencies aren't completed
   b. If no explicit dependencies, analyze names/descriptions for implicit ordering
   c. Identify setup/initialization features (these go first)
   d. Select the most foundational non-blocked pending feature
5. If multiple candidates remain, prefer features with fewer tasks (simpler first)

## Output

Output ONLY the selected feature name wrapped in tags:
```
<selected>feature-name</selected>
```

No other output. Just the tag with the feature name.
