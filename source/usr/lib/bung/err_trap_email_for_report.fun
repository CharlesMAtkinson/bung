# Copyright (C) 2021 Charles Atkinson
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
# Name: err_trap_email_for_report
# Purpose: 
#   Error traps $email_for_report
# Arguments:
#   $1 - $email_for_report
# Global variable usage: adds any error message to emsg
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_email_for_report {
    fct "${FUNCNAME[0]}" 'started'
    local address buf i msg_level my_rc
    local -r address_regex='^[A-Za-z0-9._%+-]+(@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})?$'
    local -r msg_level_regex='^(I|W|E)$'

    # Initialise
    # ~~~~~~~~~~
    my_rc=0

    # For each address configured
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=email_for_report_idx;i++))
    do
        address=${email_for_report[i]:-}
        if [[ ! $address =~ $address_regex ]]; then
            emsg+=$msg_lf"Email for report ($address) is not a valid email address"
            my_rc=1
        fi
        msg_level=${email_for_report_msg_level[i]:-}
        if [[ ! $msg_level =~ $msg_level_regex ]]; then
            emsg+=$msg_lf"Email for report msg_level ($msg_level) is not valid"
            emsg+=" (did not match $msg_level_regex)"
            my_rc=1
        fi
    done

    fct "${FUNCNAME[0]}" "returning $my_rc"
    return $my_rc
}  # end of function err_trap_email_for_report
# vim: filetype=bash:
