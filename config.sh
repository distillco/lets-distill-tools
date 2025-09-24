#!/bin/bash

# Configuration for lets-distill tools
# Edit these values to match your setup

# Main repository location
export DISTILL_REPO_BASE="${DISTILL_REPO_BASE:-$HOME/workspace/triple-distill}"

# Where to create worktrees
export DISTILL_WORKTREE_BASE="${DISTILL_WORKTREE_BASE:-$HOME/workspace/lets-distill}"

# History file location
export DISTILL_HISTORY_FILE="${DISTILL_HISTORY_FILE:-$HOME/.lets-distill-history}"

# Default main branch name
export DISTILL_MAIN_BRANCH="${DISTILL_MAIN_BRANCH:-main}"

# Scripts directory (auto-detected)
export DISTILL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"