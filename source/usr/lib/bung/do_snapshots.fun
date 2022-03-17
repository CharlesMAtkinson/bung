# Copyright (C) 2018 Charles Atkinson
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
# Name: do_snapshots
# Purpose: creates LVM snapshots
# Arguments: none
# Global variable usage:
#   Read:
#       $true
#   Set:
#       snapshot_size[*] set if not already set (from configuration file)
#       snapshot_created_flag[*] set when the snapshot is created
# Output: none except via msg function
# Other effects: syncs the local file systems
# Return code: always 0; does not return on error
#--------------------------
function do_snapshots {
    fct "${FUNCNAME[0]}" started
    local buf fs_spec i j k lvcreate_cmd mountpoint msg_part
    local my_snapshot_org_vol my_snapshot_vol size umounted_flag

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ((snapshot_idx==-1)); then
        msg D "No snapshots configured in $conf_fn"
        fct "${FUNCNAME[0]}" returning
        return
    fi

    # For each snapshot in the configuration file
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=snapshot_idx;i++))
    do
        my_snapshot_vol=${snapshot_vol[i]}
        my_snapshot_org_vol=${snapshot_org_vol[i]}

        # Deal with any existing snapshot
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # If the snapshot already exists, remove it to avoid the danger of a
        # long term snapshot filling up.
        if [[ -b $my_snapshot_vol ]]; then
            msg W "LVM snapshot volume $my_snapshot_vol already exists"
            fs_spec=${mount_fs_spec[${snapshot_mount_idx[i]}]}
            is_fs_mounted "$fs_spec"
            if [[ ${is_fs_mounted_out+dummy} != '' ]]; then

                # Try to unmount
                # ~~~~~~~~~~~~~~
                for ((j=0;j<${#is_fs_mounted_out[*]};j++))
                do
                    # Programming note: this code is very similar to code in
                    # the finalise function so any changes here should probably
                    # be made there.
                    mountpoint=${is_fs_mounted_out[j]}
                    msg W "$my_snapshot_vol is mounted on $mountpoint.  Attempting to unmount"
                    umounted_flag=$false
                    # TODO: make the sleep length and the maximum loop count configurable?
                    for ((k=0;k<10;k++))
                    do  
                        sleep 2
                        buf=$(umount "$mountpoint" 2>&1)
                        if [[ $buf = '' ]]; then
                            umounted_flag=$true
                            break
                        fi  
                        msg D "${FUNCNAME[0]}: umount failed on pass $j"
                    done
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
            fi
            is_fs_mounted "$fs_spec"
            if [[ ${is_fs_mounted_out+dummy} != '' ]]; then
                msg W "Unable to remove $my_snapshot_vol because it is still mounted; manual intervention required before it fills"
            else
                # The snapshot is not mounted anywhere; remove it
                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                # Programming note: this code is very similar to code in
                # the finalise function so any changes here should probably
                # be made there.
                # lvremove is not reliable.  Useful discussion at
                # https://bugzilla.redhat.com/show_bug.cgi?id=753105
                for ((j=0;j<lvremove_count_max;j++))
                do  
                    # LVM_SUPPRESS_FD_WARNINGS suppresses messages from lvremove matching
                    #     ^File descriptor .* leaked on lvremove invocation\. .*$
                    buf=$(LVM_SUPPRESS_FD_WARNINGS= lvremove --force $my_snapshot_vol 2>&1)
                    lvremove_rc=$?
                    ((lvremove_rc==0)) && break
                done
                if ((lvremove_rc==0)); then
                    msg I "Removed pre-existing snapshot volume $my_snapshot_vol"
                    sleep 5
                else
                    lvremove_failed_flag=$true
                    msg W "Unable to remove snapshot volume $my_snapshot_vol after $lvremove_count_max attempts${msg_lf}Command was:${msg_lf}LVM_SUPPRESS_FD_WARNINGS= lvremove --force $my_snapshot_vol${msg_lf}Output was:$msg_lf$buf"
                    buf=Diagnostics:
                    buf+=$msg_lf$msg_lf
                    buf+=$'lsof:\n'$(lsof $my_snapshot_vol 2>&1 | grep -E -v "WARNING: can't stat\(\) fuse\.gvfs-fuse-daemon file system|Output information may be incomplete")
                    buf+=$msg_lf$msg_lf
                    buf+=$'fuser:\n'$(fuser $my_snapshot_vol 2>&1)
                    buf+=$msg_lf$msg_lf
                    buf+=$'lsblk -f:\n'$(lsblk --fs 2>&1)
                    buf+=$msg_lf$msg_lf
                    buf+=$'dmsetup info -c:\n'$(dmsetup info -c $my_snapshot_vol 2>&1)
                    buf+=$msg_lf$msg_lf
                    buf+=$'dmsetup ls --tree:\n'$(dmsetup info -c $my_snapshot_vol 2>&1)
                    msg I "$buf"
                    msg W "Unable to remove $my_snapshot_vol; manual intervention required before it fills"
                fi 
            fi
        fi

        # Create the snapshot unless it still exists
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ ! -b $my_snapshot_vol ]]; then
            msg D "${FUNCNAME[0]}: snapshot vol $my_snapshot_vol does not already exist"

            # Get size for snapshot volume
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            size=${snapshot_size[i]}
            if [[ $size = '' ]]; then
                # Snapshot size was not specified in the configuration file
                # so use the size of the original volume for safety.
                # Units k (KiB) are chosen for precision.
                buf=$(lvs --units k --options lv_size "$my_snapshot_org_vol" 2>&1)
                (($?>0)) && msg E "Unable to get size of $my_snapshot_org_vol.  $lvs output: $buf" 
                buf=${buf##*LSize*([!0-9])}
                size=${buf%%.*}k
            else
                size="${size//,/}"                # Silently remove any commas
            fi
            msg D "LVM snapshot size: $size"
        
            # Flush file system buffers
            # ~~~~~~~~~~~~~~~~~~~~~~~~~
            ($sync; $sleep 1; $sync; $sleep 1) >/dev/null 2>&1
        
            # Create snapshot volume
            # ~~~~~~~~~~~~~~~~~~~~~~
            # LVM_SUPPRESS_FD_WARNINGS=1 is used to suppress messages like
            # File descriptor .* leaked on lvcreate invocation
            unset lvcreate_cmd
            lvcreate_cmd=(
                lvcreate
                    --size "$size"
                    --snapshot
                    --name "$my_snapshot_vol"
                    "$my_snapshot_org_vol"
            )
            msg D "Running command: ${lvcreate_cmd[*]}"
            buf=$(LVM_SUPPRESS_FD_WARNINGS=1 "${lvcreate_cmd[@]}" 2>&1)
            (($?>0)) && msg E "Unable to create snapshot volume.  lvcreate output: $buf" 
            snapshot_created_flag[i]=$true
            buf=$(readlink --canonicalize-existing "$my_snapshot_vol")
            msg_part="LVM snapshot volume $my_snapshot_vol ($buf) created"
            msg I "$msg_part for $my_snapshot_org_vol with size $size"
        fi
    done
    
    fct "${FUNCNAME[0]}" returning
    return
}  # end of function do_snapshots

source "$BUNG_LIB_DIR/is_fs_mounted.fun" || exit 1
# vim: filetype=bash:
