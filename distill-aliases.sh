#!/bin/bash

# Distill Task Management Aliases and Functions
# Add this to your ~/.bashrc or ~/.zshrc:
# source ~/workspace/lets-distill-tools/distill-aliases.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/config.sh"

# Main function to start a new task
lets-distill() {
    # Run the script and capture the output directory
    output=$("$LETS_DISTILL_DIR/lets-distill.sh" "$@")
    exit_code=$?

    # Print the output
    echo "$output"

    # If successful, extract the directory path and cd to it
    if [ $exit_code -eq 0 ]; then
        worktree_dir=$(echo "$output" | grep "^WORKTREE_DIR:" | cut -d: -f2-)
        if [ -n "$worktree_dir" ]; then
            cd "$worktree_dir"
        fi
    fi

    return $exit_code
}

# Alias for quick task creation
alias ld='lets-distill'

# List all active tasks/worktrees
distill-tasks() {
    # Special handling for switch command
    if [ "$1" = "switch" ] || [ "$1" = "sw" ]; then
        output=$("$LETS_DISTILL_DIR/distill-tasks.sh" "$@")
        exit_code=$?

        # Print the output
        echo "$output"

        # If successful, extract the directory path and cd to it
        if [ $exit_code -eq 0 ]; then
            worktree_dir=$(echo "$output" | grep "^WORKTREE_DIR:" | cut -d: -f2-)
            if [ -n "$worktree_dir" ]; then
                cd "$worktree_dir"
            fi
        fi

        return $exit_code
    else
        # For other commands, just run normally
        "$LETS_DISTILL_DIR/distill-tasks.sh" "$@"
    fi
}

# Short aliases
alias dt='distill-tasks'
alias dtl='distill-tasks list'
alias dth='distill-tasks history'
alias dts='distill-tasks switch'

# Clean up old worktrees
distill-clean() {
    "$LETS_DISTILL_DIR/distill-clean.sh" "$@"
}

# Short alias
alias dc='distill-clean'
alias dcm='distill-clean --merged'

# Quick function to jump to the main repo
distill-main() {
    cd "$DISTILL_REPO_BASE"
}

alias dm='distill-main'

# Function to checkout existing branch
checkout-branch() {
    # Run the script and capture the output directory
    output=$("$LETS_DISTILL_DIR/checkout-distill.sh" "$@")
    exit_code=$?

    # Print the output
    echo "$output"

    # If successful, extract the directory path and cd to it
    if [ $exit_code -eq 0 ]; then
        worktree_dir=$(echo "$output" | grep "^WORKTREE_DIR:" | cut -d: -f2-)
        if [ -n "$worktree_dir" ]; then
            cd "$worktree_dir"
        fi
    fi

    return $exit_code
}

# Short alias for checkout
alias co='checkout-branch'

# Function to quickly create a PR review workspace
review-pr() {
    if [ $# -eq 0 ]; then
        echo "Usage: review-pr <PR-number>"
        return 1
    fi

    local pr_num="$1"
    lets-distill "review-pr-$pr_num"
}

# Function to quickly create a fix workspace
fix() {
    if [ $# -eq 0 ]; then
        echo "Usage: fix <description>"
        return 1
    fi

    lets-distill "fix-$*"
}

# Function to quickly create a feature workspace
feature() {
    if [ $# -eq 0 ]; then
        echo "Usage: feature <description>"
        return 1
    fi

    lets-distill "feature-$*"
}

# Function to show current task info if in a worktree
task-info() {
    if [ -f ".task-info" ]; then
        cat .task-info
    else
        echo "Not in a task worktree"
    fi
}

# Function to add notes to current task
task-note() {
    if [ -f ".task-info" ]; then
        echo "" >> .task-info
        echo "- $(date '+%Y-%m-%d %H:%M'): $*" >> .task-info
        echo "Note added to task"
    else
        echo "Not in a task worktree"
    fi
}

# Print available commands on source
echo "Distill task management loaded! Available commands:"
echo "  ld / lets-distill <task>  - Create new task workspace or checkout existing branch"
echo "  co / checkout-branch <br> - Checkout existing branch into worktree"
echo "  dt / distill-tasks        - Manage tasks (list/history/switch)"
echo "  dc / distill-clean        - Clean up old worktrees"
echo "  dm / distill-main         - Jump to main repository"
echo "  review-pr <num>           - Create PR review workspace"
echo "  fix <desc>                - Create fix workspace"
echo "  feature <desc>            - Create feature workspace"
echo "  task-info                 - Show current task info"
echo "  task-note <note>          - Add note to current task"