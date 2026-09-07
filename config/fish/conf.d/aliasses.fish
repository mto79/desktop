## Cat
abbr -a cat bat

## Kubernetes
abbr -a k kubectl
abbr -a kx kubectx
abbr -a kn kubens
abbr -a ka kubectl apply
abbr -a kaf kubectl apply -f
abbr -a kd kubectl describe
abbr -a kdel kubectl delete
abbr -a kg kubectl get
abbr -a kgp kubectl get pods
abbr -a kga kubectl get -A
abbr -a kex kubectl exec -it

## Nvim
abbr -a v nvim
abbr -a vi nvim
abbr -a vim nvim

## AI
# Through desktop-agent, which notifies when an agent stops with a non-zero status --
# these run in tmux windows nobody is watching, so a crash otherwise goes unnoticed.
abbr -a c 'desktop-agent opencode'
abbr -a cx 'printf "\033[2J\033[3J\033[H" && desktop-agent claude --allow-dangerously-skip-permissions'

## Container
abbr -a d docker
abbr -a p podman

## Tmux
abbr -a t 'tmux attach || tmux new -s Work'

## Lazygit
abbr -a lg lazygit
