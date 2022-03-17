# Copyright (C) 2019 Charles Atkinson
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
# Name: parse_conf_hotplugdevice
# Purpose:
#   Parses an "Hotplug device" line from the configuration file
#   Note: does not error trap sub-values, only traps syntactical errors
# Arguments:
#   $1 - the keyword as read from the configuration file (not normalised)
#   $2 - the value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       line_n
#       true and false
#   Set:
#       hotplug_dev_idx incremented
#       pc_emsg appended with any error message
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_hotplugdevice {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value:${2:-}, line_n: ${3:-}"
    local buf device_path idx msg_part my_rc unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#!=3)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 3"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse the value
    # ~~~~~~~~~~~~~~~
    # Hotplug device = device_path [missing_device_message_class=<class>]
    #                  [notification_email=<email address> [email_wait=<seconds>]]
    #                  [notification_screen]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    device_path=$parsed_word

    if [[ $device_path != '' ]]; then
        idx=$((++hotplug_dev_idx))
        hotplug_dev_path[idx]=$device_path

        # Get any sub-keyword values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~
        hotplug_dev_missing_msgclass[idx]=
        hotplug_dev_note_email[idx]=
        hotplug_dev_note_email_wait[idx]=
        hotplug_dev_note_screen_flag[idx]=
        local -A subkey_validation
        subkey_validation[name]='
            email_wait
            missing_device_message_class
            notification_email
            notification_screen
        '
        subkey_validation[value_required]='
            email_wait
            missing_device_message_class
            notification_email
        '
        subkey_validation[value_invalid]='notification_screen'
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done
    else
        pc_emsg+=$msg_lf"Subsidiary script device_path missing (line $line_n)"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_hotplugdevice
# vim: filetype=bash:
