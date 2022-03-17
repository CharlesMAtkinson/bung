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
# Name: err_trap_snapshot_conf
# Purpose: 
#   Error traps snapshot configuration values
# Arguments: none
#   Read:
#       msg_lf
#       snapshot_idx
#       snapshot_org_vol[]
#       snapshot_size[]
#   Write:
#       emsg: any error messages added
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function err_trap_snapshot_conf {
    fct "${FUNCNAME[0]}" started
    local buf i org_vol size vg vol

    # Initialise
    # ~~~~~~~~~~
    local my_emsg=
    local my_rc=0
    local -r valid_size_regex='^[[:digit:]]+[bBsSkKmMgGtTpPeE]?$'

    # Error trap each snapshot
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=snapshot_idx;i++))
    do
        # Original volume path
        # ~~~~~~~~~~~~~~~~~~~~
        org_vol=${snapshot_org_vol[i]}
        [[ ! -b $org_vol ]] \
            && my_emsg+=$msg_lf"Invalid original volume path $org_vol (does not exist)"

        # Size
        # ~~~~
        size=${snapshot_size[i]}
        if [[ $size != '' ]]; then
            buf=${size//,/}    # Remove any comma thousands separators
            [[ ! $buf =~ $valid_size_regex ]] \
                && my_emsg+=$msg_lf"Invalid snapshot size $size (does not match regex $valid_size_regex after removal of any , thousands separators)"
        fi
    done

    [[ $my_emsg != '' ]] && { my_rc=1; emsg+=$my_emsg; }
    
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function err_trap_snapshot_conf
# vim: filetype=bash:
