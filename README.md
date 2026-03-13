# recover

A safety net for Claude Code sessions on macOS. Takes Time Machine
snapshots before destructive operations and provides tools to find and
recover lost files.

## How it works

**Prevention:** Hook scripts automatically snapshot before the first
Bash command of each conversational turn. If Claude (or you) accidentally
deletes files, force-removes a worktree, or overwrites uncommitted work,
a snapshot exists from moments before.

**Recovery:** `tm-bisect` binary-searches all available Time Machine
snapshots to find the last one matching a predicate. It mounts the
snapshot read-only so you can browse and copy files out.

## Components

```
recover/
├── SKILL.md                  # Claude Code skill: /recover
├── scripts/
│   ├── tm-bisect             # Binary search TM snapshots
│   ├── tm-guard-arm          # Hook: arm snapshot trigger (UserPromptSubmit)
│   ├── tm-guard-snap         # Hook: take snapshot (PreToolUse, Bash only)
│   └── tm-guard-cleanup      # Hook: clean up sentinel (SessionEnd)
└── install.sh                # Installer
```

## Install

```bash
./install.sh
```

This will:
1. Copy scripts to `~/.local/bin/`
2. Install the skill to `~/.claude/skills/recover/`
3. Add hooks to `~/.claude/settings.json` (preserving existing hooks)

## Usage

### Automatic (Claude invokes when needed)

Claude will use the `/recover` skill proactively when it detects data
loss, or when you ask:

> Recover the worktree that was just deleted

> Find the version of src/lib.rs before my last change

> Undo the force-remove

### Manual

```bash
# Find last snapshot containing a file
tm-bisect test -f path/to/deleted/file

# Find last snapshot where file had specific content
tm-bisect sh -c 'grep -q "pattern" path/to/file'

# Recover from the found snapshot
snap="$(tm-bisect test -f path/to/lost/file)"
cp "$snap$HOME/project/path/to/lost/file" ./recovered/
umount "$snap"
```

### How tm-bisect works

1. Lists all Time Machine snapshots (local APFS snapshots)
2. Probes the latest — if it matches, done
3. Scans forward for the earliest match
4. Binary searches between earliest-match and latest-no-match
5. Mounts the result read-only and prints the path

The predicate runs with cwd set to the snapshot equivalent of your
current directory, so relative paths work naturally. `$TM_SNAPSHOT` is
set to the snapshot root for absolute paths.

## Requirements

- macOS with APFS and Time Machine enabled
- `jq` (for parsing hook JSON)
- `tmutil` (ships with macOS)
- `mount_apfs` (ships with macOS)

## Limitations

- **Snapshot granularity:** One per conversational turn (via hooks) plus
  macOS hourly snapshots. Files created and destroyed within a single
  turn's Bash commands are not captured.
- **Data volume only:** Snapshots cover `/Users`, `/Library`, etc. but
  not system binaries.
- **Disk pressure:** macOS prunes oldest snapshots first when space is
  low.

## Uninstall

```bash
# Remove scripts
rm ~/.local/bin/tm-bisect ~/.local/bin/tm-guard-{arm,snap,cleanup}

# Remove skill
rm -rf ~/.claude/skills/recover

# Remove hooks from ~/.claude/settings.json (manually edit out the
# tm-guard entries)
```
