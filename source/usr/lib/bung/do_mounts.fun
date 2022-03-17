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

# Programmers' notes: function call tree
#     
#    +-- do_mounts
#        |
#        +-- do_mount
#            |
#            +-- do_mount_command

#--------------------------
# Name: do_mount
# Purpose: mounts a single file system
# Arguments:
#   $1 index into the mount_* arrays
# Global variables:
#   Read:
#       mount_fs_file[]
#       mount_fs_spec[]
#       mount_fs_spec_conf[]
#       mount_hotplug_flag[]
#       mount_idx
#       mount_fsck[]
#       mount_o_option[]
#       mount_snapshot_idx[]
#       org_name
# Return code: always 0; does not return on error
#--------------------------
function do_mount {
    fct "${FUNCNAME[0]}" 'started'
    local already_mounted_flag buf dev effective_max_mount_count \
        filesystem_state fs_spec fs_max_mount_count i j last_checked \
        last_checked_secs lv_path mount_count mount_out mounted_flag \
        mountpoint msg_class msg_part now out_fn rc rc_fn regex \
        return_on_error_flag snapshot_flag tune2fs_out whole_dev
    local fsck_flag=$false
    local -r fsckable_fstype_regex='^(JFS)|(ext)' 

    # TODO: make these configurable
    local -r my_max_secs_since_last_fsck=$((30*24*60*60))
    local -r my_max_mount_count=30

    # Parse argument
    # ~~~~~~~~~~~~~~
    i=$1

    # Set convenience variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    fs_spec=${mount_fs_spec[i]}
    fs_file=${mount_fs_file[i]}

    # Is fs_spec already mounted?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    already_mounted_flag=$false
    mounted_flag=$false
    [[ ${mount_ignore_already_mounted[i]} ]] && msg_class=I || msg_class=W 
    is_fs_mounted "$fs_spec"
    if [[ ${is_fs_mounted_out:-} != '' ]]; then
        mounted_flag=$true
        for ((j=0;j<${#is_fs_mounted_out[*]};j++))
        do
            if [[ ${is_fs_mounted_out[j]} = $fs_file ]]; then
                already_mounted_flag=$true
                msg_part=' already'
            else
                msg_part=
            fi
            msg $msg_class "$fs_spec is$msg_part mounted on ${is_fs_mounted_out[j]}"
        done
    fi

    # Are there any files under fs_file?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # This is not crucial so is not error trapped
    if [[ ! ${mount_ignore_files_under_fs_file[i]} ]] \
        && ! mountpoint -q "$fs_file" 2>/dev/null; then
        buf=$(find "$fs_file" -maxdepth 1 2>/dev/null | head -2 | wc -l)
        if ((buf>1)); then
           msg_part="There are files under mountpoint $fs_file:"$'\n'
           msg W "$msg_part$(ls --almost-all -l "$fs_file")"
        fi
    fi

    # Get the file system type
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    get_fs_type "$fs_spec"

    # Is the file system on an LVM snapshot?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ((${mount_snapshot_idx[i]}==-1)) && snapshot_flag=$false || snapshot_flag=$true

    # Run fsck when possible and desireable
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! $mounted_flag ]]; then
        fsck_flag=$false
        msg_part=
        case "$fs_type" in
            cifs | NFS  )
                # Network file systems so any fscking is not done on this system
                ;;
            ext* )
                tune2fs_out=$(tune2fs -l "$fs_spec")
                (($?>0)) && msg E "Can't list file system parameters: $tune2fs_out"

                buf=${tune2fs_out##*Filesystem state:*( )}
                filesystem_state=${buf%%$'\n'*}
                [[ $filesystem_state != clean ]] \
                    && msg_part+=", Filesystem state: $filesystem_state"

                buf=${tune2fs_out##*Last checked:*( )}
                last_checked=${buf%%$'\n'*}
                last_checked_secs=$(date "--date=$last_checked" +%s)
                now=$(date +%s)
                (((now-last_checked_secs)>my_max_secs_since_last_fsck)) \
                    && msg_part+=", Last checked: $last_checked"

                buf=${tune2fs_out##*Maximum mount count:*( )}
                fs_max_mount_count=${buf%%$'\n'*}
                effective_max_mount_count=$my_max_mount_count
                if ((fs_max_mount_count>0)); then
                    ((fs_max_mount_count<my_max_mount_count)) \
                        && effective_max_mount_count=$fs_max_mount_count
                fi

                buf=${tune2fs_out##*Mount count:*( )}
                mount_count=${buf%%$'\n'*}
                ((mount_count>=effective_max_mount_count)) \
                    && msg_part+=", mount count: $mount_count"

                [[ ! ${mount_fsck[i]} ]] && msg_part=    # Sub_keyword no_fsck
                [[ $snapshot_flag ]] && msg_part=', always run on snapshot'

                if [[ $msg_part != '' ]]; then

                    # fsck
                    # ~~~~
                    fsck_flag=$true
                    buf=$(tune2fs -c 1 -C 2 "$fs_spec" 2>&1)    # Ensure fsck does act
                    (($?>0)) && msg W "Could not set $fs_spec maximum mount count and mount count: $buf"
                    msg I "running fsck on $fs_spec (${msg_part:2})"
                    # fsck option -p is OK for fsck.ext[234]
                    buf=$(fsck -Tp "$fs_spec" 2>&1)
                    rc=$?
                    ((rc==0)) && msg_class=I || msg_class=W
                    if [[ $snapshot_flag ]]; then
                        # If the fsck output is routine for a snapshot, make it an information message
                        if [[ $(echo "$buf" \
                            | grep -E -v ': Clearing orphaned inode ' \
                            | grep -E -v ': [[:digit:]/]+ files \([^)]*\), [[:digit:]/]+ blocks' \
                            | grep -E -v 'has been mounted [[:digit:]]+ times without being checked' \
                            | grep -E -v ' IGNORED\.$' \
                            | grep -E -v ': recovering journal$' \
                            ) = '' ]]; then
                            msg_class=I
                            ((rc>0)) && msg I "The fsck output below is normal for a snapshot like this despite the fsck return code"
                        fi
                    fi
                    msg $msg_class "fsck return code $rc, output:"$'\n'"$buf"
                    buf=$(tune2fs -c "$fs_max_mount_count" "$fs_spec" 2>&1)    # Restore original value
                    (($?>0)) && msg W "Could not restore $fs_spec maximum mount count: $buf"
                fi
                ;;
            jfs )
                if [[ ${mount_fsck[i]} ]]; then    # No sub_keyword no_fsck
                    # Always fsck JFS -- it's quick except when the file system
                    # is damaged when it needs to be run anyway.
                    msg I "running fsck on $fs_spec (always run on JFS)"
                    # fsck option -p is OK for jfs_fsck
                    buf=$(fsck -Tp "$fs_spec" 2>&1)
                    rc=$?
                    ((rc==0)) && msg_class=I || msg_class=W
                    msg $msg_class "fsck return code $rc, output:"$'\n'"$buf"
                fi
                ;;
            vfat )
                # No method found to see if fsck needs running and it takes
                # too long to do it every time
                ;;
            * )
                msg E "$fs_spec is of unsupported type $fs_type"
        esac
    fi

    # Mount
    # ~~~~~
    if [[ ! $already_mounted_flag ]]; then
        # Set flag to retry mount if it fails and can fsck and have not
        # already done so
        [[ ! $fs_type =~ $fsckable_fstype_regex || $fsck_flag ]] \
            && return_on_error_flag=$false || return_on_error_flag=$true
        do_mount_command "${mount_o_option[i]}" "$fs_type" "$fs_spec" \
            "${mount_fs_file[i]}" "$return_on_error_flag"
        if (($?>0)); then
            msg I "Running fsck on $fs_spec"
            # fsck option -p is OK for fsck.ext[234] and fsck_jfs
            buf=$(fsck -Tp "$fs_spec" 2>&1)
            rc=$?
            ((rc>0)) && msg E "Giving up.  fsck return code $rc output: $buf"
            msg I "Re-trying mount"
            return_on_error_flag=$false
            do_mount_command "${mount_o_option[i]}" "$fs_type" "$fs_spec" \
                "${mount_fs_file[i]}" "$return_on_error_flag"
        fi
    fi

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function do_mount

#--------------------------
# Name: do_mounts
# Purpose: mounts file systems
# Arguments: none
# Global variables:
#   Read:
#       mount_idx
#       conf_fn
# Return code: always 0; does not return on error
#--------------------------
function do_mounts {
    fct "${FUNCNAME[0]}" 'started'
    local i

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ((mount_idx==-1)); then
        msg D "No mounts configured in $conf_fn"
        fct "${FUNCNAME[0]}" 'returning'
        return
    fi

    # For each mount
    # ~~~~~~~~~~~~~~
    for ((i=0;i<=mount_idx;i++))
    do
        do_mount $i
    done
    
    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function do_mounts

#--------------------------
# Name: do_mount_command
# Purpose: runs a mount command
# Arguments:
#   $1 -o option argument (options)
#   $2 -t option argument (file system type)
#   $3 fs_spec (a.k.a device)
#   $4 fs_file (a.k.a directory and mountpoint)
#   $5 error action control; when $true, return on error; otherwise call msg E
# Global variables:
#   Read:
#   Set:
#     mount_done_mountpoint[]
#     mount_done_mountpoint_idx
# Return code:
#   0 success
#   1 failure -- OK to try fsck
#   2 failure -- not OK to try fsck
#--------------------------
function do_mount_command {
    fct "${FUNCNAME[0]}" 'started'
    local i df_out df_out_fs_file df_out_fs_spec fs_label mount_cmd mount_out
    local mount_rc msg_class msg_part my_rc o_option part_label regex
    local subshell_pid t_option
    local -r loop_count=10
    local -r out_fn=$tmp_dir/mount.out
    local -r rc_fn=$tmp_dir/mount.rc

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local o_option_arg=${1:-}
    local t_option_arg=${2:-}
    [[ $t_option_arg = '' ]] && msg E "${FUNCNAME[0]}: programming error: t_option_arg empty"
    local fs_spec=${3:-}
    local fs_file=${4:-}
    local return_on_error_flag=${5:-}
  
    # Build the mount command
    # ~~~~~~~~~~~~~~~~~~~~~~~
    mount_cmd=(mount)
    if [[ $o_option_arg != '' ]]; then
        mount_cmd+=(-o $o_option_arg)
    fi
    mount_cmd+=(-t $t_option_arg "$fs_spec" "$fs_file")

    # Run the mount command
    # ~~~~~~~~~~~~~~~~~~~~~
    # This can hang so run as a background job and monitor
    echo -n > "$out_fn"    # Empty the file in case being re-used
    echo -n > "$rc_fn"
    msg I "Mounting by: ${mount_cmd[*]}"
    (
        "${mount_cmd[@]}" > "$out_fn" 2>&1 
        echo $? > "$rc_fn"
    ) & 
    subshell_pid=$!

    # Wait a while for it to finish
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # TODO: make the number of seconds configurable?
    for ((i=0;i<loop_count;i++))
    do  
        sleep 1
        jobs | grep --quiet ' Done '
        (($?==0)) && break
    done
    sleep 1    # Allow time to write $? to $rc_fn
    kill "$subshell_pid" 2>/dev/null
    mount_out=$(cat "$out_fn")
    mount_rc=$(cat "$rc_fn" 2>/dev/null)
    if ((i>=loop_count)); then
        if [[ $mount_out != '' ]]; then
            msg_part="Output: $mount_out"
            [[ $mount_rc != '' ]] && msg_part+=".  Return code: $mount_rc"
        else
            msg_part='There was no output (probably hung)'
        fi
        kill $subshell_pid 2>/dev/null
        msg E "Timed out waiting for the mount command to finish.  $msg_part"
    fi

    # Recording and logging
    # ~~~~~~~~~~~~~~~~~~~~~
    my_rc=0
    # Use string, not arithmetic, test for $mount_rc in case it is an empty string
    if [[ $mount_rc = 0 && $mount_out = '' ]]; then
        # Was the mount really successful?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # Sometimes $mount_rc and $mount_out look OK but the mount has failed.
        # Use df's -hT options in case the output is displayed in a message.
        df_out=$(df -hT "$fs_file" | grep -v '^Filesystem' )
        df_out_fs_spec=${df_out%%[[:space:]]*}
        df_out_fs_file=${df_out##*[[:space:]]}
        if [[ $df_out_fs_spec = $fs_spec && $df_out_fs_file = $fs_file ]]; then
            mount_done_mountpoint[++mount_done_mountpoint_idx]=$fs_file
            msg_part="Mounted $fs_spec on $fs_file:"
            part_label=$(lsblk --noheadings --output PARTLABEL "$fs_spec")
            [[ $part_label != '' ]] && msg_part+=$msg_lf"Partition label: $part_label"
            fs_label=$(lsblk --noheadings --output LABEL "$fs_spec")
            [[ $fs_label != '' ]] && msg_part+=$msg_lf"File system label: $fs_label"
            # The sed command ensures same indentation as $msg_lf
            msg I "$msg_part"$'\n'"$(echo "$df_out" | sed "s/^/${msg_lf#$'\n'}/")"
        else
            msg E "Failed to mount $fs_spec on $fs_file.  df -hT "$fs_file" output:$msg_lf$df_out"
        fi
    else
        regex='is already mounted on'
        if [[ $mount_out =~ $regex ]]; then
           read -r buf < <(echo "$mount_out" | grep '^mount: according to mtab, .* is already mounted on')
           actual_mountpoint=${buf##* }
           msg D "${FUNCNAME[0]}: already mounted at $actual_mountpoint"
           if [[ $actual_mountpoint = $fs_file ]]; then
               msg W "$fs_spec already mounted on $fs_file"
           else
               msg E "Programming/design error: ${FUNCNAME[0]}: this message should never appear!"          
           fi
        else
            [[ $return_on_error_flag ]] && msg_class=W || msg_class=E
            msg $msg_class "Mount failed. rc: $mount_rc, output: $mount_out"
            my_rc=1
        fi
    fi

    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function do_mount_command

source "$BUNG_LIB_DIR/is_fs_mounted.fun" || exit 1
# vim: filetype=bash:
