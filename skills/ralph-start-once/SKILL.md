---
name: ralph:start-once
description: Run a single Ralph iteration. Useful for debugging or manual control.
---

# /ralph:start-once - Single Ralph Iteration

Run exactly one iteration of the Ralph loop.

## Usage

- `/ralph:start-once` - Auto-select feature, single iteration
- `/ralph:start-once my-feature` - Single iteration on specific feature

## When to Use

- **Debugging**: Step through the loop one iteration at a time
- **Manual control**: Review changes after each story
- **Testing**: Verify Ralph works correctly before running the full loop
- **Learning**: Understand how Ralph processes stories

## Execution

When invoked:

### 1. Verify Ralph is initialized

Check if `.ralph/` directory exists.

If not:
```
Ralph not initialized in this project.

Run /ralph:plan first to create features, or run:
  ralph init

to initialize Ralph manually.
```

### 2. Check for features

Read `.ralph/features.json` or scan `.ralph/features/` for feature directories.

If no features found:
```
No features found in .ralph/features/

Run /ralph:plan to generate features from a plan.
```

### 3. Run single iteration

Execute the ralph script with `--once` flag:

**If feature specified:**
```bash
.ralph/ralph.sh start --feature <name> --once
```

**If no feature specified (auto-select):**
```bash
.ralph/ralph.sh start --once
```

### 4. Report result

After the iteration completes:

```
Single iteration complete.

Feature: auth-system
Story worked on: US-002 - Login API
Result: PASSED

Progress: 2/5 stories complete
Remaining: 3 stories

To continue:
  /ralph:start-once     - Run another single iteration
  /ralph:start          - Run the full loop
```

Or if the story failed:

```
Single iteration complete.

Feature: auth-system
Story worked on: US-002 - Login API
Result: FAILED (attempt 1/3)

Failure reason: Tests failed - missing JWT_SECRET env var

Progress: 1/5 stories complete
Failed: 1 story

Review the failure and either:
  - Fix the issue manually
  - /ralph:start-once   - Let Ralph retry
  - /ralph:start        - Continue with full loop
```

## Feature Selection Logic

When auto-selecting, Ralph chooses:

1. **First priority**: Any feature with `status: "in_progress"` (resume work)
2. **Second priority**: First feature with `status: "pending"`

## Examples

```
/ralph:start-once
```
Runs a single iteration on the auto-selected feature.

```
/ralph:start-once auth-system
```
Runs a single iteration on the `auth-system` feature.

## Workflow Tip

For maximum control, combine with reviewing changes:

1. `/ralph:start-once` - Run one iteration
2. Review the changes Ralph made
3. `git diff` to see what changed
4. If satisfied, `/ralph:start-once` again
5. Or `/ralph:start` to let it run autonomously

## Notes

- Only processes one story per invocation
- Ideal for understanding how Ralph works
- Changes are committed if the story passes
- Failed stories are rolled back
