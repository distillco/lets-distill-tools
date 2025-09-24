#!/bin/bash

# Distill Task Management Aliases and Functions
# Add this to your ~/.bashrc or ~/.zshrc:
# source ~/workspace/lets-distill-tools/distill-aliases.sh

# Set the lets-distill tools directory explicitly
export LETS_DISTILL_DIR="$HOME/workspace/lets-distill-tools"

# Load configuration directly
export DISTILL_REPO_BASE="${DISTILL_REPO_BASE:-$HOME/workspace/triple-distill}"
export LETS_DISTILL_WORKTREE_BASE="${LETS_DISTILL_WORKTREE_BASE:-$HOME/workspace/lets-distill}"
export LETS_DISTILL_HISTORY_FILE="${LETS_DISTILL_HISTORY_FILE:-$HOME/.lets-distill-history}"
export LETS_DISTILL_MAIN_BRANCH="${LETS_DISTILL_MAIN_BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Short aliases
alias dc='distill-clean'
alias dcm='distill-clean --merged'
alias dcs='distill-clean --status'

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

    # Try to fetch PR details via gh CLI
    local pr_title=""
    local pr_status=""
    local pr_branch=""

    if command -v gh >/dev/null 2>&1; then
        echo -e "${BLUE}🔍 Fetching PR #$pr_num details...${NC}"

        # Change to the main repo to run gh commands
        local current_dir=$(pwd)
        cd "$DISTILL_REPO_BASE" 2>/dev/null || cd "$current_dir"

        # Get PR details
        pr_title=$(gh pr view "$pr_num" --json title -q .title 2>/dev/null || echo "")
        pr_status=$(gh pr view "$pr_num" --json state -q .state 2>/dev/null || echo "")
        pr_branch=$(gh pr view "$pr_num" --json headRefName -q .headRefName 2>/dev/null || echo "")
        pr_url=$(gh pr view "$pr_num" --json url -q .url 2>/dev/null || echo "")

        cd "$current_dir"

        if [ -n "$pr_title" ]; then
            echo -e "${GREEN}📋 Found PR: $pr_title${NC}"
            echo -e "${BLUE}📊 Status: $pr_status${NC}"
            if [ -n "$pr_branch" ]; then
                echo -e "${BLUE}🌿 Branch: $pr_branch${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Could not fetch PR details (may not exist or no access)${NC}"
        fi
        echo ""
    fi

    # Create the task workspace
    output=$(lets-distill "review-pr-$pr_num")
    exit_code=$?

    # Print the output
    echo "$output"

    # If successful, add PR details to task info
    if [ $exit_code -eq 0 ]; then
        worktree_dir=$(echo "$output" | grep "^WORKTREE_DIR:" | cut -d: -f2-)
        if [ -n "$worktree_dir" ] && [ -f "$worktree_dir/.task-info" ]; then
            if [ -n "$pr_title" ]; then
                echo "" >> "$worktree_dir/.task-info"
                echo "## PR Details:" >> "$worktree_dir/.task-info"
                echo "- **Title:** $pr_title" >> "$worktree_dir/.task-info"
                echo "- **Status:** $pr_status" >> "$worktree_dir/.task-info"
                echo "- **PR Number:** #$pr_num" >> "$worktree_dir/.task-info"
                if [ -n "$pr_url" ]; then
                    echo "- **URL:** $pr_url" >> "$worktree_dir/.task-info"
                fi
                if [ -n "$pr_branch" ]; then
                    echo "- **Source Branch:** $pr_branch" >> "$worktree_dir/.task-info"
                fi
                echo "- **Fetched:** $(date)" >> "$worktree_dir/.task-info"
            fi
        fi

        # Change to the worktree directory
        if [ -n "$worktree_dir" ]; then
            cd "$worktree_dir"
        fi
    fi

    return $exit_code
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