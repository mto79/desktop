# desktop-cluster (and ocl, which wraps it): the clusters in clusters.conf, and what can be
# done with one.
complete -c desktop-cluster -f
complete -c desktop-cluster -n __fish_use_subcommand -a '(desktop-cluster names 2>/dev/null)' -d cluster
complete -c desktop-cluster -n __fish_use_subcommand -a 'list status names login logout edit pick' -d command
complete -c desktop-cluster -n '__fish_seen_subcommand_from login logout status' -a '(desktop-cluster names 2>/dev/null)' -d cluster
complete -c desktop-cluster -s k -d 'k9s on a cluster' -xa '(desktop-cluster names 2>/dev/null)'
complete -c desktop-cluster -s a -d 'Argo CD on a cluster' -xa '(desktop-cluster names 2>/dev/null)'
complete -c desktop-cluster -s c -d 'its web console' -xa '(desktop-cluster names 2>/dev/null)'
complete -c desktop-cluster -s t -d 'the Talos dashboard' -xa '(desktop-cluster names 2>/dev/null)'
complete -c desktop-cluster -s x -d 'one command against a cluster' -xa '(desktop-cluster names 2>/dev/null)'
complete -c desktop-cluster -s e -d 'its environment, for this shell' -xa '(desktop-cluster names 2>/dev/null)'
