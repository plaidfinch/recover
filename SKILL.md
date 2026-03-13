---
name: recover
description: Recover lost or deleted files using Time Machine snapshots. Use when the user asks to undo a mistake, recover deleted files, find a previous version, or browse Time Machine history. Also use proactively when you realize you've caused data loss (force-removed a worktree, deleted files, overwrote uncommitted work).
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[what to recover]"
---

# Time Machine Recovery

Recover lost files by binary-searching Time Machine snapshots with
`tm-bisect`. Snapshots are taken automatically before the first Bash
command of each conversational turn, plus macOS takes hourly snapshots.

The user has asked you to recover: **$ARGUMENTS**

## Step 1: Determine the predicate

Translate the user's description into a `tm-bisect` predicate:

| Lost thing | Predicate |
|:-----------|:----------|
| A deleted file | `test -f path/to/file.rs` |
| A deleted directory | `test -d path/to/dir` |
| A file that contained X | `sh -c 'grep -q "X" path/to/file.rs'` |
| A version before a change | `sh -c '! grep -q "new_thing" path/to/file.rs'` |

If unsure, start broad with `test -e <path>`.

## Step 2: Run tm-bisect

`tm-bisect` runs from the current working directory. The predicate's cwd
is the snapshot equivalent, so **relative paths just work**.

```bash
snap="$(tm-bisect test -f path/to/lost/file.rs)"
```

- Exit 0: prints mounted snapshot path to stdout.
- Exit 1: not found (diagnostics on stderr).

For absolute paths, use `$TM_SNAPSHOT` (set inside the predicate):

```bash
snap="$(tm-bisect sh -c 'test -f "$TM_SNAPSHOT/some/absolute/path"')"
```

## Step 3: Inspect before recovering

Always show the user what you found before overwriting anything.

```bash
# Browse what's in the snapshot
ls "$snap$HOME/project/path/to/"

# Diff against current state
diff -u "$snap$HOME/project/src/lib.rs" ./src/lib.rs

# Then copy
cp "$snap$HOME/project/path/to/file" ./path/to/file

# Or copy a directory
cp -a "$snap$HOME/project/path/to/dir/" ./path/to/dir/
```

## Step 4: Unmount

Always unmount when done:

```bash
umount "$snap"
```

## If not found

The file may have been created and deleted between snapshot boundaries.
Tell the user honestly. Suggest alternatives:

- `git reflog` for recent git commits
- `git fsck --lost-found` for dangling commits (e.g., from force-removed worktrees)
- `git stash list` for stashed changes

## Limitations

- **Per-turn + hourly granularity.** Files existing for less than one
  snapshot interval are not recoverable.
- **Data volume only.** Snapshots capture `/Users`, `/Library`, etc.
  but not system paths.
- **Oldest pruned first.** macOS deletes old snapshots when disk space
  is low.
