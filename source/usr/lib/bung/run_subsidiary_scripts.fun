# Copyright (C) 2022 Charles Atkinson
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
# Name: run_subsidiary_scripts
# Purpose: runs the configured subsidiary scripts
# Arguments: none
# Global variable usage:
#   Read:
#       * org_name
#       * subsidiaryscript_conf[[]
#       * subsidiaryscript_debug[]
#       * subsidiaryscript_idx
#       * subsidiaryscript_ionice[]
#       * subsidiaryscript_name[]
#       * subsidiaryscript_nice[]
#       * subsidiaryscript_schedule[]
#       * tmp_dir
#       * tmp_dir_root
# Output
#    * The usual logging
#    * Log summary appended to $tmp_dir/summary 
# Return code: always 0; does not return on error
#--------------------------
function run_subsidiary_scripts {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd i log_line job_name msg_class msg_part exit_code exit_code_bitfield
    local time_now time_regex

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ((subsidiaryscript_idx==-1)); then
        msg I "No subsidiary scripts configured in $conf_fn"
        return
    fi

    # For each subsidiary script
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    summary_fn=$tmp_dir/summary
    for ((i=0;i<=subsidiaryscript_idx;i++))
    do
        # Build the command to run the subsidiary script
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        unset cmd
        [[ ${subsidiaryscript_nice[i]} != '' ]] \
            && cmd+=(nice -n ${subsidiaryscript_nice[i]})
        [[ ${subsidiaryscript_ionice[i]} != '' ]] \
            && cmd+=(ionice ${subsidiaryscript_ionice[i]})
        cmd+=("$BUNG_BIN_DIR/${subsidiaryscript_name[i]}")
        cmd+=(-c "${subsidiaryscript_conf[i]}")
        [[ ${subsidiaryscript_debug[i]} ]] && cmd+=(-d)
        cmd+=(-l "$log_fn" -o "$org_name" -s)

        # Does now match any scheduled time?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ ${subsidiaryscript_schedule[i]} != '' ]]; then
            time_regex=${subsidiaryscript_schedule[i]}
            time_now=$(date +%Y/%m/%d/%u/%H/%M/%S)
            if [[ $time_now =~ $time_regex ]]; then
                msg I "Time now $time_now matched schedule regex $time_regex"
            else
                msg I "Time now $time_now did not match schedule regex $time_regex so not running subsidiary script by command:$msg_lf$(printf '%q ' "${cmd[@]}")"
                continue
            fi 
        fi

        # Note current log line
        # ~~~~~~~~~~~~~~~~~~~~~
        # Required when summarising below
        if [[ -f "$log_fn" ]]; then
            buf=$(wc -l "$log_fn")
            log_line=${buf%% *}
        fi

        # Prevent trappable signals calling finalise
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        msg I 'Changing signal traps from calling finalise to setting signal_num_received'
        signal_num_received=
        set_traps signal_num_received

        # Run the subsidiary script
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        msg I "Running subsidiary script by command:$msg_lf$(printf '%q ' "${cmd[@]}")"
        buf=$("${cmd[@]}" 2>&1)
        exit_code=$?
        msg I "Exit code $exit_code from subsidiary script"
        if [[ $buf != '' ]]; then
            # There should be no stdout or stderr from the scripts.
            # Exit code 126 means the script was not executable.
            # Exit code 127 means the script was not found.
            msg_class=W
            ((exit_code==126)) || ((exit_code==127)) && msg_class=E
            msg $msg_class "stdout and stderr from script: $buf"
        fi

        # Decode the subsidiary script's exit code
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # The exit code, as set by the subsidiary script's finalise function is
        #   When not terminated by a signal, the sum of zero plus
        #      1 when any warnings
        #      2 when any errors
        #      4 when called by hotplug_bu or super_bu and a subsidiary script
        #        was terminated by a signal
        #   When terminated by a trapped signal, the sum of 128 plus the signal
        #   number
        # The subsidary script should have logged any interrupt except the 
        # untrappable 9/SIGKILL
        if [[ ${subsidiaryscript_name[i]} = hotplug_bu \
            || ${subsidiaryscript_name[i]} = super_bu \
        ]]; then
            max_normal_exit_code=7
        else
            max_normal_exit_code=3
        fi
        if ((exit_code<=max_normal_exit_code)); then
            msg I "Exit code $exit_code from subsidiary script"
            buf=$exit_code
            (((buf%2)==1)) && warning_flag=$true
            buf=$((buf/2))
            (((buf%2)==1)) && error_flag=$true
            buf=$((buf/4))
            (((buf%4)==1)) && interrupt_flag=$true
        elif ((exit_code>max_normal_exit_code)) && ((exit_code<126)); then
            msg="Invalid subsidiary script exit code $exit_code" 
            msg+=" (> $max_normal_exit_code and < 126)" 
            msg E "$msg" 
        else    # Interrupted
            # Sleep to allow the subsidiary script's messages to be written to
            # the log before writing any of our own
            sleep 1
            if ((exit_code==(128+9))); then    # SIGKILL
                msg W "The subsidiary script was killed by unmaskable interrupt SIGKILL" 
            fi
        fi

        # Summarise the subsidiary script's warnings and errors
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ -f "$log_fn" ]]; then
            job_name=${subsidiaryscript_name[i]}+${subsidiaryscript_conf[i]}
            echo -n "=== $job_name:" >> "$summary_fn"
            if ((exit_code==0)); then
                echo ' clean' >> "$summary_fn"
            else
                echo '' >> "$summary_fn"
                exec 11>&1; exec 12>&2    # Copy (save) fds
                exec 1>&-;  exec 2>&-     # Close (flush) fds
                exec 1>&11; exec 2>&12    # Open (restore) fds
                exec 11>&-; exec 12>&-    # Close (discard) saved fds
                # The warning and error regexes below are also used in the
                # my_cat function; any changes here should be reflected there.
                sed -n "$log_line"',${
                    /\(ERROR\|WARN\): /p
                    /^IO error encountered/p
                    /^No return code found /p
                    /^cannot delete non-empty directory:/p
                    /^rsync error:/p
                    /^rsync: /p
                    /is unreachable, does not exist or is not a directory$/p
                    /\([Ee]rror[: ]\|errcode\|access denied\)/p
                }' "$log_fn" >> "$summary_fn"
            fi
        fi

        # Effect any signal received while running subsidiary script
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $signal_num_received != '' ]]; then
            sleep 15    # For subsidiary script to complete logging
            finalise $((128+signal_num_received))
        fi

        # Make trappable signals call finalise
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        msg I 'Changing signal traps from setting signal_num_received to calling finalise'
        set_traps finalise
        trap > "$tmp_dir/trap_out"

    done

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function run_subsidiary_scripts
# vim: filetype=bash:
