function stack \
    --description "Sync a GitHub PR stack (one PR per local commit). Add ‑v for verbose logs."

    # ----------------------------------------------------------------------
    # Requirements
    #   • fish ≥ 3.4  — argparse builtin
    #   • git  ≥ 2.43 — --update-refs convenience when rebasing
    #   • gh   ≥ 2.0 — authenticated; scopes: contents:write, pull_requests:write
    # ----------------------------------------------------------------------

    # Abort early if fish requests completions --------------------------------
    if test (count $argv) -ge 1
        string match -q -- '--fish-completion-script*' $argv[1]; and return 0
    end

    # -------------------- Defaults & flag parsing ---------------------------
    set -l remote origin
    set -l base   (git symbolic-ref --quiet --short refs/remotes/$remote/HEAD | cut -d/ -f2)
    set -l verbose 0
    set -l help 0

    argparse -n stack 'b/base=' 'r/remote=' 'v/verbose' 'h/help' -- $argv ; or return 1
    if set -q _flag_base;   set base   $_flag_base;   end
    if set -q _flag_remote; set remote $_flag_remote; end
    if set -q _flag_verbose; set verbose 1; end
    if set -q _flag_help;
        echo "Usage: stack [options]"
        echo "Sync a GitHub PR stack (one PR per local commit)"
        echo
        echo "Options:"
        echo "  -b, --base=BRANCH    Base branch (default: main or master)"
        echo "  -r, --remote=REMOTE  Remote name (default: origin)"
        echo "  -v, --verbose        Enable verbose output (show detailed logs)"
        echo "  -h, --help           Show this help message"
        return 0
    end

    function _stack__log --argument msg
        if test "$verbose" = "1"
            echo "[stack] $msg"
        end
    end

    # -------------------- Preconditions ------------------------------------
    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        printf "✗ Not a git repository. Please run this command inside a git repository.\n" >&2
        return 1
    end

    _stack__log "Checking working tree cleanliness …"

    set -l dirty 0
    git diff --quiet --ignore-submodules --exit-code;      or set dirty 1
    git diff --cached --quiet --ignore-submodules --exit-code; or set dirty 1
    test -z (git ls-files --others --exclude-standard);    or set dirty 1

    if test $dirty -eq 1
        printf "✗ Working tree is dirty – commit, stage, or stash first.\n" >&2
        return 1
    end

    _stack__log "Fetching $remote/$base …"
    git fetch --quiet $remote $base; or begin
        printf "✗ Could not fetch %s/%s\n" $remote $base >&2
        return 1
    end

    # -------------------- Commits to stack ----------------------------------
    set -l commits (git rev-list --reverse "$remote/$base"..HEAD)
    _stack__log (string join " " "Found" (count $commits) "local commit(s) to stack.")

    if test (count $commits) -eq 0
        printf "Nothing to stack – current branch matches %s/%s.\n" $remote $base
        return 0
    end

    # Record existing remote stack branches (for pruning)
    set -l existing_branches (git ls-remote --heads $remote 'stack/*' | awk '{print $2}' | sed 's@refs/heads/@@')

    set -l prev     $base
    set -l branches
    set -l pr_urls

    # -------------------- Helper fns ----------------------------------------
    function _stack__stdin_to_file
        set -l tmp (mktemp -t stack-body-XXXXXX)
        cat > $tmp
        echo $tmp
    end

    function _stack__create_pr --argument title base head
        set -l file (_stack__stdin_to_file)
        _stack__log "Creating PR for $head → $base …"
        if test "$verbose" = "1"
            echo "DEBUG: gh pr create --base $base --head $head --title \"$title\" --body-file $file --json url -q '.url'"
        end

        # First try to get the PR URL directly if it already exists
        set -l existing_pr (gh pr view $head --json url -q '.url' 2>/dev/null)
        if test $status -eq 0
            _stack__log "Found existing PR for $head: $existing_pr"
            rm -f $file
            echo $existing_pr
            return 0
        end

        # Create new PR
        set -l url (gh pr create \
                        --base $base \
                        --head $head \
                        --title "$title" \
                        --body-file $file \
                        --json url -q '.url' 2>&1)
        set -l rc $status
        rm -f $file

        # Debug output
        if test "$verbose" = "1"
            echo "DEBUG: gh pr create exit code: $rc"
            echo "DEBUG: gh pr create output: $url"

            # Debug specific commands and their outputs
            git rev-parse $head 2>&1
            git rev-parse $base 2>&1
            echo "HEAD: $head, BASE: $base"
            git log --oneline $base..$head
        end

        if test $rc -eq 0
            echo $url
            return 0
        end

        # Log the failure
        _stack__log "Failed to create PR: $url"
        return $rc
    end

    function _stack__edit_pr --argument head --argument title_opt
        set -l file (_stack__stdin_to_file)
        if set -q title_opt
            _stack__log "Updating title/body of PR on $head …"
            gh pr edit $head --title "$title_opt" --body-file $file > /dev/null
        else
            _stack__log "Updating body of PR on $head …"
            gh pr edit $head --body-file $file > /dev/null
        end
        rm -f $file
    end

    # =================== Pass 1 — create / update PRs ======================
    for sha in $commits
        set -l short   (string sub -l 7 $sha)
        set -l branch  stack/$short
        set branches   $branches $branch

        _stack__log "Syncing branch $branch …"
        git branch -f $branch $sha > /dev/null
        git push --quiet --force-with-lease $remote $branch

        set -l title (git show -s --format=%s $sha)
        set -l body  (git show -s --format=%b $sha)
        if test -z "$body"; set body "•"; end

        set -l pr_url
        if test "$verbose" = "1"
            echo "DEBUG: Creating PR from $branch to $prev"
        end
        set pr_url (printf "%s\n" "$body" | _stack__create_pr "$title" $prev $branch)
        if test $status -ne 0
            if test "$verbose" = "1"
                echo "DEBUG: PR creation failed, attempting to get URL..."
            end

            set -l view_url (gh pr view $branch --json url -q '.url' 2>/dev/null)
            set -l view_status $status

            if test "$verbose" = "1"
                echo "DEBUG: gh pr view exit code: $view_status"
                echo "DEBUG: gh pr view URL: $view_url"
            end

            if test $view_status -eq 0
                set pr_url $view_url
                printf "%s\n" "$body" | _stack__edit_pr $branch "$title"
            else
                # Handle the case where both create and view failed
                _stack__log "Both PR creation and PR view failed for $branch"

                # Use the remote URL to construct a proper GitHub PR creation URL
                set -l repo_url (git remote get-url --push $remote | string replace -r '^git@github.com:' 'https://github.com/' | string replace -r '\.git$' '')
                set pr_url "$repo_url/pull/new/$branch"
            end
        end

        set pr_urls $pr_urls $pr_url
        set prev    $branch
    end

    # =================== Pass 2 — add stack links ==========================
    # Create formatted links for each PR URL
    set -l formatted_links
    for url in $pr_urls
        set -a formatted_links "- $url"
    end
    set -l links (string join -- "\n" $formatted_links)
    _stack__log "Adding stack links to PR bodies …"

    for branch in $branches
        set -l sha (git rev-parse $branch)
        set -l body (git show -s --format=%b $sha)
        if test -z "$body"; set body "•"; end

        set -l full_body "$body\n\n### Stack\n$links"
        printf "%s" "$full_body" | _stack__edit_pr $branch
    end

    # =================== Pass 3 — prune orphan branches ====================
    _stack__log "Pruning orphaned stack branches …"
    set -l removed 0
    for old in $existing_branches
        if not contains -- $old $branches
            _stack__log "Deleting orphan branch/PR $old …"
            set -l number (gh pr view $old --json number -q '.number' 2>/dev/null)
            if test -n "$number"
                gh pr close $number --delete-branch --comment "Closing – commit removed from stack." > /dev/null
            else
                git push $remote --delete $old > /dev/null 2> /dev/null
            end
            git branch -D $old 2> /dev/null
            set removed (math $removed + 1)
        end
    end

    # -------------------- Summary -----------------------------------------
    set -l created (count $commits)
    if test $removed -eq 0
        printf "✅ Synced %d stacked PR(s) on '%s' with base '%s'.\n" $created $remote $base
    else
        printf "✅ Synced %d PR(s), pruned %d orphaned PR(s)/branch(es).\n" $created $removed
    end

    echo -e "\nStack URLs (oldest → newest):"
    for url in $formatted_links
        echo $url
    end
end
