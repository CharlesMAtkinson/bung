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
# Purpose: error traps rsync-specific files and directories
# Arguments: none
# Return code: always 0; does not return on error
#--------------------------
function err_trap_rsync_files_and_dirs {
    fct "${FUNCNAME[0]}" 'started'
    local buf fn
    local my_emsg=

    local -r remote_fs_regex='^[^/]*:'

    if [[ $src_dir != '' && ! $src_dir =~ $remote_fs_regex ]]; then
        buf=$(ck_file "$src_dir" d:rx 2>&1)
        if [[ $buf != '' ]]; then
            my_emsg+=$msg_lf"rsync source directory: $buf"
        fi
    fi
    if [[ $rsync_exclude_fn != '' ]]; then
        buf=$(ck_file "$rsync_exclude_fn" f:r 2>&1)
        if [[ $buf != '' ]]; then
            my_emsg+=$msg_lf"rsync --exclude-from file: $buf"
        fi
    fi

    if [[ $my_emsg != '' ]]; then
        msg E "File and/or directory problems:$my_emsg"
    fi

    fct "${FUNCNAME[0]}" 'returning'
    return
}  # end of function err_trap_rsync_files_and_dirs
# vim: filetype=bash:
