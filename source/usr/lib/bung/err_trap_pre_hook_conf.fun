# Copyright (C) 2019 Charles Atkinson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

#--------------------------
# Name: err_trap_pre_hook_conf
# Purpose:
#   Error traps any pre-hook configuration
# Arguments: none
# Global variable usage: adds any error message to emsg, prefixed by $msg_lf
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_pre_hook_conf {
    fct "${FUNCNAME[0]}" 'started'
    local array buf i msg_part my_rc old_emsg subkeyword

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if [[ ${pre_hook_cmd:-} = '' ]]; then
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi

    old_emsg=$emsg
    emsg=

    # pre_hook_cmd
    # ~~~~~~~~~~~~~
    if ! hash "${pre_hook_cmd[0]}" 2>/dev/null; then
        emsg+=$msg_lf"Pre-hook command '${pre_hook_cmd[0]}' not found"
    fi

    # pre_hook_timeout
    # ~~~~~~~~~~~~~~~~~
    local -r timeout_OK_regex='^\+?[[:digit:]]*\.?[[:digit:]]+(|d|h|m|s)$'
    if [[ ! $pre_hook_timeout =~ $timeout_OK_regex ]]; then
        msg_part=$msg_lf"Invalid Pre-hook timeout value '$pre_hook_timeout'"
        emsg+="$msg_part (does not match $timeout_OK_regex)"
    fi

    # pre_hook_timeout_msgclass
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    local -r timeout_msgclass_OK_regex='^(I|W|E)$'
    if [[ ! $pre_hook_timeout_msgclass =~ $timeout_msgclass_OK_regex ]]; then
        msg_part=$msg_lf"Invalid Pre-hook timeout_msgclass value '$pre_hook_timeout_msgclass'"
        emsg+="$msg_part (does not match $timeout_msgclass_OK_regex)"
    fi

    [[ $emsg = '' ]] && my_rc=0 || my_rc=1
    emsg=$old_emsg$emsg
    fct "${FUNCNAME[0]}" "returning, rc $my_rc"
    return $my_rc
}  # end of function err_trap_pre_hook_conf
# vim: filetype=bash:
