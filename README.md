# utilities
Louie's personal scripts and shell setup.

## Layout

```
utilities/
├── install.sh                  # the installer, safe to re-run any time
├── scripts/                    # any executable file here becomes a command
│   └── photos/
│       └── compress-photos.sh
└── zsh/
    └── utilities.plugin.zsh    # oh-my-zsh custom plugin: aliases, functions, prompt
```

## Install

```
./install.sh
```

It's idempotent — re-run it any time (e.g. after pulling new scripts) and it
only fills in what's missing.

What it does:
- **Scripts**: symlinks every executable file under `scripts/` (any depth)
  into `~/.local/bin`, named after the file with its extension dropped and
  underscores turned into hyphens (`compress-photos.sh` → `compress-photos`).
- **oh-my-zsh**: installs it if missing, using `KEEP_ZSHRC=yes` so the
  installer never touches `~/.zshrc`. Also installs the `zsh-autosuggestions`,
  `zsh-syntax-highlighting`, and `fzf` plugins from their official upstream
  repos.
- **The `utilities` plugin**: symlinks `zsh/utilities.plugin.zsh` into
  oh-my-zsh's custom plugins folder.
- **`~/.zshrc`**: appends one guarded block (marked
  `# >>> louie-utilities >>>` / `# <<< ... <<<`) that sources oh-my-zsh with
  the plugins above enabled. Nothing else in the file is touched, and running
  install again won't duplicate the block.
- **`~/.zshoverrides`**: created empty if it doesn't exist yet, then left
  alone forever after.
- **git identity**: fills in `user.email` / `user.name` / `core.editor`
  only if they aren't already set.
- **git aliases**: fills in `alias.push` (prints the pushed commit's URL
  after a successful `git push`) only if it isn't already set.

## Adding a new script

Drop an executable file anywhere under `scripts/`, e.g.
`scripts/git/prune-branches.sh`, then run `./install.sh` again. No
registration step — it shows up as `prune-branches` on `$PATH`.

## Editing shell config

- **`zsh/utilities.plugin.zsh`** — tracked in this repo, portable across all
  your machines. Aliases, functions, and prompt config that should follow
  you everywhere. Edit here (not the symlink oh-my-zsh sees).
- **`~/.zshoverrides`** — *not* tracked in this repo, local to one machine.
  For anything that's genuinely specific to a single computer. Sourced
  automatically by the `utilities` plugin.