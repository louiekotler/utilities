#!/bin/bash
set -e

# new-repo — create a GitHub repo from repo-template, clone it, and set the
# backup secrets.
#
# The template carries the Dropbox backup workflow but GitHub never copies
# secrets with a template, so a repo made through the web UI or a bare
# `gh repo create` starts out with a backup that silently fails. This does
# all three steps so that cannot happen.
#
#   new-repo <name> [--public] [--description "..."]
#
# Repos are created private by default; flip to public yourself once you've
# looked over what's in them.

OWNER="${GITHUB_OWNER:-louiekotler}"
TEMPLATE="$OWNER/repo-template"
DEV_DIR="${DEV_DIR:-$HOME/Development}"
VISIBILITY="--private"
DESCRIPTION=""
NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --public)      VISIBILITY="--public"; shift ;;
    --private)     VISIBILITY="--private"; shift ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    -h|--help)     sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)            echo "! unknown option: $1" >&2; exit 1 ;;
    *)             NAME="$1"; shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "! usage: new-repo <name> [--public] [--description \"...\"]" >&2
  exit 1
fi

if [ -e "$DEV_DIR/$NAME" ]; then
  echo "! $DEV_DIR/$NAME already exists" >&2
  exit 1
fi

echo "==> Creating $OWNER/$NAME from $TEMPLATE ($VISIBILITY)"
create_args=(--template "$TEMPLATE" "$VISIBILITY")
[ -n "$DESCRIPTION" ] && create_args+=(--description "$DESCRIPTION")
gh repo create "$OWNER/$NAME" "${create_args[@]}"

echo "==> Cloning into $DEV_DIR/$NAME"
git clone -q "https://github.com/$OWNER/$NAME.git" "$DEV_DIR/$NAME"

# Templates do not carry hooks, and clone does not apply init.templateDir.
ln -sf "$DEV_DIR/utilities/git-template/hooks/pre-commit" \
       "$DEV_DIR/$NAME/.git/hooks/pre-commit"

echo "==> Setting the backup secrets"
backup-secrets apply "$NAME"

echo
echo "Ready: $DEV_DIR/$NAME"
echo "  https://github.com/$OWNER/$NAME"
