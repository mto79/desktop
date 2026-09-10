function bw-unlock --description 'Unlock Bitwarden and export session for Ansible vault'
  set -x BW_SESSION (bw unlock --raw)
end
