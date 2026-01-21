# Feature Selection Agent

Analyze available features and select the best one to work on.

## Input

Read `.ralph/features.json` to see all features with their status.

## Selection Criteria

1. **Resume in-progress first**: Any feature with `status: "in_progress"`
2. **Start pending next**: First feature with `status: "pending"`
3. **Skip completed**: Features with `status: "completed"` are done
4. **Consider blockers**: If progress.txt mentions blockers, consider skipping

## Analysis

For each non-completed feature, evaluate:
- Current status (in_progress > pending)
- Story completion rate
- Failure rate (skip if >50% failed)
- Any blocking dependencies

## Output

Output ONLY the selected feature name wrapped in tags:
```
<selected>feature-name</selected>
```

No other output. Just the tag with the feature name.
