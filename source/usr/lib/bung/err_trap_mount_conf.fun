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
# Name: err_trap_mount_conf
# Purpose: 
#   Error traps values from the configuration file's mount configuration from
#   both Mount and Snapshot lines.
# Arguments: none
# Global variable usage: adds any error message to emsg
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_mount_conf {
    fct "${FUNCNAME[0]}" started
    local buf cmd found_flag fs_file fs_spec i my_rc rc usage_warning
    local -r email_regex='^[A-Za-z0-9._%+-]+(@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})?$'
    local -r mount_o_option_test_regex='[[:space:]]'
    local -r mount_fs_spec_remote_regex='^([^/]*:|//)'
    local -r mount_fs_spec_label='^LABEL='
    local -r mount_fs_spec_uuid='^UUID='

    # Initialise
    # ~~~~~~~~~~
    local initial_emsg=$emsg
    emsg=

    # For each Mount line and Snapshot line in the configuration file
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=mount_idx;i++))
    do
        # fs_spec
        # ~~~~~~~
        # * Do not check snapshots (they should not exist yet)
        # * Do not check empty fs_spec (postprocess_mount_conf failed to set it)
        # * Do not check remote fs_spec (difficult to check; mount command will
        #   generate error message)
        fs_spec=${mount_fs_spec[i]:-}    # Not initialised for snapshots
        if [[ ${mount_snapshot_idx[i]} -eq -1 \
            && $fs_spec != '' \
            && ! $fs_spec =~ $mount_fs_spec_remote_regex \
            && ! -e $fs_spec \
        ]]; then
            emsg+=$msg_lf"Invalid Mount fs_spec value '"
            emsg+="${mount_fs_spec_conf[i]}' ($fs_spec; does not exist)"
        fi

        # fs_file
        # ~~~~~~~
        # In case it does not exist, do not generate an error if it may be in a
        # file system that is to be mounted (if it does not then exist, a
        # meaningful error will be generated when the mount command fails)
        fs_file=${mount_fs_file[i]}
        if [[ ! -e $fs_file ]]; then
            found_flag=$false
            for ((j=0;j<=mount_idx;j++))
            do
                ((j==i)) && continue
                if [[ $fs_file =~ ^${mount_fs_file[j]} ]]; then
                    found_flag=$true
                    break
                fi
            done
            if [[ ! $found_flag ]]; then
                msg I "fs_file (mount point) $fs_file does not exist; making it"
                cmd=(mkdir -p "$fs_file")
                buf=$("${cmd[@]}" 2>&1)
                rc=$?
                if ((rc!=0)) || [[ $buf != '' ]]; then
                    # Warning not error to allow remaining error traps to run
                    msg W "${cmd[*]}: rc: $rc, output $buf"
                    emsg+=$msg_lf
                    emsg+="Invalid Mount fs_file value '$fs_file' (does not exist)"
                fi
            fi
        fi

        # mount -o option value
        # ~~~~~~~~~~~~~~~~~~~~~
        if [[ ${mount_o_option[i]} != '' \
            && ${mount_o_option[i]} =~ $mount_o_option_test_regex ]]; then
            emsg+=$msg_lf"Invalid Mount options= value ${mount_o_option[i]} (may not contain spaces)"
        fi
    done
    
    if [[ $emsg = '' ]]; then
        my_rc=0
        emsg=$initial_emsg
        if [[ $debugging_flag ]]; then
            for ((i=0;i<=mount_idx;i++))
            do
                msg D "\${mount_fs_spec_conf[$i]}: ${mount_fs_spec_conf[i]}"
                msg D "\${mount_fs_file[$i]}: ${mount_fs_file[i]}"
                msg D "\${mount_o_option[$i]}: ${mount_o_option[i]}"
            done
        fi
    else
        my_rc=1
        emsg=$initial_emsg$emsg
    fi
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function err_trap_mount_conf
# vim: filetype=bash:
