# Copyright (C) 2015 Charles Atkinson
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
# Name: err_trap_ip_address
# Purpose:
#     Error traps a value that should be an unsigned integer
# Arguments:
#     $1: the putative unsigned integer
#     $2: error message prefix
# Global variable usage:
#   Adds any error message to emsg
# Output: none
# Return value:
#   Does not return when there has been a programming error
#   0 when the value is an unsigned integer
#   1 when the value is not an unsigned integer
#--------------------------
function err_trap_ip_address {
    local ip_address=${1:-}
    local emsg_part1=${2:-}
    local my_emsg= my_rc

    # Programming error traps
    [[ $emsg_part1 = '' ]] && my_emsg+=$msg_lf"Programming error: emsg_part1 (\$2) is empty"

    # Check the value
    ck_ip_address "$ip_address" 2>/dev/null
    my_rc=$?
    ((my_rc>0)) && emsg+=$msg_lf"$emsg_part1 '$ip_address' (not a valid IP address)"
    return $my_rc
}  # End of function err_trap_ip_address
# vim: filetype=bash:
