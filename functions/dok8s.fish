function dok8s
    echo "Fetching DigitalOcean Kubernetes clusters across contexts..."

    set -l namespace_map \
        "cloud-:cloud" \
        "edge-:edge" \
        "dns-:dns" \
        "sandy-:sandy" \
        "assets-:website"

    set -l auth_lines (doctl auth list)
    if test $status -ne 0
        echo "Failed to list DigitalOcean auth contexts" >&2
        return 1
    end

    set -l original_context (printf "%s\n" $auth_lines | string match -r '.*\(current\)' | string replace -r ' \(current\)$' '')

    set -l target_contexts
    for ctx in $auth_lines
        set -l cleaned (string replace -r ' \(current\)$' '' $ctx)
        if test $cleaned = "default"
            continue
        end
        set target_contexts $target_contexts $cleaned
    end

    if test (count $target_contexts) -eq 0
        echo "No DigitalOcean contexts to process"
        return 1
    end

    for context in $target_contexts
        echo "\n→ Switching to context: $context"
        doctl auth switch --context=$context
        if test $status -ne 0
            echo "Failed to switch to context $context, skipping" >&2
            continue
        end

        set -l clusters (doctl kubernetes cluster list --format Name --no-header)

        if test (count $clusters) -eq 0
            echo "No Kubernetes clusters found for context $context"
            continue
        end

        for cluster in $clusters
            echo "Processing cluster: $cluster"

            # Extract the expected new context name
            set -l new_context (echo $cluster | sed 's/^do-[^-]*-//')

            # Check if context already exists
            set -l existing_context (kubectl config get-contexts -o name | grep -x $new_context)

            if test -n "$existing_context"
                echo "Context $new_context already exists, refreshing credentials..."
                # Remove existing context first so we can refresh
                kubectl config delete-context $new_context
            end

            # Save kubeconfig for the cluster (this will create do-region-clustername context)
            doctl kubernetes cluster kubeconfig save $cluster

            # Get the current context name (will be do-region-clustername format)
            set -l current_context (kubectl config current-context)

            # Rename the context to remove the 'do-region-' prefix
            kubectl config rename-context $current_context $new_context

            set -l namespace ''
            for entry in $namespace_map
                set -l parts (string split ':' $entry)
                set -l prefix $parts[1]
                set -l mapped_namespace $parts[2]

                if string match -q "$prefix*" $new_context
                    set namespace $mapped_namespace
                    break
                end
            end

            if test -n "$namespace"
                kubectl config set-context $new_context --namespace=$namespace
                echo "✓ Added/refreshed cluster $cluster as context $new_context with namespace '$namespace'"
            else
                echo "✓ Added/refreshed cluster $cluster as context $new_context"
            end
        end
    end

    if test -n "$original_context"
        echo "\nRestoring original context: $original_context"
        doctl auth switch --context=$original_context >/dev/null
    end

    echo "\nAll contexts processed successfully!"
end
