# Feature Selection Agent

Analyze available features and select the best one to work on.

## Input

Read `.ralph/features.json` to see all features with their status, descriptions, and dependencies.

## Selection Priority (in order)

### 1. Resume in-progress work
Any feature with `status: "in_progress"` takes highest priority - always resume unfinished work.

### 2. Check explicit dependencies FIRST
For `pending` features, check the `dependencies` array.

**A feature is BLOCKED if:**
- It has dependencies listed in its `dependencies` array
- ANY of those dependencies has `status` != `"completed"`

**Skip blocked features** and move to the next candidate.

### 3. Infer dependencies from names and descriptions (fallback)
If no explicit `dependencies` array exists, analyze names and descriptions to determine logical order.

**Foundation/Setup features FIRST** - look for keywords like:
- "setup", "init", "initialize", "scaffold", "bootstrap"
- "project", "foundation", "infrastructure", "config"

### 4. Skip problematic features
- Skip features with `status: "completed"`
- Consider skipping features with >50% failure rate

## Output

Output ONLY the selected feature name wrapped in tags:
```
<selected>feature-name</selected>
```

No other output. Just the tag with the feature name.
