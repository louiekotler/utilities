#!/bin/bash
set -e

# install.sh — bootstrap this machine from the utilities repo.
#
# Idempotent and safe to re-run: every step checks what's already in place
# before touching anything. It never edits ~/.zshrc beyond appending one
# guarded block, and never touches ~/.zshoverrides once it exists.
#
#   1. Symlink every executable script in this repo into ~/.local/bin
#   2. Install oh-my-zsh (without touching ~/.zshrc) + a few plugins
#   3. Symlink zsh/utilities.plugin.zsh into oh-my-zsh's custom plugins
#   4. Create ~/.zshoverrides if missing (local, untracked, left alone)
#   5. Append one guarded block to ~/.zshrc that wires it all up
#   6. Fill in missing git identity config

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "utilities repo: $REPO_DIR"
echo

# --------- 1. symlink scripts ----------
SCRIPTS_DIR="$REPO_DIR/scripts"
echo "==> Symlinking scripts from $SCRIPTS_DIR into $BIN_DIR"
mkdir -p "$BIN_DIR"

if [ -d "$SCRIPTS_DIR" ]; then
  while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    name="${base%.*}"          # drop extension
    name="${name//_/-}"        # underscores -> hyphens
    target="$BIN_DIR/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "  ! skipping $name: $target already exists and isn't a symlink we manage"
      continue
    fi

    ln -sf "$file" "$target"
    echo "  $name -> $file"
  done < <(find "$SCRIPTS_DIR" -type f -perm +111 -print0)
fi
echo

# --------- 2. oh-my-zsh ----------
echo "==> oh-my-zsh"
if ! command -v zsh >/dev/null; then
  echo "  ! zsh not found. Install zsh first, then re-run this script."
  exit 1
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "  oh-my-zsh already installed, skipping"
else
  echo "  installing oh-my-zsh (KEEP_ZSHRC=yes — will not touch ~/.zshrc)"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone_plugin() {
  local name="$1" url="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"
  if [ -d "$dest" ]; then
    echo "  $name already installed, skipping"
  else
    git clone --depth 1 "$url" "$dest"
  fi
}

clone_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting

if command -v fzf >/dev/null; then
  echo "  fzf already installed, skipping"
elif command -v brew >/dev/null; then
  echo "  installing fzf via Homebrew"
  brew install fzf
else
  echo "  installing fzf from source"
  FZF_DIR="$HOME/.fzf"
  [ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR"
  git clone --depth 1 https://github.com/junegunn/fzf "$FZF_DIR"
  "$FZF_DIR/install" --key-bindings --completion --no-update-rc
fi

# --------- 3. symlink our custom plugin ----------
PLUGIN_DIR="$ZSH_CUSTOM/plugins/utilities"
mkdir -p "$PLUGIN_DIR"
ln -sf "$REPO_DIR/zsh/utilities.plugin.zsh" "$PLUGIN_DIR/utilities.plugin.zsh"
echo "  utilities plugin symlinked into $PLUGIN_DIR"
echo

# --------- 4. local overrides file ----------
if [ -f "$HOME/.zshoverrides" ]; then
  echo "==> ~/.zshoverrides already exists, leaving it alone"
else
  echo "==> Creating empty ~/.zshoverrides"
  cat > "$HOME/.zshoverrides" << 'EOF'
# Local, untracked shell customizations for this machine only.
# Sourced automatically by the "utilities" oh-my-zsh plugin.
EOF
fi
echo

# --------- 5. wire it into ~/.zshrc ----------
echo "==> ~/.zshrc"
MARKER_START="# >>> louie-utilities >>>"
MARKER_END="# <<< louie-utilities <<<"
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

if grep -qF "$MARKER_START" "$ZSHRC"; then
  echo "  already configured, skipping"
elif grep -qF "oh-my-zsh.sh" "$ZSHRC"; then
  echo "  ! ~/.zshrc already sources oh-my-zsh some other way — not auto-appending."
  echo "    Add 'utilities' to your existing plugins=(...) line by hand."
else
  {
    echo ""
    echo "$MARKER_START"
    echo 'export ZSH="$HOME/.oh-my-zsh"'
    echo 'ZSH_THEME=""'
    echo "plugins=(git utilities fzf zsh-autosuggestions zsh-syntax-highlighting)"
    echo 'source "$ZSH/oh-my-zsh.sh"'
    echo "$MARKER_END"
  } >> "$ZSHRC"
  echo "  appended bootstrap block"
fi
echo

# --------- 6. git identity ----------
echo "==> git identity"
GIT_EMAIL="louie9479@gmail.com"
GIT_NAME="Louie Kotler"
GIT_EDITOR="vi"

git config --global user.email >/dev/null 2>&1 || { git config --global user.email "$GIT_EMAIL"; echo "  set user.email"; }
git config --global user.name >/dev/null 2>&1 || { git config --global user.name "$GIT_NAME"; echo "  set user.name"; }
git config --global core.editor >/dev/null 2>&1 || { git config --global core.editor "$GIT_EDITOR"; echo "  set core.editor"; }
echo "  (only fills in keys that weren't already set)"
echo

echo "Done ✔  Open a new terminal, or run: source ~/.zshrc"
