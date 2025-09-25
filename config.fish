# pnpm
set -gx PNPM_HOME "/Users/loks0n/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# uv
fish_add_path "/Users/loks0n/.local/bin"

# aliases
alias lg="lazygit log"
alias k="kubectl"

# git
alias gd="git diff --output-indicator-new=' ' --output-indicator-old=' '"

alias ga="git add"
alias gap="git add --patch"
alias gc="git commit"

alias gs="git switch"
alias gr="git restore"

alias gp="git push"
alias gu="git pull"

alias gl='git log --graph --all --pretty=format:"%C(magenta)%h %C(white) %an  %ar%C(auto)  %D%n%s%n"'
alias gb="git branch"

alias gi="git init"
alias gcl="git clone"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
