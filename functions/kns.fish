function kns --description "Switch kubectl namespace with autocomplete"
    if test (count $argv) -eq 0
        kubectl config view --minify --output "jsonpath={..namespace}"
        echo
    else
        kubectl config set-context --current --namespace=$argv
        # Force prompt update
        commandline -f repaint
    end
end
