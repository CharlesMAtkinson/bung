# Copyright (C) 2013 Charles Atkinson
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
# Name: postprocess_org_name_conf
# Purpose:
#     Processes any organisation name from the conf file, overriding it with
#     any -o option value
# Arguments:
#     $1: the organisation name from the conf file or the default "(unknown organisation)"
#     $2: the organisation name from the command line or an empty string
#     $3: option -o flag.  $true when -o option used; $false otherwise
# Global variable usage:
#   Sets org_name or adds an error message to emsg
# Output: none
# Return value: always 0; does not return on error
#--------------------------
function postprocess_org_name_conf {
    local org_name_conf=${1:-}
    local org_name_optarg=${2:-}
    local opt_o_flag=${3:-}

    if [[ $org_name_conf = '(unknown organisation)' ]]; then
        if [[ $opt_o_flag ]]; then
            org_name=$org_name_optarg
        else
            emsg+=$msg_lf"Organisation name is required when the -o option is not used"
            return
        fi  
    else 
        if [[ ! $opt_o_flag ]]; then
            [[ $org_name_conf =~ / ]] && \
                emsg+=$msg_lf"Organisation name is invalid: '$org_name_conf' (may not contain /)"
            org_name=$org_name_conf
        else
            [[ $org_name_optarg != $org_name_conf ]] \
                && msg I "Command line -o $org_name_optarg overriding the configuration file's $org_name"
            org_name=$org_name_optarg
        fi
    fi  

    [[ ${org_name:-} = '' ]] \
        && msg E "Programming error: function ${FUNCNAME[0]}: no org_name set.  \$1: ${1:-}, \$2: ${2:-}, \$3: ${3:-}"
}  # End of function postprocess_org_name_conf
# vim: filetype=bash:
