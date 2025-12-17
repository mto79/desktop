# Auto-merge all kubeconfigs in ~/.kube/clusters
set KUBE_DIR $HOME/.kube/clusters

if test -d $KUBE_DIR
    # Get all YAML files and join them with :
    set KUBECONFIG (find $KUBE_DIR -name '*.yaml' | string join ':')
    set -x KUBECONFIG $KUBECONFIG

    # Optional: merge into default kubeconfig
    kubectl config view --merge --flatten >~/.kube/config 2>/dev/null
end
