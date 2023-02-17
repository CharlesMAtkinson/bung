# Copyright (C) 2023 Charles Atkinson
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
    local address buf i msg_level my_rc none_flag
    local -A ass
    local -r address_re='^[A-Za-z0-9._%+-]+(@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})?$'
    local -r msg_level_re='^(I|W|E)$'

    # Initialise
    # ~~~~~~~~~~
    my_rc=0
    none_flag=$false

    # For each address configured
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=email_for_report_idx;i++))
    do
        address=${email_for_report[i]:-}
        [[ ! -v ass[$address] ]] && ass[$address]=set || emsg+=$msg_lf"Email for report: duplicated address $address"
        if [[ $address = none ]]; then
            none_flag=$true
        elif [[ $address =~ $address_re ]]; then
            msg_level=${email_for_report_msg_level[i]:-}
            if [[ ! $msg_level =~ $msg_level_re ]]; then
                emsg+=$msg_lf"Email for report msg_level ($msg_level) is not valid"
                emsg+=" (did not match $msg_level_re)"
                my_rc=1
            fi
        else
            emsg+=$msg_lf"Email for report ($address) is not a valid email address or 'none'"
            my_rc=1
        fi
    done

    if [[ ! $none_flag ]]; then
        if [[ ${email_for_report[0]} != root ]]; then    # Assumed defaulted, not conffed
            if ! hash mailx 2>/dev/null; then
                # A warning not an error so the backup does not fail
                wmsg+=$msg_lf'Email for report is specified but the mailx command is not available'
                my_rc=1
            fi
        fi
    else
        if ((email_for_report_idx>0)); then
            emsg+=$msg_lf"Email for report: when 'none' is specified, no other 'Email for report' values can be specified"
            my_rc=1
        fi
    fi

    fct "${FUNCNAME[0]}" "returning $my_rc"
    return $my_rc
}  # end of function err_trap_email_for_report
# vim: filetype=bash:
