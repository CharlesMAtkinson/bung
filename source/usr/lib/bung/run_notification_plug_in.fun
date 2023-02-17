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
# Name: run_notification_plug_in
# Purpose: runs a notification plug-in
# Syntax
#   run_notification_plug_in -c <conf_fn> -b <body> -e <executable> [-l <log_fn>] -s <subject> -u <user>
#   or
#   run_notification_plug_in -c <conf_fn> -C -e <executable> -u <user>
#   Where
#       <conf_fn> is the plug-in's configuration file
#       <body> is a text string to be used as the body of the notification
#       <executable> is the plug-in execuitable
#       <log_fn> is the path of the log file to append to the body of the notification
#       <subject> is the notification subject
#       <user> is the user to run the plug-in as
# Arguments: none
# Global variable usage:
#   Read
#     signal_num_received: if not empty, action the traps
#   Write
#     emsg: appended with any conf errors (-C option only)
#     notification_sent_flag: set $true when notification sent
#     signal_num_received: set empty
# Return code: always 0; does not return on error
#--------------------------
function run_notification_plug_in {
    fct "${FUNCNAME[0]}" "started with arguments $*"
    local OPTIND    # Required when getopts is called in a function
    local args opt opt_b_flag opt_c_flag opt_C_flag opt_e_flag opt_l_flag opt_s_flag opt_u_flag
    local buf cmd command msg_class rc
    local body body_fn conf_fn executable subject user
    local i_msgs e_msgs w_msgs my_emsg unexpected_out
    local already_percent_q_flag

    # Parse options
    # ~~~~~~~~~~~~~
    args=("$@")
    my_emsg=
    opt_b_flag=$false
    opt_c_flag=$false
    opt_C_flag=$false
    opt_e_flag=$false
    opt_l_flag=$false
    opt_s_flag=$false
    opt_u_flag=$false
    while getopts :b:c:Ce:l:s:u: opt "$@"
    do
        case $opt in
            b )
                opt_b_flag=$true
                body=$OPTARG
                ;;
            c )
                opt_c_flag=$true
                conf_fn=$OPTARG
                ;;
            C )
                opt_C_flag=$true
                ;;
            e )
                opt_e_flag=$true
                executable=$OPTARG
                ;;
            l )
                opt_l_flag=$true
                body_fn=$OPTARG
                ;;
            s )
                opt_s_flag=$true
                subject=$OPTARG
                ;;
            u )
                opt_u_flag=$true
                user=$OPTARG
                ;;
            : )
                my_emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                my_emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done
    shift $(($OPTIND-1))

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_C_flag ]]; then
        [[ $opt_b_flag ]] && my_emsg+=$msg_lf"Option -b cannot be used with option -C"
        [[ $opt_l_flag ]] && my_emsg+=$msg_lf"Option -l cannot be used with option -C"
        [[ $opt_s_flag ]] && my_emsg+=$msg_lf"Option -s cannot be used with option -C"
    fi

    # Test for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_c_flag ]] && my_emsg+=$msg_lf'-c option is required'
    [[ ! $opt_u_flag ]] && my_emsg+=$msg_lf'-u option is required'
    if [[ ! $opt_C_flag ]]; then
        [[ ! $opt_b_flag ]] && my_emsg+=$msg_lf'-b option is required when option -C is not used'
        [[ ! $opt_e_flag ]] && my_emsg+=$msg_lf'-e option is required when option -C is not used'
        [[ ! $opt_s_flag ]] && my_emsg+=$msg_lf'-s option is required when option -C is not used'
    fi

    # Test remaining arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    (($#>0)) && my_emsg+=$msg_lf"Invalid non-option arguments: $*"

    # Validate option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_l_flag ]];  then
        buf=$(ck_file "$log_fn" f:r 2>&1)
        [[ $buf != '' ]] && my_emsg+=$msg_lf"$buf"
    fi

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $my_emsg != '' ]]; then
        # These are programming error(s) so use error, not warning
        msg E "Programming error. ${FUNCNAME[0]} called with ${args[*]}$my_emsg"
    fi

    # Build the command to run the notification plug-in
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $user_name = root ]]; then
        if [[ $opt_C_flag ]]; then    # Error trap the conffile
            cmd=(su "$user"
                --shell /bin/bash
                --command "$(printf '%q' "$executable") -c $(printf '%q' "$conf_fn") -C"
            )
        else
            command="$(printf '%q' "$executable") -b $(printf '%q' "$body") -c $(printf '%q' "$conf_fn")"
            if [[ $opt_l_flag ]];  then
                command+=" -l $(printf '%q' "$log_fn")"
            fi
            command+=" -s $(printf '%q' "$subject")"
            cmd=(su "$user"
                --shell /bin/bash
                --command "$command"
            )
        fi
        already_percent_q_flag=$true
    else
        if [[ $opt_C_flag ]]; then    # Error trap the conffile
            cmd=("$executable" -c "$conf_fn" -C)
        else
            cmd=("$executable" -b "$body" -c "$conf_fn" -s "$subject")
            if [[ $opt_l_flag ]];  then
                cmd+=(-l "$log_fn")
            fi
        fi
        already_percent_q_flag=$false
    fi

    # Prevent trappable signals calling finalise
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg D 'Preventing trappable signals calling finalise'
    signal_num_received=
    set_traps signal_num_received

    # Run the notification plug-in
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $already_percent_q_flag ]]; then
        msg I "Running notification plug-in by command:$msg_lf${cmd[*]}"
    else
        msg I "Running notification plug-in by command:$msg_lf$(printf '%q ' "${cmd[@]}")"
    fi
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    i_msgs=$(echo "$buf" | grep '^For bung I ' | sed 's/^For bung I //')
    w_msgs=$(echo "$buf" | grep '^For bung W ' | sed 's/^For bung W //')
    e_msgs=$(echo "$buf" | grep '^For bung E ' | sed 's/^For bung E //')
    unexpected_out=$(echo "$buf" | grep -Ev '^For bung (I|W|E) ')
    [[ $unexpected_out != '' ]] && msg W "Unexpected output:"$'\n'"$unexpected_out"
    [[ $i_msgs != '' ]] && msg I "Information messages:"$'\n'"$i_msgs"
    if [[ $opt_C_flag ]]; then    # Error trapping the conffile
        [[ $e_msgs != '' ]] && emsg+=$'\n'$e_msgs
    else
        ((rc==0)) && notification_sent_flag=$true
        [[ $w_msgs != '' ]] && msg W "Warning messages:"$'\n'"$w_msgs"
    fi
    ((rc==0)) && msg_class=I || msg_class=W
    msg $msg_class "Notification plug-in return code $rc"

    # Effect any signal received while running the notification plug-in
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg D 'Effecting any signal received while running notification plug-in'
    if [[ $signal_num_received != '' ]]; then
        msg I "Effecting signal $signal_num_received received while running the notification plug-in"
        finalise $((128+signal_num_received))
    fi

    # Revert trappable signals to call finalise
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg D 'Reverting trappable signals to call finalise'
    set_traps finalise
    trap > "$tmp_dir/trap_out"

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function run_notification_plug_in
# vim: filetype=bash:
