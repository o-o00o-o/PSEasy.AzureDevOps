# to make git-hooks folder work for everyone

  git config core.hooksPath .git-hooks

https://medium.com/better-programming/how-to-prevent-git-commit-naming-mistakes-a34c8a7c6ae6

Pre-commit hook

https://medium.com/@ripoche.b/using-global-pre-commit-hook-to-prevent-committing-unwanted-code-edbbf957ad12


Pre-post hook
https://helloacm.com/how-to-prevent-commiting-to-master-develop-branch-by-accidents-using-pre-push-hooks-in-git/


I tried this in a pre-commit file but it gave me an error "error: cannot spawn .git-hooks/pre-commit: No such file or directory"

is it a path thing?

#
# To prevent debug code from being accidentally committed, simply add a comment near your
# debug code containing the keyword !nocommit and this script will abort the commit.
# https://medium.com/@ripoche.b/using-global-pre-commit-hook-to-prevent-committing-unwanted-code-edbbf957ad12
#
#if git commit -v --dry-run | grep '```\s*mermaid' >/dev/null 2>&1
#then
#  echo "Trying to commit mermaid graph with syntax not supported by ADO Wiki."
#  echo "Switch the \`\`\`mermaid for :::mermaid"
#  exit 1
#else
#  exit 0
#fi