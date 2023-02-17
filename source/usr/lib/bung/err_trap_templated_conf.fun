# Copyright (C) 2020 Charles Atkinson
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
# Name: err_trap_templated_conf
# Purpose:
#   Error traps the templated_bu-specific configuration
# Arguments: none
# Global variable usage: adds any error message to emsg, prefixed by $msg_lf
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_templated_conf {
    fct "${FUNCNAME[0]}" 'started'
    local array buf i msg_part my_rc old_emsg subkeyword
    local -r fqdn_or_ip_address_re='^(([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}|[[:digit:]]+(.[[:digit:]]+){3})$'

    old_emsg=$emsg
    emsg=

    # template
    # ~~~~~~~~
    if [[ "${template_fn:-}" != '' ]]; then
        buf=$(ck_file "$template_fn" f:r 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"$buf"
    else
        emsg+=$msg_lf'Subkeyword template_file is required'
    fi

    # hostname and associated subkeywords
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ "${hostname:-}" != '' ]]; then
        if [[ "${identity_fn:-}" != '' ]]; then
            buf=$(ck_file "$identity_fn" f:r 2>&1)
            [[ $buf != '' ]] && emsg+=$msg_lf"$buf"
        fi
    else
        msg_part=' is invalid without hostname'
        [[ "${identity_fn:-}" != '' ]] \
            && emsg+=$msg_lf"Subkeyword identity_file$msg_part"
        [[ "${username:-}" != '' ]] \
            && emsg+=$msg_lf"Subkeyword username$msg_part"
    fi

    # dest_dir and associated subkeywords
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ "${dest_dir:-}" != '' ]]; then
        IFS=/ read -ra array <<< "$dest_dir"
        ((${#array[*]}<=3)) \
            && emsg+=$msg_lf'dest_dir must be 3 subdirectories under /'
        buf=$(ck_file "$dest_dir" d:rwx 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"$buf"
        if [[ ${dest_dir_usage_warning:-} != '' ]]; then
            subkeyword=dest_dir_usage_warning
            buf=$dest_dir_usage_warning
            err_trap_uint "$buf" "Invalid $subkeyword" \
                && ((buf>100)) \
                && emsg+=$msg_lf"Invalid $subkeyword % $buf (maximum 100)"
        fi
        err_trap_retention_conf "$retention"
    else
        msg_part=' is invalid without dest_dir'
        [[ "${dest_dir_usage_warning:-}" != '' ]] \
            && emsg+=$msg_lf"Subkeyword dest_dir_usage_warning$msg_part"
        [[ "${retention:-}" != '' ]] \
            && emsg+=$msg_lf"Subkeyword retention$msg_part"
    fi

    # git_root
    # ~~~~~~~~
    if [[ "${git_root_dir:-}" != '' ]]; then
        buf=$(ck_file "$git_root_dir" d:rwx 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"$buf"
    fi

    # TFTP variables
    # ~~~~~~~~~~~~~~
    if [[ "${tftp_root:-}" != '' ]]; then
        buf=$(ck_file "$tftp_root" d:rwx 2>&1)
        [[ $buf != '' ]] && emsg+=$msg_lf"$buf"
        [[ "${tftp_server:-}" = '' ]] \
            && emsg+=$msg_lf"tftp_root is invalid without tftp_server"
    fi
    if [[ "${tftp_server:-}" != '' ]]; then
        [[ ! $tftp_server =~ $fqdn_or_ip_address_re ]] \
            && emsg+=$msg_lf"$tftp_server is not valid FQDN or IPv4 address"
        [[ "${tftp_root:-}" = '' ]] \
            && emsg+=$msg_lf"tftp_server is invalid without tftp_root"
    fi

    [[ $emsg = '' ]] && my_rc=0 || my_rc=1
    emsg=$old_emsg$emsg
    fct "${FUNCNAME[0]}" "returning, rc $my_rc"
    return $my_rc
}  # end of function err_trap_templated_conf
# vim: filetype=bash:
