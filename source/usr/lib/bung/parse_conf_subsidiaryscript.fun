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
# Name: parse_conf_subsidiaryscript
# Purpose:
#   Parses a "Subsidiary script" line from the configuration file
# Arguments:
#   $1 - the "Subsidiary script" keyword as read from the configuration file (not normalised)
#   $2 - the "Subsidiary script" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       line_n
#       true and false
#   Set:
#       subsidiaryscript_idx incremented
#       pc_emsg appended with any error message
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_subsidiaryscript {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf conf idx msg my_rc name regex subval unparsed_str

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
    # Subsidiary script = <script name> <config file name> [debug]
    #     [ionice=<ionice>] [nice=<nice>] [schedule=<time_regex>]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    name=$parsed_word

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    conf=$parsed_word

    if [[ $conf != '' ]]; then
        idx=$((++subsidiaryscript_idx))
        subsidiaryscript_name[idx]=$name
        subsidiaryscript_conf[idx]=$conf

        # Get any sub-keyword values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~
        subsidiaryscript_debug[idx]=$false
        subsidiaryscript_ionice[idx]=
        subsidiaryscript_nice[idx]=
        subsidiaryscript_schedule[idx]=
        local -r valid_subkeywords='debug ionice nice schedule'
        local -A subkey_validation
        subkey_validation[name]='
            debug
            ionice
            nice
            schedule
        '
        subkey_validation[value_required]='
            ionice
            nice
            schedule
        '
        subkey_validation[value_invalid]=' debug '
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done
    else
        [[ $name = '' ]] && msg='script name' || msg='config file name'
        pc_emsg+=$msg_lf"Subsidiary script $msg missing (line $line_n)"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_subsidiaryscript
# vim: filetype=bash:
