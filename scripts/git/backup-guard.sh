#!/bin/sh
# Make sure this repo carries the Dropbox backup workflow, installing it if
# it does not. Git seeds this hook into every new repo via init.templateDir,
# so a repo cannot reach its first commit unbacked.
#
# Bypass with: git commit --no-verify

WORKFLOW_DIR=.github/workflows
TEMPLATE="$HOME/Development/repo-template/.github/workflows/backup.yml"

# The caller has been named both backup.yml and backup-to-dropbox.yml over
# time, so match on what it calls rather than on the filename.
if [ -d "$WORKFLOW_DIR" ] &&
   grep -rqF 'personal-workflows/.github/workflows/backup-to-dropbox.yml' "$WORKFLOW_DIR" 2>/dev/null; then
  exit 0
fi

# personal-workflows hosts the reusable workflow and calls its in-tree copy.
if [ -f "$WORKFLOW_DIR/backup-to-dropbox.yml" ] &&
   grep -qF 'workflow_call' "$WORKFLOW_DIR/backup-to-dropbox.yml" 2>/dev/null; then
  exit 0
fi

mkdir -p "$WORKFLOW_DIR" || exit 0

if [ -r "$TEMPLATE" ]; then
  cp "$TEMPLATE" "$WORKFLOW_DIR/backup.yml" || exit 0
else
  # repo-template is the source of truth; this copy only covers it being absent.
  cat > "$WORKFLOW_DIR/backup.yml" <<'YAML' || exit 0
name: Backup to Dropbox

on:
  push:
    branches:
      - '**'  # Run on all branches

jobs:
  backup_to_dropbox:
    uses: louiekotler/personal-workflows/.github/workflows/backup-to-dropbox.yml@main
    secrets:
      DROPBOX_CLIENT_ID: ${{ secrets.DROPBOX_CLIENT_ID }}
      DROPBOX_CLIENT_SECRET: ${{ secrets.DROPBOX_CLIENT_SECRET }}
      DROPBOX_REFRESH_TOKEN: ${{ secrets.DROPBOX_REFRESH_TOKEN }}
YAML
fi

git add "$WORKFLOW_DIR/backup.yml"
echo "backup: $WORKFLOW_DIR/backup.yml was missing — installed it and staged it for this commit"
echo "backup: remember the DROPBOX_* secrets, or the workflow will fail (new-repo sets them)"
