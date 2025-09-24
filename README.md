# lets-distill - Git Worktree Task Management

A set of bash scripts for managing development tasks using git worktrees, designed for the Distill codebase but usable for any git repository.

## What it does

Creates isolated workspaces for each task/feature/bugfix using git worktrees, allowing you to:
- Switch between tasks without stashing
- Keep dependencies isolated
- Work on multiple PRs simultaneously
- Maintain a clean main workspace

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/lets-distill-tools.git ~/workspace/lets-distill-tools
```

2. Add to your shell configuration (`~/.bashrc` or `~/.zshrc`):
```bash
source ~/workspace/lets-distill-tools/distill-aliases.sh
```

3. Reload your shell or run:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Configuration

Edit the scripts to set your repository location:
- `REPO_BASE`: Path to your main repository (default: `$HOME/workspace/triple-distill`)
- `WORKTREE_BASE`: Where to create worktrees (default: `$HOME/workspace/lets-distill`)

## Commands

### Creating Tasks

```bash
# Create a new task/feature branch
ld fix-auth-bug
lets-distill "implement dark mode"

# Work on existing branch
ld improve-sentry-filtering-matchers
co feature/add-pagination

# Quick task types
review-pr 1234
fix broken-login
feature user-profiles
```

### Managing Tasks

```bash
# List all active tasks
dt
distill-tasks

# Show task history
dt history

# Switch to a task
dt switch auth
dts pagination

# Jump back to main repo
dm
distill-main
```

### Cleaning Up

```bash
# Interactive cleanup
dc
distill-clean

# Remove merged branches
dc --merged

# Clean up orphaned worktrees
dc --prune
```

### Task Notes

```bash
# Show current task info
task-info

# Add a note to current task
task-note "Fixed the race condition in auth flow"
```

## How it Works

1. **New Task**: Creates a new git worktree with a timestamped branch name
2. **Existing Branch**: Checks out existing local or remote branches into a new worktree
3. **Isolation**: Each worktree has its own `node_modules` and git state
4. **Tracking**: Maintains history in `~/.lets-distill-history`
5. **Cleanup**: Removes worktrees and optionally deletes branches

## Worktree Structure

```
~/workspace/lets-distill/
├── fix-auth-bug-20240315-143022/
│   ├── .task-info
│   ├── node_modules/
│   └── [full repo copy]
├── review-pr-1234-20240315-150000/
│   └── [full repo copy]
└── feature-dark-mode-20240316-090000/
    └── [full repo copy]
```

## Files

- `lets-distill.sh` - Main script for creating new tasks
- `checkout-distill.sh` - Check out existing branches
- `distill-tasks.sh` - List and manage active tasks
- `distill-clean.sh` - Clean up old worktrees
- `distill-aliases.sh` - Shell aliases and functions

## Requirements

- Git 2.5+ (for worktree support)
- Bash or Zsh
- npm/node (for JavaScript projects)

## Tips

- Each worktree is independent - you can have different versions of dependencies
- Worktrees share the same git history but have separate working directories
- Use `dc --merged` regularly to clean up completed work
- The `.task-info` file in each worktree tracks task metadata

## License

MIT