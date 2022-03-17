# Copyright (C) 2013 Charles Atkinson
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
# Name: postprocess_mount_conf
# Purpose: 
#   * Completes the mount data as far as is practicable
# Arguments: none
# Global variable usage:
#   Read:
#       msg_lf
#   Write:
#       emsg: any error messages added
#       mount_fs_spec[]
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function postprocess_mount_conf {
    fct "${FUNCNAME[0]}" started
    local buf i fs_spec_conf

    # The data
    # ~~~~~~~~
    # * mount_fs_file[] is the mountpoint
    # * mount_fs_spec[] is the fs_spec to use when searching /proc/mounts to
    #   see if the file system is mounted and to use in the mount command.
    #   Already filled for snapshots.
    # * mount_fs_spec_conf[] is the fs_spec given in the configuration file.
    # * mount_notification_email[] is already set as configured.
    # * mount_o_option[] is already set as configured.
    # * mount_snapshot_idx[] is -1 unless this is a mount for a snapshot

    # Initialise
    # ~~~~~~~~~~
    local my_emsg=
    local my_rc=0

    # For each set of mount data
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=$mount_idx;i++))
    do
        # Set mount_fs_spec for non-snapshots
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if ((${mount_snapshot_idx[i]}==-1)); then

            # Convert any LABEL=, UUID= or /dev/* symlink
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            fs_spec_conf=${mount_fs_spec_conf[i]}
            if [[ $fs_spec_conf =~ ^LABEL= || $fs_spec_conf =~ ^UUID= ]]; then
                msg D "$fs_spec_conf identified as LABEL or UUID"
                buf=$(findfs "$fs_spec_conf" 2>&1)
                if (($?>0));then
                    my_emsg+=$msg_lf"Cannot find the file system corresponding to '$fs_spec_conf'"
                    continue
                fi
                fs_spec=$buf
            elif [[ $fs_spec_conf =~ ^/dev/ ]]; then
                msg D "$fs_spec_conf identified as /dev/"
                buf=$(readlink --canonicalize-existing -- "$fs_spec_conf" 2>&1)
                if (($?>0)); then
                    [[ $buf = '' ]] \
                        && my_emsg+=$msg_lf"Invalid Mount fs_spec value '$fs_spec_conf' (does not exist)" \
                        || my_emsg+=$msg_lf"Problems running readlink --canonicalize-existing -- $fs_spec_conf: $buf" 
                    continue
                fi  
                fs_spec=$buf
                if [[ $fs_spec =~ ^/dev/dm- ]]; then
                    buf=$(find -L /dev/mapper -samefile "$fs_spec" 2>&1)
                    if [[ ! $buf =~ ^/dev/mapper/ ]]; then
                       my_emsg+=$msg_lf"Problems running find -L /dev/mapper -samefile $fs_spec: $buf" 
                       continue
                    fi
                    fs_spec=$buf
                fi  
            elif [[ $fs_spec_conf =~ ^// ]]; then
                msg D "$fs_spec_conf identified as CIFS"
                fs_spec=$fs_spec_conf
            else
                fs_spec=$fs_spec_conf
            fi  
            [[ $fs_spec_conf != $fs_spec ]] \
                && msg I "Converted $fs_spec_conf to $fs_spec"
            mount_fs_spec[i]=$fs_spec
        fi
    done

    [[ $my_emsg != '' ]] && { my_rc=1; emsg+=$my_emsg; }
    
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function postprocess_mount_conf
# vim: filetype=bash:
