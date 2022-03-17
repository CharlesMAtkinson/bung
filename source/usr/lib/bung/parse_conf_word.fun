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
# Name: parse_conf_word
# Purpose:
#   Parses a word from the configuration file
# Arguments:
#   $1 - the configuration file line number
# Global variable usage:
#   Read:
#       true and false
#       unparsed_str
#   Set:
#       parsed_word
#       pc_emsg appended with any error message
#       unparsed_str: the word and any trailing space removed
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_word {
    fct "${FUNCNAME[0]}" "started with line number: ${1:-} (unparsed_str: $unparsed_str)"
    local buf initial_pc_emsg msg_part msg_prefix msg_postfix my_rc
    local -r quoted_regex='^"'
    local -r space_regex='[[:space:]]'

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if [[ ${1:-} = '' ]]; then
        msg="Programmming error: ${FUNCNAME[0]} called with no arguments"
        msg E "$msg (args: $*)"
    fi
    local -r line_n=$1

    # Parse the next word from $unparsed_str
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    unparsed_str=${unparsed_str##*([[:space:]])}    # Discard any leading spaces and tabs
    if [[ ! $unparsed_str =~ $quoted_regex ]]; then
        read -r parsed_word unparsed_str < <(echo "$unparsed_str")
    else
        unparsed_str=${unparsed_str:1}    # Discard the "
        parsed_word=
        while [[ $unparsed_str != '' ]]   # For each character of the word
        do
            msg D "unparsed_str: $unparsed_str"
            case $unparsed_str in
                '\"'* )
                    parsed_word+='"'
                    unparsed_str=${unparsed_str#'\"'}
                    ;;   
                '"'* )
                    unparsed_str=${unparsed_str:1}
                    break
                    ;;
                '' )
                    pc_emsg+=$msg_lf"Unterminated quoted string (line $line_n)"
                    fct "${FUNCNAME[0]}" "returning with rc 1"
                    return 1
                    ;;
                * )
                    parsed_word+=${unparsed_str:0:1}
                    unparsed_str=${unparsed_str:1}
            esac
        done
    fi
    unparsed_str=${unparsed_str##*([[:space:]])}    # Discard any leading spaces and tabs
    
    fct "${FUNCNAME[0]}" "returning 0. parsed_word: '${parsed_word:-}'"
    return 0
}  # end of function parse_conf_word
# vim: filetype=bash:
