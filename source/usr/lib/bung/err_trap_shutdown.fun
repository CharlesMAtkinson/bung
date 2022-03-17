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
# Name: err_trap_shutdown
# Purpose: 
#   Error traps the shutdown configuration value
# Arguments: none
# Global variable usage
#   Read:
#       shutdown
#   Write:
#       emsg: any error messages added
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_shutdown {
    fct "${FUNCNAME[0]}" started
    local buf 

    # Initialise
    # ~~~~~~~~~~
    local my_emsg=
    local my_rc=0

    buf=${shutdown,,}
    case $buf in
        yes | no )
            ;;
        * )
            my_emsg+=$msg_lf"Invalid shutdown value '$shutdown' (must be yes or no, case-insensitive)"
            ;;
    esac

    [[ $my_emsg != '' ]] && { my_rc=1; emsg+=$my_emsg; }
    
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function err_trap_shutdown
# vim: filetype=bash:
