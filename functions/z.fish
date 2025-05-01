function z -d "Open a project in Zed editor, clone if doesn't exist"
    if test (count $argv) -eq 0
        echo "Usage: z [repository_path]"
        return 1
    end
    set -l project_path $argv[1]
    set -l src_dir "$HOME/src"
    set -l full_path "$src_dir/$project_path"
    # Check if the directory exists
    if not test -d $full_path
        # Extract owner and repo from the path
        set -l parts (string split "/" $project_path)
        if test (count $parts) -lt 2
            echo "Invalid repository path format. Expected format: owner/repo"
            return 1
        end
        set -l owner $parts[1]
        set -l repo $parts[2]
        # Create the owner directory if it doesn't exist
        if not test -d "$src_dir/$owner"
            mkdir -p "$src_dir/$owner"
        end
        # Clone the repository
        set -l clone_url "https://github.com/$owner/$repo.git"
        echo "Repository not found locally. Cloning from $clone_url..."
        git clone $clone_url "$full_path"
        # Check if clone was successful
        if test $status -ne 0
            echo "Failed to clone repository."
            return 1
        end
    end
    # Open the project in Zed
    echo "Opening $full_path in Zed..."
    zed "$full_path"
end
