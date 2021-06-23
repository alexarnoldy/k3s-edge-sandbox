set -o vi
alias kgn="kubectl get nodes -o wide"
alias kgd="kubectl get deployments -o wide"
alias kgp="kubectl get pods -o wide"
alias kgpa="kubectl get pods -o wide --all-namespaces | less" 
alias kg="kubectl get "
alias kaf="kubectl apply -f"
alias kdf="kubectl delete -f"

complete -W "$(echo `cat ~/.all_nodes | cut -f 1 -d ' ' | \
    sed -e s/,.*//g | uniq | grep -v "\["`;)" ssh
