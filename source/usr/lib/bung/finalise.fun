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
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#    $1  exit code
# Exit code: 
#   When not terminated by a signal, the sum of zero plus
#      1 when any warnings
#      2 when any errors
#      4 when called by hotplug_bu or super_bu and a subsidiary script was
#        terminated by a signal
#   When terminated by a trapped signal, the sum of 128 plus the signal number
#--------------------------
function finalise {
    fct "${FUNCNAME[0]}" "started with args $*"
    [[ ${BUNG_COMPGEN_DIR:-} != '' ]] && compgen -v >> $BUNG_COMPGEN_DIR/final.vars
    local address at_least_one_lvremove_failed_flag body buf hdun_body hdun_subject i j
    local logger_msg lsof_out lvremove_failed_flag lvremove_rc mountpoint
    local msg msg_class msg_level my_exit_code my_snapshot_mapper my_snapshot_vol subject
    local tmp_dir_regex umounted_flag
    local -r shutdown_cmd='shutdown -h +5'
    local -r subject_postfix=' (bung)'
    local -r usage_percent_regex='^[[:digit:]]+%$'

    finalising_flag=$true
    
    # Interrupted?
    # ~~~~~~~~~~~~
    my_exit_code=0
    if ck_uint "${1:-}"; then
        if (($1>128)); then    # Trapped interrupt
            interrupt_flag=$true
            i=$((128+${#sig_names[*]}))    # Max valid interrupt code
            if (($1<i)); then
                my_exit_code=$1
                sig_name=${sig_names[$1-128]}
                msg I "Finalising on $sig_name"
                [[ ${summary_fn:-} != '' ]] \
                    && echo "Finalising on $sig_name" >> "$summary_fn" 
            else
               msg="${FUNCNAME[0]} called with invalid exit value '${1:-}'" 
               msg+=" (> max valid interrupt code $i)" 
               msg E "$msg"    # Returns because finalising_flag is set
            fi
        fi
    fi

    # Run any post-hook commands
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! $interrupt_flag ]] && ((post_hook_idx>-1)); then
        for ((i=0;i<=post_hook_idx;i++))
        do
            if [[ ${post_hook_run[i]} = always ]] \
                || [[ ${post_hook_run[i]} = normal && ! $error_flag ]]; then
                msg I "Running post-hook command: ${post_hook_cmd[i]}"

                # Run the command
                # ~~~~~~~~~~~~~~~
                cmd=(${post_hook_cmd[i]})
                run_cmd_with_timeout -o '<3' -e '>=3' -t "$post_hook_timeout" \
                    -T "$post_hook_timeout_msgclass" -v
                rc=$?
                out=$(<"$out_fn")
                case $rc in
                    0|1)    # Did not time out
                        # Log output from the post-hook
                        rc=$(<"$rc_fn")
                        msg='Output from post-hook command:'
                        msg+=$'\n==== start of output from post-hook command ==='
                        msg+=$'\n'"$out"
                        msg+=$'\n==== end of output from post-hook command ==='
                        case $rc in
                            $hook_rc_ic | $hook_rc_if) 
                                msg_class=I
                                ;;
                            $hook_rc_wc | $hook_rc_wf) 
                                msg_class=W
                                ;;
                            $hook_rc_e) 
                                msg_class=E
                                ;;
                            *) 
                                msg="Unsupported return code $rc from post-hook command"
                                msg_class=E
                        esac
                        msg $msg_class "$msg"
                        ;;
                    2)
                        msg $post_hook_timeout_msgclass 'post-hook command timed out'
                esac
            fi
         done
     fi

    # Unmount any file systems mounted earlier
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    do_umounts

    # Hotplug device final notification
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ${hotplug_dev_idx:-} != '' ]]; then
        notify_finally
    fi

    # Drop snapshots
    # ~~~~~~~~~~~~~~
    at_least_one_lvremove_failed_flag=$false
    for ((i=0;i<=snapshot_idx;i++))
    do 
        if [[ ${snapshot_created_flag[i]:-$false} ]]; then
            lvremove_failed_flag=$false
            my_snapshot_vol=${snapshot_vol[i]}          # /dev/<VG name>/snap-<LV name>
            my_snapshot_mapper=${snapshot_mapper[i]}    # /dev/mapper/<VG name>-snap--<LV name>

            # Programming note
            # ~~~~~~~~~~~~~~~~
            # A technique of removing the -cow and -real before running
            # lvremove was tried but was not effective because they could
            # not be removed, despite running in a 100-repeat loop and trying
            # a sync and a sleep 5 before the attempt.
            # Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=674682

            # Workaround udev/lvremove interaction
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            # Ref: https://bugzilla.redhat.com/show_bug.cgi?id=753105 
            for ((j=0;j<lvremove_count_max;j++))
            do
                # LVM_SUPPRESS_FD_WARNINGS suppresses messages from lvremove matching
                #     ^File descriptor .* leaked on lvremove invocation\. .*$
                buf=$(LVM_SUPPRESS_FD_WARNINGS= lvremove --force $my_snapshot_vol 2>&1)
                lvremove_rc=$?
                ((lvremove_rc==0)) && break
            done
            ((lvremove_rc!=0)) && lvremove_failed_flag=$true

            # Workaround partial snapshot removal
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            # This attempts to clean up after the snapshot has been removed
            # but its -cow and/or -real components remain.
            # One of the cow's paths is /dev/<VG name>/snap-<LV name>-cow
            # One of the real's paths is /dev/<VG name>/snap-<LV name>-real
            if [[
                $lvremove_failed_flag \
                && ! -e $my_snapshot_vol && ! -e $my_snapshot_mapper
            ]]; then
                msg D "Trying to workaround partial snapshot removal"
                cow=$my_snapshot_vol-cow
                for ((j=0;j<lvremove_count_max;j++))
                do
                    [[ ! -e $cow ]] && break
                    dmsetup remove "$cow" >/dev/null 2>&1
                done
                real=$my_snapshot_vol-real
                for ((j=0;j<lvremove_count_max;j++))
                do
                    [[ ! -e $real ]] && break
                    dmsetup remove "$real" >/dev/null 2>&1
                done
                [[ ! -e $cow && ! -e $real ]] && lvremove_failed_flag=$false
            fi
                
            # Report lvremove status
            # ~~~~~~~~~~~~~~~~~~~~~~
            if [[ ! $lvremove_failed_flag ]]; then
                msg I "Removed snapshot volume $my_snapshot_vol"
            else
                at_least_one_lvremove_failed_flag=$true
                msg W "Unable to remove snapshot volume $my_snapshot_vol"
                buf=Diagnostics:
                buf+=$msg_lf$msg_lf
                buf+=$'lsblk -fs output:\n'$(lsblk --fs 2>&1)
                buf+=$msg_lf$msg_lf
                buf+=$'dmsetup info -c output:\n'$(dmsetup info -c $my_snapshot_vol 2>&1)
                buf+=$msg_lf$msg_lf
                buf+=$'dmsetup ls --tree output:\n'$(dmsetup ls --tree 2>&1)
                msg I "$buf"
            fi
        fi
    done
    [[ $at_least_one_lvremove_failed_flag ]] \
        && msg E "One or more LVM snapshots could not be removed; manual intervention required; possibly a reboot"

    # Old log removal
    # ~~~~~~~~~~~~~~~
    # This is not made dependent on $logging_flag or $subsidiary_mode in case
    # old logs exist for this script and configuration file combination 
    if [[ $conf_name != '(unknown config)' ]]; then
        buf=$(find "$log_dir" -name "$script_name+$conf_name.*.log" -mtime +$log_retention -execdir rm {} \; 2>&1)
        [[ $buf != '' ]] && msg W "Problem removing old logs: $buf"
    fi

    # Shutdown
    # ~~~~~~~~
    # The shutdown command with a future time does not return so it must be
    # backgrounded for this script to continue.
    # This script exits before shutdown; that would normally result in the
    # backgrounded shutdown command being terminated so it must be protected
    # against SIGHUP.
    if [[ ${shutdown,,} = yes ]]; then
        msg I "Shutting down using command '$shutdown_cmd'"
        if [[ $tmp_dir_created_flag ]]; then
            buf=$( 
                $shutdown_cmd &>"$out_fn" &
                disown
                sleep 1
                [[ -s $out_fn ]] && cat "$out_fn"
            )
            [[ $buf != '' ]] && msg W "$shutdown_cmd: output:"$'\n'"$buf"
        else
            $shutdown_cmd &>/dev/null &
        fi
    fi

    # Exit code value adjustment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! $interrupt_flag ]]; then
        if [[ $warning_flag ]]; then
            msg I "There was at least one WARNING" 
            ((my_exit_code+=1))
        fi
        if [[ $error_flag ]]; then
            msg I "There was at least one ERROR" 
            ((my_exit_code+=2))
        fi
        if ((my_exit_code==0)) && ((${1:-0}!=0)); then
            msg='There was an error not reported in detail'
            msg+=' (probably by ... || finalise 1)'
            msg E "$msg" 
            my_exit_code=2
        fi
    else
        msg I "There was a $sig_name interrupt" 
    fi
    msg I "Exiting with return value $my_exit_code"

    # Final messages (logger and email)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! $subsidiary_mode_flag ]]; then

        # Non-subsidiary mode: syslog and report mail
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $logging_flag ]]; then
            # If we are finalising because of an error parsing the config file
            # email_for_report may not have been set in which case set sane
            # defaults
            if ((email_for_report_idx==-1)); then
                email_for_report_idx=0
                email_for_report[0]=root
                email_for_report_msg_level[0]=I
                email_for_report_nolog_flag[0]=$false
            fi

            # The email subject, ending with SUCCESS, WARN or ERROR followed by
            # (bung), is typically used for email filtering so changing that
            # format could require updating mail filters.
            subject="$org_name $conf_name $(date --iso)" 
            if [[ ! $warning_flag \
                && ! $error_flag \
                && ! $interrupt_flag \
            ]]; then
                if [[ $script_name != hotplug_bu_launcher ]]; then
                    subject="$subject SUCCESS$subject_postfix"
                    for ((i=0;i<=email_for_report_idx;i++))
                    do
                        msg_level=${email_for_report_msg_level[i]}
                        [[ $msg_level != I ]] && continue
                        address=${email_for_report[i]}
                        msg I "Sending report mail to $address"
                        buf=$(echo "No problems detected.  Log file: $log_fn" \
                            | mailx -s "$subject" "$address")
                        [[ $buf != '' ]] && msg W "sending mail: $buf"
                    done
                    logger_msg='no problems detected, success report'
                    logger_msg+=" mailed to ${email_for_report[*]}"
                else
                    logger_msg='no problems detected'
                fi
            else
                if [[ $error_flag || $interrupt_flag ]]; then
                    subject="$subject ERROR$subject_postfix"
                    logger_msg="ERROR detected, log mailed to ${email_for_report[*]}"
                else
                    subject="$subject WARN$subject_postfix"
                    logger_msg="WARNING issued, log mailed to ${email_for_report[*]}"
                fi
                body=$(
                    if [[ ${summary_fn:-} != '' && -s $summary_fn ]]; then
                        echo '== Warning and error summary'
                        cat "$summary_fn"
                        echo $'== End of warning and error summary\n'
                    fi
                )
                for ((i=0;i<=email_for_report_idx;i++))
                do
                    msg_level=${email_for_report_msg_level[i]}
                    [[ $msg_level = E && ! $error_flag && ! $interrupt_flag ]] \
                        && continue
                    [[ ! ${email_for_report_nolog_flag[i]} && -f "$log_fn" ]] \
                        && body+=$'\n\n'$(my_cat "$log_fn")
                    address=${email_for_report[i]}
                    msg I "Sending report mail to $address"
                    buf=$(echo "$body" \
                        | iconv --from-code utf-8 --to-code ascii//translit \
                        | tr --delete '' \
                        | fold -w 999 \
                        | mailx -n -s "$subject" "$address")
                    [[ $buf != '' ]] && msg W "sending mail: $buf"
                done
            fi
            buf=$(logger -i -t "$script_name+$conf_name" "$logger_msg" 2>&1)
            [[ $buf != '' ]] && msg W "logger command problem: $buf"
        fi
    else
        # Subsidiary mode: syslog only
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $logging_flag ]]; then
            subject="$org_name $conf_name $(date --iso)" 
            if [[ ! $warning_flag \
                && ! $error_flag \
                && ! $interrupt_flag \
            ]]; then
                logger_msg='no problems detected'
            elif [[ $error_flag || $interrupt_flag ]]; then
                logger_msg='ERROR detected'
            else
                logger_msg='WARNING issued'
            fi
            buf=$(logger -i -t "$script_name+$conf_name" "$logger_msg" 2>&1)
            [[ $buf != '' ]] && msg W "logger command problem: $buf"
        fi
    fi

    # Remove temporary directory/ies
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    tmp_dir_regex="^$tmp_dir_root/$script_name\+$conf_name\..{6}$"
    [[ $tmp_dir_created_flag \
        && ${tmp_dir:-} =~ $tmp_dir_regex \
    ]] && rm -fr "$tmp_dir"

    tmp_dir_pg_regex="^$tmp_dir_root/$script_name\+$conf_name\.pg\..{6}$"
    [[ ${tmp_dir_pg_created_flag:-$false} \
        && ${tmp_dir_pg:-} =~ $tmp_dir_pg_regex \
    ]] && rm -fr "$tmp_dir_pg"

    # Remove PID file
    # ~~~~~~~~~~~~~~~
    [[ $pid_file_locked_flag ]] && rm "$pid_fn"

    # Exit
    # ~~~~
    fct "${FUNCNAME[0]}" 'exiting'
    exit $my_exit_code
}  # end of function finalise

#--------------------------
# Name: notify_finally
# Purpose: notifies finally -- OK to unplug hotplug device or not
# Arguments: none
# Global variables:
#   Read:
#       hotplug_dev[]
#       hotplug_dev_idx
#       hotplug_dev_email[]
#       hotplug_whole_dev[]
#   Set: 
# Return code: always 0
#--------------------------
function notify_finally {
    fct "${FUNCNAME[0]}" 'started'
    local buf body cmd dialog_type i path pid pids regex subject whole_disk_dev

    # Ensure the initial notification is not displayed
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ${x_msg_pid:-} != '' ]]; then
        regex='^(su --command )?(yad|zenity) '

        # Kill any child processes of the backgrounded job
        buf=$(ps --format args,pid --no-headers --ppid=$x_msg_pid 2>&1)
        # TODO: process each line of $buf separately
        if [[ $buf =~ $regex ]]; then
           pids=$(echo "$buf"|sed 's/.* //')
           kill $pids
        else
           msg D "regex $regex not matched for the backgrounded job"
        fi

        # Kill the backgrounded job itself
        buf=$(ps --format args --no-headers --pid=$x_msg_pid 2>&1)
        if [[ $buf =~ $regex ]]; then
           kill $x_msg_pid
        else
           msg D "regex $regex not matched for the backgrounded job"
        fi
    fi

    # For each hotplug device
    # ~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=hotplug_dev_idx;i++))
    do  
        # Nothing to do?
        # ~~~~~~~~~~~~~~
        # When finalising because of early errors
        [[ ${hotplug_whole_dev[i]:-} = '' ]] && continue
        [[ ${out_fn:-} = '' || ! -e "$out_fn" ]] && continue
        [[ ${rc_fn:-} = '' || ! -e "$rc_fn" ]] && continue

        # Any file systems on it still mounted?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        whole_disk_dev=${hotplug_whole_dev[i]}
        buf=$(mount 2>&1 | grep "^$whole_disk_dev" 2>&1)
        if [[ $buf = '' ]]; then

            # Get the file system usage
            # ~~~~~~~~~~~~~~~~~~~~~~~~~
            mount_fs_file[0]=$tmp_dir/mnt
            mount_idx=0
            mount_ignore_already_mounted[0]=$false
            mount_ignore_files_under_fs_file[0]=$false
            mount_o_option[0]=
            mount_snapshot_idx=-1
            cmd=(readlink --canonicalize-existing -- "${hotplug_dev_path[i]}")
            mount_fs_spec[0]=$("${cmd[@]}" 2>&1)
            if (($?>0)); then
                msg E "Problems running ${cmd[*]}: ${mount_fs_spec[0]}"
            fi
            mount_fsck[0]=$false
            do_mounts
            cmd=(df --output=pcent "${hotplug_dev_path[i]}")
            run_cmd_with_timeout -w '!=0'
            if (($?==0)); then
                pcent=$(tail -1 "$out_fn")
                pcent=${pcent##* }
            else
                pcent=unknown
            fi
            do_umounts
            body="Final file system usage is $pcent"

            spin_down_device "$whole_disk_dev"
            subject="OK to unplug $org_name hotplug storage"
            dialog_type=info
        else
            subject="Not safe to unplug $org_name hotplug storage; file system(s) mounted"
            body+=$'\n'"File systems mounted:"$'\n'"$buf"
            dialog_type=error
        fi  

        # On-screen notification
        # ~~~~~~~~~~~~~~~~~~~~~~
        [[ ${hotplug_dev_note_screen_flag[i]} ]] \
            && msg_on_screen "$dialog_type" "$subject" "$body"

        # E-mail notification
        # ~~~~~~~~~~~~~~~~~~~
        [[ ${hotplug_dev_note_email[i]} = '' ]] && continue
        path=${hotplug_dev_path[i]}
        body+=$'\n\nDevice:\n'"$path, also referenced as"$'\n'
        body+=$(find -L /dev/disk/by-path /dev/disk/by-id -samefile "$path")
        body+=$'\n\n'"There may be more information in log file $log_fn"
        msg I "Notifying ${hotplug_dev_note_email[i]}: $subject"
        echo "$body" | mailx -s "$subject" ${hotplug_dev_note_email[i]}
    done

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function notify_finally

#--------------------------
# Name: spin_down_device
# Purpose: spins down a hotplug device
# Arguments:
#   $1 - whole disk device file, example /dev/sdg 
# Global variables:
#   Read: none
#   Set: none
# Return code: 1 on error, otherwise 0 
#--------------------------
function spin_down_device {
    fct "${FUNCNAME[0]}" started
    local buf cmd dev_bsg_X msg msgclass rc

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r whole_disk_dev=${1:-}

    # Get the /dev/bsg/* file name from the /dev/sd* file name
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # /dev/bsg/* is the "pass-through" interface to the SCSI driver.  It must
    # be used as the DEVICE argument when sdparm is used to send commands to
    # the device.
    cmd='lsscsi --generic'
    buf=$($cmd 2>&1)
    rc=$?
    if ((rc==0)); then
        dev_bsg_X=/dev/bsg/$(echo "$buf" | grep $whole_disk_dev | sed -e 's/\[//' -e 's/].*$//')
        if [[ ! -e $dev_bsg_X ]]; then
            msg W "SCSI driver pass-through device file '$dev_bsg_X' does not exist"
            fct "${FUNCNAME[0]}" 'returning 1'
            return 1
        fi  
        msg D "SCSI generic device is $dev_bsg_X"
    else
        msg="Unexpected output from $cmd"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg W "$msg"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi

    # Spin down
    # ~~~~~~~~~
    cmd="sdparm --command=stop --quiet --verbose $dev_bsg_X"
    msg I "Spinning down $whole_disk_dev using command $cmd"
    buf=$(sdparm --command=stop --quiet --verbose $dev_bsg_X 2>&1)
    rc=$?
    ((rc==0)) && msgclass=D || msgclass=W
    msg $msgclass "sdparm return code: $rc, output: "$'\n'"$buf"

    fct "${FUNCNAME[0]}" "returning $rc"
    return $rc
}  # end of function spin_down_device

# vim: filetype=bash:
