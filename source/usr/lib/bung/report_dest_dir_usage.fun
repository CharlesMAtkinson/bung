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
# Name: report_dest_dir_usage
# Purpose: reports the destination directory's file system's usage
# Arguments: none
# Global variable usage:
#   dest_dir: read
#   dest_dir_remote_dir: read
#   dest_dir_remote_flag: read
#   dest_dir_remote_host: read
#   dest_dir_usage_warning: read
# Return code: always 0
#--------------------------
function report_dest_dir_usage {
    fct "${FUNCNAME[0]}" 'started'
    local array buf cmd msg_class msg_part msg_part2
    local -r usage_percent_regex='^[[:digit:]]+%$'

    # Get the destination directory usage
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I 'Getting the destination directory usage'
    if [[ $dest_dir_remote_flag ]]; then
        printf -v dest_dir_escaped %q "$dest_dir_remote_dir"
        cmd=(ssh "$dest_dir_remote_host" df "$dest_dir_escaped")
        run_cmd_with_timeout
        if (($?!=2)); then
            buf=$(<"$tmp_dir/out") 
        else
            buf='timed out'
        fi
        msg_part='Remote destination'
    else
        buf=$(df "$dest_dir" 2>&1)
        msg_part=Destination
    fi
    case $buf in
        Filesystem* )
            ;;
        * )
            msg E "Unexpected output checking$msg_part destination directory file system usage: $buf"
            ;;
    esac

    # Report the destination directory usage
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    array=($buf)
    if [[ ${array[11]} =~ $usage_percent_regex ]]; then
        buf=${array[11]//%}
        msg_class=I
        msg_part2=
        if (( dest_dir_usage_warning>0 && buf>dest_dir_usage_warning)); then
            msg_class=W
            msg_part2=" (> $dest_dir_usage_warning%)"
        fi
        msg $msg_class "$msg_part file system ${array[12]} is $buf% full$msg_part2"
    else
        msg W "Unexpected output from$msg_part df $dest_dir: $buf"
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function report_dest_dir_usage
# vim: filetype=bash:
