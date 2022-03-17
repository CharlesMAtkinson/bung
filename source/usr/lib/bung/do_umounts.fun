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
# Name: do_ummounts
# Purpose: unmounts all files systems mounted by the script
# Arguments:
#   $1 index into the mount_* arrays
# Global variables:
#   Read:
#       mount_fs_file[]
#       mount_fs_spec[]
#       mount_fs_spec_conf[]
#       mount_hotplug_flag[]
#       mount_idx
#       mount_o_option[]
#       mount_snapshot_idx[]
#       org_name
# Return code: always 0; does not return on error
#--------------------------
function do_umounts {
    fct "${FUNCNAME[0]}" 'started'
    local buf i j lsof_out mountpoint umounted_flag
    local -r not_mounted_regex='not mounted'

    # For each umount
    # ~~~~~~~~~~~~~~~
    # In reverse order in case there are any mountpoints under mountpoints
    for ((i=mount_done_mountpoint_idx;i>=0;i--))
    do   
        mountpoint=${mount_done_mountpoint[i]}

        # Umount
        # ~~~~~~
        umounted_flag=$false
        #TODO: make the sleep length and the maximum loop count configurable?
        for ((j=0;j<30;j++))
        do   
            # sync before umount to avoid kernel message
            # "INFO: task umount:<PID> blocked for more than 120 seconds"
            sync 
            buf=$(umount "$mountpoint" 2>&1)
            if [[ $buf = '' ]]; then 
                umounted_flag=$true
                break
            elif [[ $buf =~ $not_mounted_regex ]]; then
                msg W "$mountpoint was not mounted"
                umounted_flag=$true
                break
            fi
            msg D "${FUNCNAME[0]}: umount failed on pass $j"
            sleep 1    # Allow conditions to change before next attempt
        done 
        sleep 1    # Allow umount to complete

        # Logging
        # ~~~~~~~
        if [[ $umounted_flag ]]; then 
            msg I "Unmounted $mountpoint"
        else 
            msg W "Problem unmounting $mountpoint: $buf"
            msg D "${FUNCNAME[0]}: lsof command argument: $(readlink --canonicalize-existing -- "$mountpoint")"
            # The grep -v is for a known lsof/.gvfs incompatibility reported as a bug at:
            # https://bugs.launchpad.net/ubuntu/+source/lsof/+bug/662168 
            lsof_out=$'\n'"$(
                lsof -n -P "$(readlink --canonicalize-existing -- "$mountpoint")" 2>&1 \
                | grep -E -v "WARNING: can't stat\(\) fuse\.gvfs-fuse-daemon file system|Output information may be incomplete"
            )"
            msg I "lsof output:$lsof_out"
        fi
    done
    mount_done_mountpoint_idx=-1    # Re-initialise in case any further mounts

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function do_umounts
# vim: filetype=bash:
