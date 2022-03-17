Hook scripts
============

Copy tools/git-store-meta/hooks-for-bung/* to .git/hooks

create_tarballs.sh
==================

Before running create_tarballs.sh
* Ensure source/usr/lib/bung/version.scrippet contains script_ver=<version>
  Example
  script_ver=3.2.2
* Ensure the working tree is tagged with the current bung version, example 3.2.2

To run create_tarballs.sh,
* Change directory to the root of the git working tree
* Run tools/create_tarballs.sh -c tools/create_tarballs.conf

The tarballs are created in the current directory
