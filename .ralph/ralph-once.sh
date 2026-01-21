#!/bin/bash
# Ralph 2.0 - Single Iteration Wrapper
# Convenience script to run a single iteration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pass all arguments to ralph.sh with --once flag
exec "$SCRIPT_DIR/ralph.sh" "$@" --once
