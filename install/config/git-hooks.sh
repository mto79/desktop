#!/usr/bin/env bash

# Have git run the hooks kept in the repository. .githooks/pre-commit stops a commit that
# would publish something private -- a token, a home directory, whatever the deny list
# names -- and git only looks in .githooks once it is told to. The setting lives in the
# repository's own config, so every worktree of it gets the hook as well.
git -C ~/.local/share/desktop config core.hooksPath .githooks
