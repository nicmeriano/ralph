---
name: ralph:start
description: Start the Ralph development loop. Auto-selects a feature or specify one.
---

# /ralph:start - Start Ralph Loop

Start the Ralph autonomous development loop.

## Usage

- `/ralph:start` - Auto-select feature based on status
- `/ralph:start my-feature` - Start specific feature

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

Run /ralph:plan to generate features from a plan:
  /ralph:plan @path/to/plan.md
  /ralph:plan Build a user auth system
```

### 3. Run the loop

Execute the ralph loop script:

**If feature specified:**
```bash
.ralph/ralph.sh start --feature <name>
```

**If no feature specified:**
```bash
.ralph/ralph.sh start
```
(Ralph will use Claude to analyze and select the best feature)

### 4. Report

When starting:
```
Starting Ralph loop...

Feature: auth-system (auto-selected)
Branch: ralph/auth-system
Stories: 0/5 complete
Mode: Loop (max 8 iterations)

Dashboard: http://localhost:3456/?feature=auth-system

Ralph is now working autonomously. You can:
- Watch progress in the dashboard
- Check .ralph/features/auth-system/progress.txt for details
- Ctrl+C to stop the loop
```

## Feature Selection

When auto-selecting, Ralph uses Claude to analyze `.ralph/features.json` and select:

1. **Resume in-progress first**: Any feature with `status: "in_progress"`
2. **Start pending next**: First feature with `status: "pending"`
3. **Skip completed**: Features with `status: "completed"` are done
4. **Consider blockers**: High failure rates may be skipped

## Examples

```
/ralph:start
```
Auto-selects the best feature to work on and starts the loop.

```
/ralph:start auth-system
```
Starts the loop for the `auth-system` feature specifically.

## Notes

- The loop runs until all stories pass or max iterations is reached
- Progress is saved after each iteration
- Failed stories are retried up to 3 times before being skipped
- A PR is created automatically when all stories complete
