function dok8s
    echo "Fetching DigitalOcean Kubernetes clusters..."
    
    # Get list of clusters and extract cluster names
    set clusters (doctl kubernetes cluster list --format Name --no-header)
    
    if test (count $clusters) -eq 0
        echo "No Kubernetes clusters found"
        return 1
    end
    
    for cluster in $clusters
        echo "Processing cluster: $cluster"
        
        # Extract the expected new context name
        set new_context (echo $cluster | sed 's/^do-[^-]*-//')
        
        # Check if context already exists
        set existing_context (kubectl config get-contexts -o name | grep -x $new_context)
        
        if test -n "$existing_context"
            echo "Context $new_context already exists, refreshing credentials..."
            # Remove existing context first
            kubectl config delete-context $new_context
        end
        
        # Save kubeconfig for the cluster (this will create do-region-clustername context)
        doctl kubernetes cluster kubeconfig save $cluster
        
        # Get the current context name (will be do-region-clustername format)
        set current_context (kubectl config current-context)
        
        # Rename the context to remove the 'do-region-' prefix
        kubectl config rename-context $current_context $new_context
        
        # Set default namespace based on cluster name pattern
        if string match -q "cloud-*" $new_context
            kubectl config set-context $new_context --namespace=cloud
            echo "✓ Added/refreshed cluster $cluster as context $new_context with namespace 'cloud'"
        else if string match -q "edge-*" $new_context
            kubectl config set-context $new_context --namespace=edge
            echo "✓ Added/refreshed cluster $cluster as context $new_context with namespace 'edge'"
        else
            echo "✓ Added/refreshed cluster $cluster as context $new_context"
        end
    end
    
    echo "All clusters processed successfully!"
end