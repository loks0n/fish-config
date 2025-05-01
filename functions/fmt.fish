#!/usr/bin/env fish

function fmt -d "Format code and commit changes"
    set -l has_changes 0

    # Check if we're in a git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Error: Not in a git repository"
        return 1
    end

    # Check for composer.json
    if test -f "composer.json"
        echo "Found composer.json, attempting to format PHP code..."

        # Try composer format command
        if test (jq -r '.scripts.format // empty' composer.json 2>/dev/null)
            echo "Running composer format..."
            composer format
            set has_changes 1
        # Try pint directly if no composer format
        else if test -f "./vendor/bin/pint" -o (command -v pint >/dev/null 2>&1)
            echo "Running Laravel Pint..."
            if test -f "./vendor/bin/pint"
                ./vendor/bin/pint
            else
                pint
            end
            set has_changes 1
        else
            echo "No PHP formatter found in composer.json or Pint not available"
        end
    end

    # Check for package.json
    if test -f "package.json"
        echo "Found package.json, attempting to format JavaScript/TypeScript code..."

        # Try npm run format command
        if test (jq -r '.scripts.format // empty' package.json 2>/dev/null)
            echo "Running npm run format..."
            npm run format
            set has_changes 1
        # Try prettier directly if no npm format script
        else if test -f "./node_modules/.bin/prettier" -o (command -v prettier >/dev/null 2>&1)
            echo "Running Prettier..."

            # Check for prettier config files
            for config in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.yaml .prettierrc.yml prettier.config.js .prettierrc.toml
                if test -f $config
                    echo "Using config: $config"
                    break
                end
            end

            if test -f "./node_modules/.bin/prettier"
                ./node_modules/.bin/prettier --write "**/*.{js,jsx,ts,tsx,json,css,scss,md}"
            else
                prettier --write "**/*.{js,jsx,ts,tsx,json,css,scss,md}"
            end
            set has_changes 1
        else
            echo "No JS formatter found in package.json or Prettier not available"
        end
    end

    # Check if we have changes to commit
    if test $has_changes -eq 1
        if git diff --quiet
            echo "No changes to commit after formatting"
            return 0
        end

        # Commit the changes
        echo "Committing formatting changes..."
        git add .
        git commit -m "chore: fmt"

        # Push the changes
        echo "Pushing changes..."
        git push

        echo "Formatting completed and changes pushed!"
    else
        echo "No formatters found or executed"
    end
end
