#!/bin/bash

# Purpose
#   * A pre-hook script for use with bung to stop VirtualBox VMs controlled by
#     instances of vboxvmservice@.service
#   * For each enabled instance of vboxvmservice@.service:
#       If systemd reports the instance as active:
#           systemctl stop vboxvmservice@<instance_name>.service
#       As the user named in vboxvmservice@.service:
#           List running VMs
#           If the VM is listed, shut it down
# Notes
#   * For simplicity the templated service is called vboxvmservice@.service
#     above and below.  It is actually what is named in the conffile
#   * The templated service's [Install] section must have
#     "WantedBy=multi-user.target"
#   * "Enabled" means there is a symlink with the instance name in
#     /etc/systemd/system/multi-user.target.wants
#
# Usage: run with -h option or see usage function

# Programmers' notes: bash library
#   * May be changed by setting environment variable BUNG_LIB_DIR
export BUNG_LIB_DIR=${BUNG_LIB_DIR:-/opt/bung/lib}
source "$BUNG_LIB_DIR/version.scrippet" || exit 1

# Function call tree
#    +
#    |
#    +-- initialise
#    |   |
#    |   +-- usage
#    |
#    +-- get_enabled_instances
#    |
#    +-- stop_enabled_instances
#    |   |
#    |   +-- stop_enabled_instance
#    |       |
#    |       + is_vm_running
#    |
#    +-- finalise
#
# Utility functions called from various places:
#    ck_file ck_uint fct msg

source "$BUNG_LIB_DIR/ck_file.fun" || exit 1
source "$BUNG_LIB_DIR/ck_uint.fun" || exit 1
source "$BUNG_LIB_DIR/fct.fun" || exit 1

#--------------------------
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#    $1  return value
# Return code (on exit): 
#    * If terminated by a signal, $pre_hook_rc_e
#    * Otherwise $1
#--------------------------
function finalise {
    fct "${FUNCNAME[0]}" "started with args $*"

    my_retval=$1
    finalising_flag=$true

    # Interrupted?  Message and exit return value
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if ck_uint "${1:-}" && (($1>128)); then
        my_retval=$pre_hook_rc_e
        case $1 in
            129 )
                buf=SIGHUP
                ;;
            130 )
                buf=SIGINT
                ;;
            131 )
                buf=SIGQUIT
                ;;
            132 )
                buf=SIGILL
                ;;
            134 )
                buf=SIGABRT
                ;;
            135 )
                buf=SIGBUS
                ;;
            136 )
                buf=SIGFPE
                ;;
            138 )
                buf=SIGUSR1
                ;;
            139 )
                buf=SIGSEGV
                ;;
            140 )
                buf=SIGUSR2
                ;;
            141 )
                buf=SIGPIPE
                ;;
            142 )
                buf=SIGALRM
                ;;
            143 )
                buf=SIGTERM
                ;;
            146 )
                buf=SIGCONT
                ;;
            147 )
                buf=SIGSTOP
                ;;
            148 )
                buf=SIGTSTP
                ;;
            149 )
                buf=SIGTTIN
                ;;
            150 )
                buf=SIGTTOU
                ;;
            151 )
                buf=SIGURG
                ;;
            152 )
                buf=SIGCPU
                ;;
            153 )
                buf=SIGXFSZ
                ;;
            154 )
                buf=SIGVTALRM
                ;;
            155 )
                buf=SIGPROF
                ;;
            * )
                msg E "${FUNCNAME[0]}: programming error: \$1 ($1) not serviced"
                ;;
        esac
        interrupt_flag=$true
        msg="Finalising on $buf"
        msg E "$msg"    # Returns because finalising_flag is set
    fi

    fct "${FUNCNAME[0]}" "exiting $my_retval"
    exit $my_retval
}  # end of function finalise

#--------------------------
# Name: get_enabled_instances
# Purpose: 
#   * For each enabled instance of vboxvmservice@.service, get the instance name
#     and the VM name
#--------------------------
function get_enabled_instances {
    fct "${FUNCNAME[0]}" 'started'
    local buf instance

    instances=$(
        find -L /etc/systemd/system/multi-user.target.wants/ \
        -samefile "$template_fn" | sed 's|.*/||'
    )
    if [[ $instances != '' ]]; then
         msg I "Found instances: ${instances[*]}"
    else
         msg I "No instances of $template_fn found"
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function get_enabled_instances

#--------------------------
# Name: initialise
# Purpose: sets up environment, parses command line, reads config file
#--------------------------
function initialise {
    local args buf emsg opt template

    # Configure shell environment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    export LANG=en_GB.UTF-8
    export LANGUAGE=en_GB.UTF-8
    for var_name in LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION \
        LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER \
        LC_TELEPHONE LC_TIME 
    do
        unset $var_name
    done

    export PATH=/usr/sbin:/sbin:/usr/bin:/bin
    IFS=$' \n\t'
    set -o nounset
    shopt -s extglob            # Enable extended pattern matching operators
    unset CDPATH                # Ensure cd behaves as expected
    umask 022

    # Initialise some global logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    readonly false=
    readonly true=true
    
    debugging_flag=$false
    error_flag=$false
    finalising_flag=$false
    interrupt_flag=$false
    warning_flag=$false

    # Initialise some global string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    final_msg=
    readonly msg_lf=$'\n    '              # Message linefeed and indent
    readonly my_name=${0##*/}
    readonly pre_hook_rc_e=4
    readonly pre_hook_rc_i_continue=0
    readonly pre_hook_rc_i_finalise=1
    readonly pre_hook_rc_w_continue=2
    readonly pre_hook_rc_w_finalise=3

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    args=("$@")
    args_org="$*"
    conf_fn=/etc/opt/bung/${my_name%.sh}.conf
    emsg=
    opt_r_flag=$false
    while getopts :c:dhr: opt "$@"
    do
        case $opt in
            c )
                conf_fn=$OPTARG
                ;;
            d )
                debugging_flag=$true
                ;;
            h )
                debugging_flag=$false
                usage verbose
                exit 0
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                [[ $OPTARG = c ]] && { opt_c_flag=$true; conf_fn=/bin/bash; }
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Check for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mandatory options

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive options

    # Validate option values
    # ~~~~~~~~~~~~~~~~~~~~~~
    [[ ! -r "$conf_fn" ]] \
        && emsg+=$msg_lf"$conf_fn does not exist or is not readable"

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        msg E "$emsg"
    fi

    # Set traps
    # ~~~~~~~~~
    trap 'finalise 129' 'HUP'
    trap 'finalise 130' 'INT'
    trap 'finalise 131' 'QUIT'
    trap 'finalise 132' 'ILL'
    trap 'finalise 134' 'ABRT'
    trap 'finalise 135' 'BUS'
    trap 'finalise 136' 'FPE'
    trap 'finalise 138' 'USR1'
    trap 'finalise 139' 'SEGV'
    trap 'finalise 140' 'USR2'
    trap 'finalise 141' 'PIPE'
    trap 'finalise 142' 'ALRM'
    trap 'finalise 143' 'TERM'
    trap 'finalise 146' 'CONT'
    trap 'finalise 147' 'STOP'
    trap 'finalise 148' 'TSTP'
    trap 'finalise 149' 'TTIN'
    trap 'finalise 150' 'TTOU'
    trap 'finalise 151' 'URG'
    trap 'finalise 152' 'XCPU'
    trap 'finalise 153' 'XFSZ'
    trap 'finalise 154' 'VTALRM'
    trap 'finalise 155' 'PROF'

    # Read conffile
    # ~~~~~~~~~~~~~
    source "$conf_fn"
    if [[ ${template:-} != '' ]]; then
        buf=$(ck_file "$template" f:r:a 2>&1)
        [[ $buf != '' ]] && emsg+=$'\n'"$buf"
    else
        emsg+=$'\n'"template not specified or empty"
    fi
    [[ $emsg != '' ]] && msg E "$conf_fn$emsg"
    template_fn=$template

    # Get the user from the template
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(grep -i '^User=' "$template_fn" 2>&1)
    [[ $buf == '' ]] && msg E "User= not found in $template_fn"
    buf=$(echo "$buf" | head -1 | sed 's/User=//')
    user=$(echo $buf)    # Strip any whitespace
    msg I "Configuration file: $conf_fn, template: $template, user: $user"

}  # end of function initialise

#--------------------------
# Name: is_vm_running
# Purpose: 
#   * Return
#     0 if the named VM is running
#     1 if the named VM is not running
#--------------------------
function is_vm_running {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd rc
    local -r vm_name=$1

    cmd=(sudo --user="$user" vboxmanage list runningvms)
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    msg D "Output from ${cmd[*]}: $buf"
    ((rc!=0)) && [[ $buf =~ error ]] \
        && msg W "'error' in output from ${cmd[*]}: $buf"
    echo "$buf" | grep --quiet "^\"$vm_name\""
    rc=$?

    fct "${FUNCNAME[0]}" "returning $rc"
    return $rc
}  # end of function is_vm_running

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: D, E, I or W indicating Debug, Error, Information or Warning
#    $2 message text
# Global variables read:
#     debugging_flag
# Global variables written:
#     error_flag
#     warning_flag
# Output: information messages to stdout; the rest to stderr
# Returns: 
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
#--------------------------
function msg {
    local buf class message_text prefix

    # Process arguments
    # ~~~~~~~~~~~~~~~~~
    class="${1:-}"
    message_text="${2:-}"

    # Class-dependent set-up
    # ~~~~~~~~~~~~~~~~~~~~~~
    case "$class" in  
        D ) 
            [[ ! $debugging_flag ]] && return
            prefix='DEBUG: '
            ;;  
        E ) 
            error_flag=$true
            prefix='ERROR: '
            ;;  
        I ) 
            prefix=
            ;;  
        W ) 
            warning_flag=$true
            prefix='WARN: '
            ;;  
        * ) 
            msg E "msg: invalid class '$class': '$*'"
    esac
    message_text="$prefix$message_text"

    # Write to stdout or stderr
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    message_text="$(date '+%H:%M:%S') $message_text"
    if [[ $class = I ]]; then
        echo "$message_text"
    else
        echo "$message_text" >&2
        if [[ $class = E ]]; then
            # Tell bung script to generate error too
            [[ ! $finalising_flag ]] && finalise $pre_hook_rc_e
        fi
    fi  

    return 0
}  #  end of function msg

#--------------------------
# Name: stop_enabled_instance
# Purpose: 
#   * Stop an enabled instance of vboxvmservice@.service
#--------------------------
function stop_enabled_instance {
    fct "${FUNCNAME[0]}" 'started'
    local buf rc vm_name
    local -r instance=$1
    local -r sleep=5
    local -r time_allowed_for_shutdown=120

    # If the instance is active, stop it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(systemctl show "$instance" --property ActiveState --value 2>&1)
    if [[ $buf == active ]]; then
        msg I "Instance $instance is active; stopping it"
        cmd=(systemctl stop "$instance")
        buf=$("${cmd[@]}" 2>&1)
        [[ $buf != '' ]] && msg W "Unexpected output from ${cmd[*]}: $buf"
    else
        msg I "Instance $instance is not active"
    fi

    # If the VM is running, shut it down
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # This is required in case the VM has been started other than by the systemd instance
    # The core of this is same as in shut_down_vbox_vm.sh
    vm_name=$(echo $instance | sed -e 's/.*@//' -e 's/\.service//')
    msg I "VM name is $vm_name"
    is_vm_running "$vm_name"
    rc=$?
    if ((rc==0)); then
        msg I "VM $vm_name is running; shutting down via ACPI button as user $user"
        cmd=(sudo --user="$user" vboxmanage controlvm "$vm_name" acpipowerbutton)
        buf=$("${cmd[@]}" 2>&1)
        rc=$?
        [[ $buf != '' ]] && msg W "Unexpected output from ${cmd[*]}: $buf"
        msg I "Waiting up to $time_allowed_for_shutdown seconds for $vm_name to shut down"
        for ((i=0;i<time_allowed_for_shutdown;i=i+sleep))
        do
            sleep $sleep
            is_vm_running "$vm_name"
            rc=$?
            ((rc==1)) && break
        done
        ((rc==0)) && msg E "Failed to shut down $vm_name. Aborting backup"
    fi
    msg I "VM $vm_name is not running"

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function stop_enabled_instance

#--------------------------
# Name: stop_enabled_instances
# Purpose: 
#   * Stop each enabled instance of vboxvmservice@.service
#--------------------------
function stop_enabled_instances {
    fct "${FUNCNAME[0]}" 'started'
    local instance 

    for instance in $instances
    do
        stop_enabled_instance $instance
    done

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function stop_enabled_instances

#--------------------------
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    fct "${FUNCNAME[0]}" 'started'
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage: $my_name "
    msg='  where:'
    usage+='[-c conffile] [-d] [-h]'
    msg+=$'\n    -c names the configuration file. Default '"$conf_fn"
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -h prints this help and exits'

    # Display the message(s)
    # ~~~~~~~~~~~~~~~~~~~~~~
    echo "$usage" >&2
    if [[ ${1:-} != 'verbose' ]]; then
        echo "(use -h for help)" >&2
    else
        echo "$msg" >&2
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function usage

#--------------------------
# Name: main
# Purpose: where it all happens
#--------------------------
initialise "${@:-}"
get_enabled_instances
stop_enabled_instances
finalise $pre_hook_rc_i_continue
