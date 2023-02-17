The examples are written to pass inspection by yamllint and by ansible-lint when customised with the .ansible-lint content below.  ALICE is an in-house ansible system

skip_list:
  # no-changed-when applies only to command and shell modules and is task
  # based.  A "# noqa no-changed-when" in a file of tasks disabled
  # no-changed-when checking for the rest of the file (because it is task-based,
  # not line based).  In ALICE, command and shell modules are rarely used to
  # produce a change on a managed host.  Decided to disable no-changed-when
  # checking and add the requirement for changed-when in coding standards
  - no-changed-when

  # empty-string-compare is not useful, ref 
  # https://github.com/ansible-community/ansible-lint/issues/457
  - empty-string-compare

  # fqcn-builtins compliance results in dense code, harder to comprehend
  # https://github.com/ansible-community/ansible-lint/issues/419
  - fqcn-builtins

  # no-handler is impractical, ref 
  # https://github.com/ansible-community/ansible-lint/issues/419
  - no-handler
