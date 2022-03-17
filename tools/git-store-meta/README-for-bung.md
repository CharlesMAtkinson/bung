# Introduction
This bung git repository is designed to preserve modification times by incorporating Danny Lin's git-store-meta from https://github.com/danny0838/git-store-meta.  Thanks, Danny :)

git-store-meta is installed under tools/git-store-meta and synchronized by git for user convenience and to make the git repository as re-locatable as practicable

# Procedure
To make git-store-meta effective:

- Create .git/hooks scripts post-checkout, post-merge and pre-commit.  They can be copied from tools/git-store-meta/hooks-for-bung
- Initialise .git\_store\_meta by running `tools/git-store-meta/git-store-meta.pl --store -f mtime`
- Add .git\_store\_meta to the git index by `git add .git_store_meta` or otherwise

