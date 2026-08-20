# utilities
Louie's personal scripts and shell setup.

## Layout

```
utilities/
├── install.sh                  # the installer, safe to re-run any time
├── git-template/               # seeded into every new repo by git init
│   └── hooks/
│       └── pre-commit          # shim; the logic lives in backup-guard.sh
├── scripts/                    # any executable file here becomes a command
│   ├── git/
│   │   ├── backup-guard.sh     # guarantees the Dropbox backup workflow
│   │   ├── backup-secrets.sh
│   │   └── new-repo.sh
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
- **git template dir**: points `init.templateDir` at `git-template/`, and
  links its `pre-commit` hook into every repo already under
  `~/Development` that hasn't got its own.

## Repo backups

Every repo is backed up to Dropbox by a GitHub Action, via the reusable
workflow in `personal-workflows`. Two things have to be true for that to
work, and `repo-template` on its own only guarantees the first:

1. `.github/workflows/backup.yml` exists in the repo.
2. `DROPBOX_CLIENT_ID`, `DROPBOX_CLIENT_SECRET` and `DROPBOX_REFRESH_TOKEN`
   are set as Actions secrets. **GitHub never copies secrets from a template
   repo**, so this step is always manual otherwise, and a repo missing them
   has a backup that fails on every push rather than one that's obviously
   absent.

`new-repo` does both:

```
new-repo my-thing                       # private by default
new-repo my-thing --public --description "..."
```

The `pre-commit` hook is the backstop for repos created any other way — the
web UI, a plain `gh repo create`, a bare `git init`. If the backup workflow
is missing when you commit, the hook writes it and stages it, so a repo
can't reach its first commit without one. Bypass with `git commit
--no-verify` in the rare case you mean to.

The hook git installs is only a shim: git *copies* template hooks into new
repos rather than linking them, so the logic sits in `backup-guard.sh` where
editing it reaches every repo at once, not just the ones created afterwards.

Secrets live in the login keychain, never on disk in the clear:

```
backup-secrets store          # prompts once, saves to the keychain
backup-secrets check          # which repos have a backup workflow but no secrets
backup-secrets apply          # push them to every repo that's missing them
backup-secrets apply my-thing # or just one
```

`backup-secrets check` is worth running now and then — it's the only thing
that catches a backup that's silently failing.

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