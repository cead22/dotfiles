source ~/.bashrc

export PATH="/usr/local/sbin:$PATH"

# rbenv used for mobile development
# export PATH="$HOME/.rbenv/bin:$PATH"
# eval "$(rbenv init -)"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Set PATH, MANPATH, etc., for Homebrew on macOS.
if [ "$(uname -s)" = "Darwin" ] && [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# uv
export PATH="/Users/carlos/.local/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
