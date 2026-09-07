Review the staged changes using `git diff --cached` and generate a commit message following the Conventional Commits specification.

Rules:
- Format: `type(scope): concise description`
- Types: feat, fix, refactor, chore, docs, ci, test, style, perf, build
- Scope: infer from the primary file/directory affected (e.g., argocd, gitlab, ansible, helm)
- Subject line must be lowercase, imperative mood, no period, max 72 chars
- If the change is non-trivial, add a body separated by a blank line explaining **why**, not what
- If multiple logical changes are staged, suggest splitting into separate commits
- For infrastructure/GitOps changes, prefer scopes like: helm, argocd, tekton, openshift, terraform, ansible, satellite

Output only the commit message, nothing else. No markdown fencing.
