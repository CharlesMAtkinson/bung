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
# Name: run_remote_agent
# Purpose:
#   Runs the bung remote agent script:
#       1. Create conf file locally
#       2. Copy conf file to remote host's user's home directory
#       3. Run remote_agent on remote host
#       4. Remove conf file from remote host
# Options:
#   Usage:
#   * Before calling this function:
#       * $out_fn and $rc_fn must contain paths of writeable files
#         Any existing content will be deleted.
#   Syntax
#       run_remote_agent -b|-D -c conf [-l dir] [-p dir] -s ssh_host [-t timeouts] [-T count]
#   Where
#       -b and -D are options for remote_agent
#       -c configuration string for remote agent
#       -l remote host log directory
#       -p remote host PID directory and temporary root_direcctory
#       -s remote ssh host name (normally in ~/.ssh/config)
#       -t <timeout>[,timeout>]
#          Duration before timing out:
#          1 The command
#          2 Any remote host connection test
#          <timeout> must be a floating point number with an optional suffix:
#          s for seconds (the default)
#          m for minutes
#          h for hours
#          d for days
#          Default 10,10
#       -T timeout retry count.  Default 0
#   After this function has run caller can:
#       * Examine its return code.
#         0 - No problem detected with the command.
#             Either:
#                 * Its return code was zero
#                 or
#                 * Its return code was non-zero or ignored and its output
#                   matched a -o option regular expression.
#         1 - The command failed.
#             Either:
#                 * Its return code was not ignored and non-zero
#                 or
#                 * Its return code was ignored and its output
#                   did not match any -o option regular expression.
#         2 - Timeout:
#                 The command timed out.
#       * In case the command did not time out:
#           * Read its return code from $rc_fn
#           * Read its combined stdout and stderr from $out_fn
#   Example:
#       run_remote_agent -D -c dir -s server.mydomain -t 60,10,10
#       rc=$?
#       case $rc in
#           0)
#               # Remote agent ran OK; examine output as required and continue
#               ;;
#           1)
#               # Remote agent was not run or was run and failed; examine output and do whatever ...
#               ;;
#           2)
#               # Timeout while copying conf file or running remote agent; retry or give up
#       esac
# Global variables read:
#   out_fn
#   rc_fn
# Global variables set:
# Output:
#   * stdout and stderr to log or screen, either directly or via msg function
#   * Command return code to $tmp_dir/rc
#   * Command output to $tmp_dir/out
# Returns: described under "Usage:" above
#--------------------------
function run_remote_agent {
    fct "${FUNCNAME[0]}" "started with arguments $*"
    local OPTIND    # Required when getopts is called in a function
    local args opt
    local opt_b_flag opt opt_c_flag opt_D_flag opt_i_flag opt_l_flag opt_p_flag opt_s_flag opt_t_flag
    local cmd_opts conf emsg ssh_host_ssh_identity_fn opt_t_arg remote_agent_args remote_agent_opt
    local ssh_host timeout_retry_count
    local buf i local_tmp_fn msg_part out remote_conf_fn saved_out
    local -r scp_out_ok_re='^Warning: Permanently added .* to the list of known hosts'
    local -r bad_configuration_option_re='Bad configuration option'

    # Parse options
    # ~~~~~~~~~~~~~
    args=("$@")
    emsg=
    opt_b_flag=$false
    opt_c_flag=$false
    opt_D_flag=$false
    opt_i_flag=$false
    opt_l_flag=$false
    opt_p_flag=$false
    opt_s_flag=$false
    opt_t_flag=$false
    opt_t_arg=10,10
    timeout_retry_count=0
    while getopts :b:c:Dl:p:s:t:T: opt "$@"
    do
        case $opt in
            b )
                opt_b_flag=$true
                remote_agent_opt="-b $OPTARG"
                ;;
            c )
                opt_c_flag=$true
                conf=$OPTARG
                ;;
            D )
                opt_D_flag=$true
                remote_agent_opt=-D
                ;;
            l )
                opt_l_flag=$true
                ssh_host_log_dir=$OPTARG
                ;;
            p )
                opt_p_flag=$true
                ssh_host_pid_dir=$OPTARG
                ;;
            s )
                opt_s_flag=$true
                ssh_host=$OPTARG
                ;;
            t )
                opt_t_flag=$true
                opt_t_arg=$OPTARG
                ;;
            T )
                timeout_retry_count=$OPTARG
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done
    shift $(($OPTIND-1))

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ $opt_b_flag && $opt_D_flag ]] \
        && emsg+=$msg_lf'-b and -D options are mutually exclusive'

    # Test for mandatory options not set
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_b_flag && ! $opt_D_flag ]] && emsg+=$msg_lf'-b or -D option is required'
    [[ ! $opt_c_flag ]] && emsg+=$msg_lf'-c option is required'
    [[ ! $opt_s_flag ]] && emsg+=$msg_lf'-s option is required'
    [[ ! $opt_t_flag ]] && emsg+=$msg_lf'-t option is required'

    # Test remaining arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    (($#>0)) && emsg+=$msg_lf"Invalid non-option arguments: $*"

    # Validate option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    # opt_t_arg not validated here; will be validated by run_cmd_with_timeout
    err_trap_uint "$timeout_retry_count" '-T option argument'

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        # These are programming error(s) so use error, not warning
        msg E "Programming error. ${FUNCNAME[0]} called with ${args[*]}$emsg"
    fi

    # Create conf file locally
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    # Random string in name to avoid collision on remote host
    buf=$(cat /dev/urandom 2>/dev/null \
        | tr -cd 'a-f0-9' 2>/dev/null \
        | head -c 8
    )
    local_tmp_fn=$tmp_dir/bung.$buf.conf
    buf=$(echo "$conf" 2>&1 > "$local_tmp_fn")
    if [[ $buf != '' ]]; then
        msg W "Creating $local_tmp_fn:$lf$buf"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    chmod 700 "$local_tmp_fn" || finalise 1

    # Copy conf file to remote host
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Temporary file location is remote user's home directory as best practicable choice
    msg D $'Copying conf file to remote host, content:\n'"$conf"
    remote_conf_fn=${local_tmp_fn##*/}
    buf=(ssh -o StrictHostKeyChecking=accept-new)
    [[ ! $buf =~ $bad_configuration_option_re ]] && cmd_opts=(-o StrictHostKeyChecking=accept-new)
    cmd_opts+=(-p "$local_tmp_fn" "$ssh_host:$remote_conf_fn")
    cmd=(scp "${cmd_opts[@]}")
    for ((i=-1;i<timeout_retry_count;i++))
    do
        run_cmd_with_timeout -t "$opt_t_arg"
        rc=$?
        out=$(<"$out_fn")
        case $rc in
            0)
                [[ $out = '' ]] && break
                ;&
            1)
                if [[ ! $out =~ $scp_out_ok_re ]]; then    # Failed
                    msg W "Failed running ${cmd[*]}.  rc: $rc, output: $out"
                    fct "${FUNCNAME[0]}" 'returning 1'
                    return 1
                else
                    msg I "$out"
                fi
                ;;
            2)
                # Timed out
        esac
    done
    if (($rc==2)); then
        buf=$(<"$out_fn")
        [[ $buf = '' ]] && msg_part= || msg_part=". Output: $buf"
        msg W "Timed out running ${cmd[*]} after $timeout_retry_count retries$buf"
        fct "${FUNCNAME[0]}" 'returning 2'
        return 2
    fi

    # Run remote agent
    # ~~~~~~~~~~~~~~~~
    # Syntax
    # remote_agent -D -c file [-d] [-h] [-l log|-L dir] [-t dir]
    # or
    # remote_agent -b retention -c file [-d] [-h] [-l log|-L dir] [-t dir]
    # where:
    #     -b backup directory mode with retention days
    #     -c configuration file
    #     -D directory existence report mode
    #     -d debugging on
    #     -h prints this help and exits
    #     -l log file
    #     -L log directory
    #     -p PID directory
    if [[ $remote_agent_opt = -D ]]; then
        msg I 'Running remote agent to check directory existence'
    else
        msg I "Running remote agent to remove old changed and deleted files for retention ${remote_agent_opt#-b }"
    fi
    remote_agent_args=("$remote_agent_opt" -c "$remote_conf_fn")
    [[ $opt_l_flag ]] && remote_agent_args+=(-L "$ssh_host_log_dir")
    [[ $opt_p_flag ]] && remote_agent_args+=(-p "$ssh_host_pid_dir")
    cmd=(ssh "$ssh_host"
        "/usr/bin/remote_agent ${remote_agent_args[@]}"
    )
    for ((i=-1;i<timeout_retry_count;i++))
    do
        run_cmd_with_timeout -t "$opt_t_arg"
        rc=$?
        case $rc in
            0)
                break
                ;;
            1)
                msg W "Failed running ${cmd[*]}.  Output: $($tmp_dir/out)"
                fct "${FUNCNAME[0]}" 'returning 1'
                return 1
                ;;
            2)
                # Timed out
        esac
    done
    if (($rc==2)); then
        msg W "Timed out running ${cmd[*]} after $timeout_retry_count retries"
        fct "${FUNCNAME[0]}" 'returning 2'
        return 2
    fi

    # Remove conf file from remote host
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg D 'Removing conf file from remote host'
    saved_out=$(<"$out_fn")    # Save for restore
    cmd=(ssh "$ssh_host" "rm $remote_conf_fn")
    for ((i=-1;i<timeout_retry_count;i++))
    do
        run_cmd_with_timeout -t "$opt_t_arg"
        rc=$?
        out=$(<"$out_fn")
        case $rc in
            0)
                [[ $out = '' ]] && break
                ;&
            1)
                # Failed
                msg W "Failed running ${cmd[*]}.  Output: $out)"
                echo "$saved_out" > "$out_fn"
                # Return 0 because the remote agent has run OK
                fct "${FUNCNAME[0]}" 'returning 0'
                return 0
                ;;
            2)
                # Timed out
        esac
    done
    if (($rc==2)); then
        msg W "Timed out running ${cmd[*]} after $timeout_retry_count retries"
        echo "$saved_out" > "$out_fn"
        # Return 0 because the remote agent has run OK
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi

    echo "$saved_out" > "$out_fn"
    fct "${FUNCNAME[0]}" 'returning 0'
    return 0
}  #  end of function run_remote_agent
# vim: filetype=bash:
