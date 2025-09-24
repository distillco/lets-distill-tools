#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$LETS_DISTILL_WORKTREE_BASE"
HISTORY_FILE="$LETS_DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Function to get branch status
get_branch_status() {
    local branch="$1"
    local remote_exists=$(git ls-remote --heads origin "$branch" 2>/dev/null)

    if [ -n "$remote_exists" ]; then
        # Check if branch is merged
        if git branch -r --merged origin/main | grep -q "origin/$branch"; then
            echo "merged"
        else
            echo "unmerged"
        fi
    else
        echo "local-only"
    fi
}

# Function to mark a worktree for deletion (fast)
mark_for_deletion() {
    local path="$1"
    local branch="$2"
    local deletion_queue="$WORKTREE_BASE/.deletion-queue"

    echo -e "${YELLOW}Marking worktree for deletion:${NC}"
    echo -e "  Path: $path"
    echo -e "  Branch: $branch"

    # Create deletion queue directory if it doesn't exist
    mkdir -p "$deletion_queue"

    # Get a unique name for the marked directory
    local basename=$(basename "$path")
    local timestamp=$(date +%s)
    local marked_path="$deletion_queue/${basename}-${timestamp}"

    # Move the worktree to deletion queue (fast)
    if mv "$path" "$marked_path" 2>/dev/null; then
        # Remove from git worktree registry (fast)
        git worktree remove "$marked_path" --force 2>/dev/null || git worktree prune

        # Optionally delete the branch
        read -p "Delete local branch '$branch'? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git branch -D "$branch" 2>/dev/null || echo -e "${YELLOW}Branch already deleted or doesn't exist${NC}"
        fi

        echo -e "${GREEN}✅ Worktree marked for deletion (will be cleaned up in background)${NC}"

        # Start background cleanup if not already running
        start_background_cleanup
    else
        echo -e "${RED}Failed to mark worktree for deletion${NC}"
        return 1
    fi
}

# Function to remove a worktree (legacy - now uses mark_for_deletion)
remove_worktree() {
    mark_for_deletion "$1" "$2"
}

# Function to start background cleanup process
start_background_cleanup() {
    local deletion_queue="$WORKTREE_BASE/.deletion-queue"
    local pid_file="$deletion_queue/.cleanup.pid"

    # Check if cleanup is already running
    if [ -f "$pid_file" ]; then
        local existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            # Process is already running
            return 0
        else
            # Stale PID file, remove it
            rm -f "$pid_file"
        fi
    fi

    # Start background cleanup
    (
        echo $$ > "$pid_file"
        cleanup_deletion_queue
        rm -f "$pid_file"
    ) &

    local cleanup_pid=$!
    echo -e "${BLUE}🔧 Started background cleanup (PID: $cleanup_pid)${NC}"
}

# Function to actually delete the marked worktrees
cleanup_deletion_queue() {
    local deletion_queue="$WORKTREE_BASE/.deletion-queue"

    if [ ! -d "$deletion_queue" ]; then
        return 0
    fi

    for marked_dir in "$deletion_queue"/*; do
        if [ -d "$marked_dir" ]; then
            echo "$(date): Deleting marked worktree: $marked_dir" >> "$deletion_queue/.cleanup.log"
            rm -rf "$marked_dir"
            echo "$(date): Completed deletion of: $marked_dir" >> "$deletion_queue/.cleanup.log"
        fi
    done

    # Clean up empty deletion queue
    if [ -z "$(ls -A "$deletion_queue" 2>/dev/null | grep -v '\.cleanup\.')" ]; then
        rm -rf "$deletion_queue"
    fi
}

# Function to show cleanup status
show_cleanup_status() {
    local deletion_queue="$WORKTREE_BASE/.deletion-queue"
    local pid_file="$deletion_queue/.cleanup.pid"
    local log_file="$deletion_queue/.cleanup.log"

    echo -e "${CYAN}🔧 Background Cleanup Status${NC}"
    echo ""

    # Check if deletion queue exists
    if [ ! -d "$deletion_queue" ]; then
        echo -e "${GREEN}✅ No worktrees pending deletion${NC}"
        return 0
    fi

    # Count pending deletions
    local pending_count=$(find "$deletion_queue" -maxdepth 1 -type d ! -name ".*" | wc -l)
    if [ "$pending_count" -gt 0 ]; then
        echo -e "${YELLOW}⏳ Worktrees pending deletion: $pending_count${NC}"
        echo "Pending:"
        find "$deletion_queue" -maxdepth 1 -type d ! -name ".*" -exec basename {} \; | sed 's/^/  - /'
        echo ""
    else
        echo -e "${GREEN}✅ No worktrees pending deletion${NC}"
    fi

    # Check if cleanup process is running
    if [ -f "$pid_file" ]; then
        local cleanup_pid=$(cat "$pid_file")
        if kill -0 "$cleanup_pid" 2>/dev/null; then
            echo -e "${GREEN}🔄 Background cleanup is running (PID: $cleanup_pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  Stale cleanup process found (cleaning up)${NC}"
            rm -f "$pid_file"
        fi
    else
        if [ "$pending_count" -gt 0 ]; then
            echo -e "${BLUE}💤 Background cleanup is not running${NC}"
            echo -e "${BLUE}   Run 'dc --cleanup-now' to process pending deletions${NC}"
        fi
    fi

    # Show recent log entries if available
    if [ -f "$log_file" ]; then
        echo ""
        echo -e "${CYAN}📋 Recent cleanup log:${NC}"
        tail -5 "$log_file" | sed 's/^/  /'
    fi
}

# Function to clean old worktrees interactively
clean_interactive() {
    echo -e "${CYAN}🧹 Cleaning Old Worktrees${NC}"
    echo ""

    local found_worktrees=false

    # Store worktree info in arrays to avoid input redirection conflicts
    local worktree_paths=()
    local worktree_branches=()
    local worktree_tasks=()
    local worktree_created=()
    local worktree_ages=()
    local worktree_statuses=()
    local worktree_status_colors=()

    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            found_worktrees=true
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Ensure path has leading slash
            if [[ "$path" != /* ]]; then
                path="/$path"
            fi

            # Skip if path doesn't exist
            if [ ! -d "$path" ]; then
                echo -e "${YELLOW}Orphaned worktree found (path doesn't exist): $path${NC}"
                git worktree prune
                continue
            fi

            # Get task info
            task_name="Unknown"
            created="Unknown"
            if [ -f "$path/.task-info" ]; then
                task_name=$(grep "^# Task:" "$path/.task-info" 2>/dev/null | sed 's/# Task: //' || echo "Unknown")
                created=$(grep "^Created:" "$path/.task-info" 2>/dev/null | sed 's/Created: //' || echo "Unknown")
            fi

            # Get branch status
            status=$(get_branch_status "$branch")
            status_color="$YELLOW"
            status_text="$status"

            case "$status" in
                merged)
                    status_color="$GREEN"
                    status_text="✅ Merged to main"
                    ;;
                unmerged)
                    status_color="$YELLOW"
                    status_text="⚠️  Not merged"
                    ;;
                local-only)
                    status_color="$BLUE"
                    status_text="📍 Local only"
                    ;;
            esac

            # Get directory age
            age="Unknown"
            if [ -d "$path" ]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    created_timestamp=$(stat -f "%B" "$path" 2>/dev/null)
                else
                    # Linux
                    created_timestamp=$(stat -c "%W" "$path" 2>/dev/null)
                fi

                if [ -n "$created_timestamp" ] && [ "$created_timestamp" != "-" ]; then
                    current_timestamp=$(date +%s)
                    age_seconds=$((current_timestamp - created_timestamp))
                    age_days=$((age_seconds / 86400))
                    age="${age_days} days old"
                fi
            fi

            # Store in arrays
            worktree_paths+=("$path")
            worktree_branches+=("$branch")
            worktree_tasks+=("$task_name")
            worktree_created+=("$created")
            worktree_ages+=("$age")
            worktree_statuses+=("$status_text")
            worktree_status_colors+=("$status_color")
        fi
    done < <(git worktree list)

    # Now prompt for each worktree
    for i in "${!worktree_paths[@]}"; do
        path="${worktree_paths[$i]}"
        branch="${worktree_branches[$i]}"
        task_name="${worktree_tasks[$i]}"
        created="${worktree_created[$i]}"
        age="${worktree_ages[$i]}"
        status_text="${worktree_statuses[$i]}"
        status_color="${worktree_status_colors[$i]}"

        # Display worktree info
        echo -e "${CYAN}────────────────────────────────────${NC}"
        echo -e "${GREEN}📂 Task: $task_name${NC}"
        echo -e "   Branch: $branch"
        echo -e "   Status: ${status_color}${status_text}${NC}"
        echo -e "   Created: $created"
        echo -e "   Age: $age"
        echo -e "   Path: $path"

        # Ask for action
        echo ""
        read -p "Remove this worktree? (y/N/q to quit): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Qq]$ ]]; then
            echo -e "${YELLOW}Cleanup cancelled${NC}"
            return
        elif [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_worktree "$path" "$branch"
            echo ""
        fi
    done

    if [ "$found_worktrees" = false ]; then
        echo -e "${GREEN}No worktrees to clean${NC}"
    else
        echo ""
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    fi
}

# Function to clean all merged worktrees automatically
clean_merged() {
    echo -e "${CYAN}🧹 Cleaning Merged Worktrees${NC}"
    echo ""

    local cleaned=0

    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Ensure path has leading slash
            if [[ "$path" != /* ]]; then
                path="/$path"
            fi

            # Skip if path doesn't exist
            if [ ! -d "$path" ]; then
                git worktree prune
                continue
            fi

            # Check if branch is merged
            status=$(get_branch_status "$branch")

            if [ "$status" == "merged" ]; then
                echo -e "${GREEN}Removing merged worktree: $branch${NC}"
                git worktree remove "$path" --force 2>/dev/null || git worktree prune
                git branch -D "$branch" 2>/dev/null || true
                ((cleaned++))
            fi
        fi
    done < <(git worktree list)

    if [ $cleaned -eq 0 ]; then
        echo -e "${YELLOW}No merged worktrees to clean${NC}"
    else
        echo -e "${GREEN}✅ Cleaned $cleaned merged worktree(s)${NC}"
    fi
}

# Function to prune missing worktrees
prune_missing() {
    echo -e "${CYAN}🔧 Pruning missing worktrees...${NC}"
    git worktree prune
    echo -e "${GREEN}✅ Pruned missing worktrees${NC}"
}

# Main function
main() {
    # Ensure we're in the repo to run git commands
    cd "$REPO_BASE" 2>/dev/null || {
        echo -e "${RED}Error: Repository not found at $REPO_BASE${NC}"
        exit 1
    }

    if ! git worktree list > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi

    if [ $# -eq 0 ]; then
        # Interactive mode
        clean_interactive
    else
        case "$1" in
            --merged|-m)
                clean_merged
                ;;
            --prune|-p)
                prune_missing
                ;;
            --all|-a)
                echo -e "${RED}⚠️  This will remove ALL worktrees in $WORKTREE_BASE${NC}"
                read -p "Are you sure? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    while IFS= read -r line; do
                        if [[ $line == *"lets-distill"* ]]; then
                            path=$(echo "$line" | awk '{print $1}')
                            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

                            # Ensure path has leading slash
                            if [[ "$path" != /* ]]; then
                                path="/$path"
                            fi

                            remove_worktree "$path" "$branch"
                        fi
                    done < <(git worktree list)
                fi
                ;;
            --status|-s)
                show_cleanup_status
                ;;
            --cleanup-now)
                echo -e "${CYAN}🧹 Running manual cleanup of deletion queue${NC}"
                cleanup_deletion_queue
                echo -e "${GREEN}✅ Manual cleanup complete${NC}"
                ;;
            --help|-h)
                echo "Usage: distill-clean [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  (no args)      Interactive cleanup"
                echo "  --merged       Remove all merged worktrees"
                echo "  --prune        Prune missing worktrees"
                echo "  --all          Remove ALL worktrees (dangerous!)"
                echo "  --status       Show background cleanup status"
                echo "  --cleanup-now  Manually run background cleanup"
                echo "  --help         Show this help"
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use: distill-clean --help for options"
                exit 1
                ;;
        esac
    fi
}

main "$@"