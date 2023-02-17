#! /bin/bash

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

# Purpose: ensures storage set up on local computer:
#   * LV
#   * File system on LV
#   * Mountpoint
#   * /etc/fstab line
#   * File system mounted

# Usage:
#   See usage function or use -h option.

# Programmers' notes: top level function call tree
#    +
#    |
#    +-- initialise
#    |   |
#    |   +-- usage
#    |
#    +-- ensure_lv
#    |
#    +-- ensure_file_system
#    |
#    +-- ensure_mountpoint
#    |
#    +-- ensure_fstab_line
#    |
#    +-- ensure_mounted
#    |
#    +-- finalise
#
# Utility functions called from various places:
#    msg

#--------------------------
# Name: ensure_file_system
# Purpose: ensures the logical volume exists
#--------------------------
function ensure_file_system {
    local buf cmd rc

    # Does the LV already contain an ext4 file system?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    file -s $(readlink -f "/dev/$vg_name/$lv_name") \
        | grep --quiet ' ext4 filesystem data,'
    if (($?==0)); then
        msg I "LV $lv_name already has an ext4 file system"
        return 0
    fi

    # The LV does not contain an ext4 file system.  Create it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I "Creating ext4 file system in LV $lv_name"
    cmd=(mkfs.ext4 -L "$file_system_label" "/dev/$vg_name/$lv_name")
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi

}  # end of function ensure_file_system

#--------------------------
# Name: ensure_fstab_line
# Purpose: ensures a line in /etc/fstab for the file system
#--------------------------
function ensure_fstab_line {
    local buf cmd rc regex
    local -r fstab_fn=/etc/fstab

    # Does fstab already contain an line for the file system?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    regex="^[[:space:]]*LABEL=$file_system_label[[:space:]]"
    grep --extended-regexp --quiet "$regex" "$fstab_fn"
    if (($?==0)); then
        msg I "$fstab_fn already has a line for LABEL=$file_system_label with $mountpoint"
        return 0
    fi
    regex+="[[:space:]]$mountpoint[[:space:]]"
    grep --extended-regexp --quiet "$regex" "$fstab_fn"
    if (($?==0)); then
        msg I "$fstab_fn already has a line for mountpoint $mountpoint"
        return 0
    fi

    # fstab does not contain a line for the file system.  Create it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I "Creating a line in $fstab_fn for LABEL=$file_system_label with $mountpoint"
    cmd=(bu "$fstab_fn")
    buf=$("${cmd[@]}" 2>&1)    # Backup /etc/fstab
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi
    cmd=(echo "LABEL=$file_system_label" "$mountpoint" 
        ext4 noatime,nodiratime,nofail 0 2
    )
    buf=$("${cmd[@]}" 2>&1 >>"$fstab_fn")
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi

}  # end of function ensure_fstab_line

#--------------------------
# Name: ensure_lv
# Purpose: ensures the logical volume exists
#--------------------------
function ensure_lv {
    local buf cmd msg rc regex

    # Does the LV exist?
    # ~~~~~~~~~~~~~~~~~~
    regex="^[[:space:]]*$vg_name[[:space:]]*$lv_name"
    lvs -o vg_name,lv_name | grep --quiet "$regex"
    if (($?==0)); then
        msg I "LV $lv_name already exists in VG $vg_name"
        return 0
    fi

    # The LV does not exist.  Create it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I "Creating LV $lv_name in VG $vg_name"
    cmd=(lvcreate --name "$lv_name" --size "$lv_size"k --yes "$vg_name")
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi

}  # end of function ensure_lv

#--------------------------
# Name: ensure_mountpoint
# Purpose: ensures the mountpoint exists
#--------------------------
function ensure_mountpoint {
    local buf cmd rc

    if [[ -d "$mountpoint" ]]; then
        msg I "Mountpoint $mountpoint already exists"
        return 0
    fi

    msg I "Creating mountpoint $mountpoint"
    cmd=(mkdir -p "$mountpoint")
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi

}  # end of function ensure_mountpoint

#--------------------------
# Name: ensure_mounted
# Purpose: ensures the file system is mounted
#--------------------------
function ensure_mounted {
    local buf cmd rc regex

    # Is the file system already mounted?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    findmnt --source "LABEL=$file_system_label" --mountpoint "$mountpoint" \
        >/dev/null
    if (($?==0)); then
        msg I "File system with LABEL=$file_system_label already mounted at $mountpoint"
        return 0
    fi

    # The file system is not mounted.  Mount it
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I "Mounting file system with LABEL=$file_system_label"
    cmd=(mount "LABEL=$file_system_label")
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    if ((rc!=0)); then
        msg="Command: ${cmd[*]}"
        msg+=$msg_lf"rc: $rc"
        msg+=$msg_lf"Output: $buf"
        msg E "$msg"
    fi

}  # end of function ensure_mounted

#--------------------------
# Name: finalise
# Purpose: exits
# Arguments:
#    $1  exit value
#--------------------------
function finalise {
    finalising_flag=$true

    if [[ ${1:-} =~ $uint_regex ]]; then
       (($1<128)) && exit $1
       msg E "finalise called with invalid exit value $1"
    else
       msg E "finalise called with invalid exit value ${1:-}"
    fi

    # Should not get here
    exit 1
}  # end of function finalise

#--------------------------
# Name: initialise
# Purpose: sets up environment, parses command line and sets OS-dependent variables
#--------------------------
function initialise {
    local OPTIND    # Required when getopts is called in a function
    local msg

    # Configure shell environment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    export PATH=/usr/local/bin:/usr/sbin:/sbin:/usr/bin:/bin
    IFS=$' \n\t'
    set -o nounset
    shopt -s extglob            # Enable extended pattern matching operators
    unset CDPATH                # Ensure cd behaves as expected
    umask 022

    # Set global read-only logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    declare -gr false=
    declare -gr true=true

    # Set global read-only string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    declare -gr script_name=${0##*/}
    declare -gr msg_lf=$'\n    '
    declare -gr uint_regex='^[[:digit:]]+$'

    # Set global string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    declare -g finalising_flag=$false

    # Initialise local string variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    local args=("$@")
    local emsg=

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    local opt_l_flag=$false
    local opt_n_flag=$false
    local opt_m_flag=$false
    local opt_s_flag=$false
    local opt_v_flag=$false
    debugging_flag=$false
    while getopts :dhl:m:n:v:s: opt "$@"
    do
        case $opt in
            d )
                debugging_flag=$true
                ;;
            h )
                debugging_flag=$false
                usage verbose
                exit 0
                ;;
            l )
                opt_l_flag=$true
                file_system_label=$OPTARG
                ;;
            m )
                opt_m_flag=$true
                mountpoint=$OPTARG
                ;;
            n )
                opt_n_flag=$true
                lv_name=$OPTARG
                ;;
            s )
                opt_s_flag=$true
                lv_size=$OPTARG
                ;;
            v )
                opt_v_flag=$true
                vg_name=$OPTARG
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Test for mutually exclusive arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive arguments

    # Test for mandatory arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_l_flag ]] && emsg+=$msg_lf"Option -l is required"
    [[ ! $opt_n_flag ]] && emsg+=$msg_lf"Option -n is required"
    [[ ! $opt_m_flag ]] && emsg+=$msg_lf"Option -m is required"
    [[ ! $opt_s_flag ]] && emsg+=$msg_lf"Option -s is required"
    [[ ! $opt_v_flag ]] && emsg+=$msg_lf"Option -v is required"

    # Validate option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $opt_l_flag ]] && ((${#file_system_label}>16)); then
        emsg+=$msg_lf"Invalid file system label $file_system_label"
        emsg+=" (more than 16 characters)"
    fi
    [[ $opt_l_flag ]] && [[ ! $lv_size =~ $uint_regex ]] \
        && emsg+=$msg_lf"Invalid LV size $lv_size (not unsigned integer)"

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    # Report any command line errors
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        emsg+=$msg_lf'(-h for help)'
        msg E "Command line error(s)$emsg"
    fi
}  #  end of function initialise

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: I, D, W or E indicating Information, Debug, Warning or Error
#    $2 message text
# Output: fomattted messages to stderr
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
            prefix='WARN: '
            ;;  
        * ) 
            msg E "msg: invalid class '$class': '$*'"
    esac

    # Write to stderr
    # ~~~~~~~~~~~~~~~
    message_text="$prefix$message_text"
    echo "$message_text" >&2
    if [[ $class = E ]]; then
        [[ ! $finalising_flag ]] && finalise 1 
    fi

    return 0
}  #  end of function msg

#--------------------------
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage: $script_name [-d] -l <file system label> [-h] -m <mountpoint> -n <LV name> -s <LV size> -v <VG name>"
    msg='  where:'
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -l file system label, max 16 characters'
    msg+=$'\n    -h prints this help and exits'
    msg+=$'\n    -m mountpoint (directory)'
    msg+=$'\n       Example: /srv/backup/ansible-client.iciti.av'
    msg+=$'\n    -n logical volume name'
    msg+=$'\n       Example: ansible-client.iciti.av'
    msg+=$'\n    -s logical volume size in kB'
    msg+=$'\n    -v volune group name'

    # Display the message(s)
    # ~~~~~~~~~~~~~~~~~~~~~~
    echo "$usage" >&2
    if [[ ${1:-} != 'verbose' ]]; then
        echo "(use -h for help)" >&2
    else
        echo "$msg" >&2
    fi
}  # end of function usage

#--------------------------
# Name: main
# Purpose: the main sequence; execution starts here
#--------------------------
initialise "${@:-}"
ensure_lv
ensure_file_system
ensure_mountpoint
ensure_fstab_line
ensure_mounted
finalise 0
