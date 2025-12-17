#!/usr/bin/env bash

if [ -d /opt/kubectx ]; then
  sudo git -C /opt/kubectx pull
else
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
  ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
  ln -s /opt/kubectx/kubens /usr/local/bin/kubens

  mkdir -p ~/.config/fish/completions
  ln -s /opt/kubectx/completion/kubectx.fish ~/.config/fish/completions/
  ln -s /opt/kubectx/completion/kubens.fish ~/.config/fish/completions/

  mkdir -p ~/.kube/clusters/
fi
