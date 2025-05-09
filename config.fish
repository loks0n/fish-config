# pnpm
set -gx PNPM_HOME "/Users/loks0n/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# uv
fish_add_path "/Users/loks0n/.local/bin"
