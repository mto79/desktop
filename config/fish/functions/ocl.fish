# ocl is desktop-cluster under its old, short name. A function rather than a link in
# ~/.local/bin: nothing from bin/ is put anywhere else (test/git-test.sh), and fish finds a
# function before any ocl on PATH, the old script included.
function ocl --wraps=desktop-cluster --description 'desktop-cluster: shell, k9s or Argo CD on a cluster'
    desktop-cluster $argv
end
