function kx --description "Switch kubectl context with autocomplete"
    if test (count $argv) -eq 0
        kubectl config current-context
    else
        kubectl config use-context $argv
    end
end
