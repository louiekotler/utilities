# utilities — Louie's oh-my-zsh custom plugin
#
# Edit this file, not $ZSH_CUSTOM/plugins/utilities/utilities.plugin.zsh —
# install.sh symlinks that path to this one.
#
# The prompt and the alert()/del-knownhost()/brew-packages() helpers below are
# adapted from Jay Greco's omz-config (https://github.com/jaygreco/omz-config).
# That includes the closing convention of sourcing ~/.zshoverrides — a
# local, untracked file for anything that's specific to one machine and
# shouldn't live in this repo.

# --------- prompt ----------
PROMPT='%(?.%F{green}➜.%F{red}%? ➜)%f %F{cyan}%n%f [%~$(git_prompt_info)] %#%{$fg[default]%} '
ZSH_THEME_GIT_PROMPT_PREFIX=":%{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# --------- NAS Cloud Server ----------
alias louiecloud="100.118.150.126"
alias cloud="open smb://louie@100.118.150.126/louiecloud"

# --------- Arduino GDB ----------
alias gdb-arduino="sudo $HOME/Library/Arduino15/packages/arduino/tools/arm-none-eabi-gcc/7-2017q4/bin/arm-none-eabi-gdb"

# --------- pyenv ----------
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"

# --------- conda ----------
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/opt/anaconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# --------- git ----------
alias hist="git log --pretty=format:'%x1b[31m%h %x1b[32m%ad %x1b[0m| %x1b[0m%s%x1b[32m%d %x1b[0m[%x1b[35m%an%x1b[0m]' --graph --date=short"
alias hista="git log --pretty=format:'%x1b[31m%h %x1b[32m%ad %x1b[0m| %x1b[0m%s%x1b[32m%d %x1b[0m[%x1b[35m%an%x1b[0m]' --graph --date=short --all"

# --------- scripts symlinked by install.sh ----------
export PATH="$HOME/.local/bin:$PATH"

# --------- helpers (adapted from Jay Greco's omz-config) ----------

# Remove a stale line from ~/.ssh/known_hosts by line number.
del-knownhost() {
    sed -i'.bak' -e "$1d" ~/.ssh/known_hosts
    rm ~/.ssh/known_hosts.bak
}

# Run a command, print how long it took and whether it succeeded, and (if
# ALERT_WEBOOK_URL is set to a Discord or Slack webhook) send a notification.
# No-op notification-wise if the env var isn't set — just prints locally.
alert() {
    CMD="$*"
    START=$SECONDS

    eval "$CMD"

    STATUS="$?"
    T=$((SECONDS-START))
    >&2 echo "$CMD: $STATUS in $T s"

    if [[ -z "$ALERT_WEBOOK_URL" ]]; then
        return
    fi

    if [[ $STATUS -eq 0 ]]; then
        RES="✅"
    else
        RES="❌"
    fi

    which hostname &> /dev/null && readonly HOSTNAME="on $(hostname)"
    MSG="has finished $HOSTNAME in $T sec with exit code:"

    case "$ALERT_WEBOOK_URL" in
        *"discord"*) JSON="{\"content\":\"$RES \`$CMD\` $MSG \`$STATUS\`\"}";;
        *"slack"*) JSON="{\"message\":\"$MSG\", \"cmd\":\"$CMD\", \"result\":\"$RES\", \"exit_code\":\"$STATUS\"}";;
    esac

    curl -d "$JSON" -H "Content-Type: application/json" -X POST $ALERT_WEBOOK_URL
}

if [[ $(uname) == "Darwin" ]]; then
    # List installed Homebrew packages sorted by size.
    brew-packages() {
        brew list | xargs brew info | egrep --color '\d*\.\d*(KB|MB|GB)'
    }
fi

# --------- local, untracked, machine-specific overrides ----------
[ -f ~/.zshoverrides ] && source ~/.zshoverrides
