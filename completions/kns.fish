complete -c kns -f -a "(kubectl get namespaces -o name | string replace \"namespace/\" \"\")"
