#!/bin/bash
set -e

# backup-secrets — manage the DROPBOX_* secrets the backup workflow needs.
#
# GitHub template repos copy files but never secrets, so a repo created from
# repo-template still has a workflow that fails until these are set. Values
# live in the login keychain; nothing is written to disk in the clear.
#
#   backup-secrets store            prompt for the three values, save them
#   backup-secrets apply [repo...]  push them to repos (default: any missing)
#   backup-secrets check            report which repos are missing them

KEYS=(DROPBOX_CLIENT_ID DROPBOX_CLIENT_SECRET DROPBOX_REFRESH_TOKEN)
SERVICE_PREFIX="dropbox-backup"
OWNER="${GITHUB_OWNER:-louiekotler}"

keychain_get() {
  security find-generic-password -s "$SERVICE_PREFIX-$1" -w 2>/dev/null
}

keychain_set() {
  security add-generic-password -U -s "$SERVICE_PREFIX-$1" -a "$USER" -w "$2"
}

cmd_store() {
  echo "Storing Dropbox backup credentials in your login keychain."
  echo "Get them from https://www.dropbox.com/developers/apps (see personal-workflows/README.md)."
  echo
  for key in "${KEYS[@]}"; do
    printf "  %s: " "$key"
    read -rs value
    echo
    if [ -z "$value" ]; then
      echo "  ! empty, aborting"; exit 1
    fi
    keychain_set "$key" "$value"
  done
  echo
  echo "Saved. Run 'backup-secrets apply' to push them to repos that need them."
}

require_stored() {
  for key in "${KEYS[@]}"; do
    if ! keychain_get "$key" >/dev/null; then
      echo "! $key is not in the keychain. Run: backup-secrets store" >&2
      exit 1
    fi
  done
}

# Repo names whose local checkout has a backup workflow. A workflow committed
# but not yet pushed is invisible to the API, and that is exactly the moment
# this gets run, so match on the remote URL rather than the directory name --
# the two differ (candela-homekit -> yeelight-candela-homekit).
local_backed_up_repos() {
  local dir url name
  for dir in "${DEV_DIR:-$HOME/Development}"/*/; do
    [ -d "$dir/.git" ] || continue
    ls "$dir".github/workflows/backup*.yml >/dev/null 2>&1 || continue
    url=$(git -C "$dir" remote get-url origin 2>/dev/null) || continue
    name=$(basename "$url" .git)
    echo "$name"
  done
}

repos_missing_secrets() {
  local local_repos
  local_repos=$(local_backed_up_repos)
  gh repo list "$OWNER" --limit 100 --no-archived \
    --json name,isFork --jq '.[] | select(.isFork | not) | .name' |
  while read -r repo; do
    # A repo with no backup workflow does not need the secrets. gh api prints
    # its 404 body to stdout, so trust the exit status rather than the output.
    local names
    names=$(gh api "repos/$OWNER/$repo/contents/.github/workflows" \
              --jq '.[].name' 2>/dev/null) || names=""
    if ! echo "$names" | grep -q '^backup'; then
      echo "$local_repos" | grep -qxF "$repo" || continue
    fi
    [ "$(gh secret list --repo "$OWNER/$repo" 2>/dev/null | wc -l)" -ge 3 ] && continue
    echo "$repo"
  done
}

cmd_apply() {
  require_stored
  local repos
  repos=("$@")
  if [ ${#repos[@]} -eq 0 ]; then
    echo "==> Finding repos with a backup workflow but no secrets"
    # bash 3.2 on macOS has no mapfile
    while IFS= read -r found_repo; do
      repos+=("$found_repo")
    done < <(repos_missing_secrets)
    [ ${#repos[@]} -eq 0 ] && { echo "  nothing to do"; return; }
  fi
  for repo in "${repos[@]}"; do
    echo "==> $OWNER/$repo"
    for key in "${KEYS[@]}"; do
      keychain_get "$key" | gh secret set "$key" --repo "$OWNER/$repo" >/dev/null
      echo "  set $key"
    done
  done
  echo
  echo "Done. The next push to each repo will back it up."
}

cmd_check() {
  echo "==> Repos with a backup workflow but fewer than 3 secrets"
  local found
  found=$(repos_missing_secrets)
  if [ -z "$found" ]; then
    echo "  none — every backed-up repo has its secrets"
  else
    echo "$found" | sed 's/^/  /'
  fi
}

case "${1:-}" in
  store) cmd_store ;;
  apply) shift; cmd_apply "$@" ;;
  check) cmd_check ;;
  *) sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
