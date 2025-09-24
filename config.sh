#!/bin/bash

# Configuration for lets-distill tools
# Edit these values to match your setup

# Main repository location (the repo you're managing tasks for)
export DISTILL_REPO_BASE="${DISTILL_REPO_BASE:-$HOME/workspace/triple-distill}"

# Where to create worktrees
export LETS_DISTILL_WORKTREE_BASE="${LETS_DISTILL_WORKTREE_BASE:-$HOME/workspace/lets-distill}"

# History file location
export LETS_DISTILL_HISTORY_FILE="${LETS_DISTILL_HISTORY_FILE:-$HOME/.lets-distill-history}"

# Default main branch name
export LETS_DISTILL_MAIN_BRANCH="${LETS_DISTILL_MAIN_BRANCH:-main}"

# Scripts directory (auto-detected)
export LETS_DISTILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"