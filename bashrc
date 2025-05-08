# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace
# no duplicate entries
HISTCONTROL=ignoredups:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
# big big history
HISTSIZE=10000000
HISTFILESIZE=10000000


# append to history, don't overwrite it
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

export EDITOR='nvim'
export BASH_SILENCE_DEPRECATION_WARNING=1
export SALTFAB_DIR=~/Expensidev/Ops-Configs/saltfab
export BASTION_USER=carlos

# set a fancy prompt (non-color, unless we know we "want" color)
#case "$TERM" in
#    xterm-color) color_prompt=no;;
#esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

unset color_prompt force_color_prompt

# Load aliases from ~/.aliases file
if [ -f ~/.aliases ]; then
    . ~/.aliases
fi

# Load extra settings
if [ -f ~/.extra ]; then
    . ~/.extra
fi

function parse_git_dirty {
    if ! git ls-files >& /dev/null; then
        echo ""
    else
        [[ $(git diff --shortstat) ]] && echo "*"
    fi
}
function parse_git_dirty {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git diff-index --quiet HEAD -- || echo "*"
    else
        echo ""
    fi
}

function get_branch_color {
    if ! git ls-files >& /dev/null; then
        echo ""
    else
        local dirty=$(parse_git_dirty)
        if [[ $dirty == '*' ]]
        then
            echo "\[\033[31m\]"
        else
            echo "\[\033[32m\]"
        fi
    fi
}

function twolastdirs {
tmp=${PWD%/*/*};
[ ${#tmp} -gt 0 -a "$tmp" != "$PWD" ] && echo ${PWD:${#tmp}+1} || echo $PWD;
}
function color_my_prompt {
    history -a
    local host="\[\033[01;36m\]\h"
    local dircolor="\[\033[01;36m\]"
    local dir="\W"
    local twolastdirs="$(twolastdirs)"
    local branch_color=$(get_branch_color)
    local git_branch='`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\(\\\\\1\)\ /`'
    local last_color="\[\033[00m\]"
    local prompt_symbol="$"
    export PS1="$dircolor$twolastdirs $branch_color$git_branch$auth_status_circle$prompt_symbol$last_color "
}
PROMPT_COMMAND=color_my_prompt

source ~/.git-completion.bash
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

cdnvm() {
    command cd "$@";
    nvm_path=$(nvm_find_up .nvmrc | tr -d '\n')

    # If there are no .nvmrc file, use the default nvm version
    if [[ ! $nvm_path = *[^[:space:]]* ]]; then

        declare default_version;
        default_version=$(nvm version default);

        # If there is no default version, set it to `node`
        # This will use the latest version on your machine
        if [[ $default_version == "N/A" ]]; then
            nvm alias default node;
            default_version=$(nvm version default);
        fi

        # If the current version is not the default version, set it to use the default version
        if [[ $(nvm current) != "$default_version" ]]; then
            nvm use default;
        fi

    elif [[ -s $nvm_path/.nvmrc && -r $nvm_path/.nvmrc ]]; then
        declare nvm_version
        nvm_version=$(<"$nvm_path"/.nvmrc)

        declare locally_resolved_nvm_version
        # `nvm ls` will check all locally-available versions
        # If there are multiple matching versions, take the latest one
        # Remove the `->` and `*` characters and spaces
        # `locally_resolved_nvm_version` will be `N/A` if no local versions are found
        locally_resolved_nvm_version=$(nvm ls --no-colors "$nvm_version" | tail -1 | tr -d '\->*' | tr -d '[:space:]')

        # If it is not already installed, install it
        # `nvm install` will implicitly use the newly-installed version
        if [[ "$locally_resolved_nvm_version" == "N/A" ]]; then
            nvm install "$nvm_version";
        elif [[ $(nvm current) != "$locally_resolved_nvm_version" ]]; then
            nvm use "$nvm_version";
        fi
    fi
}
# alias cd='cdnvm'
cd "$PWD"

# nvm use 14.19.3

# For new dot android development
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

CA_CERT_PATH="/Users/carlos/Expensidev/Ops-Configs/saltfab/cacert.pem"

if [ -f "$CA_CERT_PATH" ]; then
    export NODE_EXTRA_CA_CERTS="$CA_CERT_PATH"
    export AWS_CA_BUNDLE="$CA_CERT_PATH"
    export SSL_CERT_FILE="$CA_CERT_PATH"
    export CURL_CA_BUNDLE="$CA_CERT_PATH"
    export BUNDLE_SSL_CA_CERT="$CA_CERT_PATH"
    export REQUESTS_CA_BUNDLE="$CA_CERT_PATH"
fi
