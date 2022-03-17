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
# Name: is_fs_mounted
# Purpose: detects whether a file system is mounted
# Arguments:
#   $1: fs_spec (in the sense described on the fstab man page).
#       Sometimes there are multiple fs_spec alternatives for the same file
#       system (for example: UUID, LABEL, symlink).  In these cases, $1 must be
#       the alternative that is listed in /proc/mounts when it is mounted.
# Global variables:
#   is_fs_mounted_out (array): set to any mountpoints of fs_spec 
# Outputs: none
# Return code: always 0; does not return on error
# Usage: 
#   After calling, check whether is_fs_mounted_out is set, for example:
#       [[ ${is_fs_mounted_out+dummy} != '' ]]
#--------------------------
function is_fs_mounted {
    fct "${FUNCNAME[0]}" 'started'
    local i match_fs_spec pm_fs_spec pm_fs_file

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r fs_spec=${1:-}
    [[ $fs_spec = '' ]] && msg E "${FUNCNAME[0]}: programming error: \$1 is empty"

    # Initialise
    # ~~~~~~~~~~
    i=0
    unset is_fs_mounted_out

    # Is fs_spec mounted?
    # ~~~~~~~~~~~~~~~~~~~
    while read -r pm_fs_spec pm_fs_file _
    do
        if [[ $pm_fs_spec = $fs_spec ]]; then
            is_fs_mounted_out[i++]=$pm_fs_file
        fi
    done < <(cat /proc/mounts)

    fct "${FUNCNAME[0]}" returning
    return
}  # end of is_fs_mounted
# vim: filetype=bash:
