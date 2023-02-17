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
# Name: err_trap_notification_plug_in_conf
# Purpose:
#   Error traps any "Notification plug-in" configurations
# Arguments: none
# Global variable usage:
#   Read
#     notification_plug_in_idx and notification_plug_in_*[]
#   Write
#     emsg: appended with any conf error messages
#     notification_plug_in_conf_err_flag[]: set $true when any conf errors detected
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_notification_plug_in_conf {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd i my_rc
    local conf_fn conffile executable msg_level initial_function_emsg initial_loop_emsg user user_emsg
    local executable_OK_flag user_OK_flag
    local -r msg_level_re='^(I|W|E)$'

    # Initialise
    # ~~~~~~~~~~
    initial_function_emsg=$emsg

    # For each "Notification plug-in" configuration
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=notification_plug_in_idx;i++))
    do
        # Errors are listed in the order the keywords and sub-keywords are shown in the bung_common (5) man page
        #     executable configuration_file [msg_level = level] [user = user] [no_log]
        # Doing so requires a little complication because, when running as root, checking the configuration_file
        # has to be done as the default or specified user
        initial_loop_emsg=$emsg

        executable_OK_flag=$true
        executable=${notification_plug_in_executable[i]}
        if [[ ${executable#*/} = $executable ]]; then    # executable does not contain a "/"
            if ! hash "$executable" 2>/dev/null; then
                emsg+=$msg_lf"Notification plug-in executable $executable not accessible in \$PATH $PATH"
                executable_OK_flag=$false
            fi
        else
            buf=$(ck_file "$executable" f:rx 2>&1)
            if [[ $buf != '' ]]; then
                emsg+=$msg_lf"Notification plug-in executable: $buf"
                executable_OK_flag=$false
            fi
        fi

        user_emsg=
        user_OK_flag=$true
        if [[ $user_name = root ]]; then    # The user to run the plug-in is ignored when not being run by root
            user=${notification_plug_in_user[i]}
            getent passwd "$user" &>/dev/null
            if (($?!=0)); then
                user_emsg=$msg_lf"Notification plug-in user $user does not exist"
                user_OK_flag=$false
            fi
        fi

        conffile=${notification_plug_in_conffile[i]}
        if [[ ${conffile#*/} = $conffile ]]; then    # conffile does not contain a "/"
            conf_fn=$conf_dir/$conffile
        else
            conf_fn=$conffile
        fi
        buf=$(ck_file "$conf_fn" f:r 2>&1)
        if [[ $buf = '' ]]; then
            [[ $executable_OK_flag && $user_OK_flag ]] \
                && run_notification_plug_in -c "$conf_fn" -C -e "$executable" -u "$user"
        else
            emsg+=$msg_lf"Notification plug-in configuration file: $buf"
        fi

        msg_level=${notification_plug_in_msg_level[i]}
        if [[ ! $msg_level =~ $msg_level_re ]]; then
            emsg+=$msg_lf"Notification plug-in msg_level $msg_level is invalid"
            emsg+=" (did not match $msg_level_re)"
        fi

        [[ $user_emsg != '' ]] && emsg+=$user_emsg
        [[ $emsg != $initial_loop_emsg ]] && notification_plug_in_conf_err_flag[i]=$true
    done

    [[ $emsg = $initial_function_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning $my_rc"
    return $my_rc
}  # end of function err_trap_notification_plug_in_conf
# vim: filetype=bash:
