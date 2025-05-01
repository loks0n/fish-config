# Completion for z function
function __z_complete
    set -l src_dir "$HOME/src"
    set -l current_token (commandline -ct)
    # If we're at the beginning of the path
    if not string match -q "*/*" $current_token
        # List all directories in ~/src
        for dir in $src_dir/*/
            set -l dirname (string replace -r "^$src_dir/" "" (string trim -r -c "/" $dir))
            if test -n "$dirname"
                echo $dirname
            end
        end
    else
        # We're after the first part, e.g., "owner/"
        set -l parts (string split "/" $current_token)
        set -l owner $parts[1]
        if test -d "$src_dir/$owner"
            # List all repositories for this owner
            for repo in $src_dir/$owner/*/
                set -l reponame (string replace -r "^$src_dir/" "" (string trim -r -c "/" $repo))
                if test "$reponame" != "$owner"
                    echo $reponame
                end
            end
        end
    end
end

# Register the autocomplete function
complete -c z -f -a "(__z_complete)"
