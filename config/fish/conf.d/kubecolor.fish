# kubectl and oc as typed at the prompt go through kubecolor, which runs the real one and
# colours what it prints: get, describe, logs, and the rest. It colours nothing when the
# output is not a terminal, so a pipe or a script reads what kubectl wrote, and it passes
# exec, edit and the like straight through. Scripts, desktop-cluster among them, call the
# command itself and never see these.
if status is-interactive; and command -q kubecolor
    function kubectl --description 'kubectl, coloured by kubecolor'
        command kubecolor $argv
    end
    function oc --description 'oc, coloured by kubecolor'
        KUBECTL_COMMAND=oc command kubecolor $argv
    end
end
