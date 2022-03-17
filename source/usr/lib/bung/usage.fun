# Copyright (C) 2016 Charles Atkinson
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
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    fct "${FUNCNAME[0]}" 'started'
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage: $script_name "
    msg='  where:'
    usage+='-c conf [-C] [-d] [-h] [-L dir|-l logi] [-o org] [-p] [-t dir]'
    msg+=$'\n    -c configuration file name'
    msg+=$'\n    -C check the configuration file and exit'
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -h prints this help and exits'
    msg+=$'\n    -L log directory (default '"$BUNG_LOG_DIR)"
    msg+=$'\n    -l log file.  Use /dev/tty to log to screen'
    msg+=$'\n    -o organisation name'
    msg+=$'\n    -p path.  Replace the PATH environment variable (default '"$PATH)"
    msg+=$'\n    -t temporary directory (default '"$BUNG_TMP_DIR)"
    msg+=$'\n       If specified, the PID file is created in this directory too'

    if [[ $script_name != super_bu ]]; then
        usage+='[-s] '
        msg+=$'\n    -s subsidiary mode.  Does not finalise log or send report email'
    fi

    if [[ $script_name =~ ^hotplug_.* ]]; then
        usage+='[-u] '
            msg+=$'\n    -u udev mode.  In conjunction with the configuration file, controls the' \
            msg+=$'\n       message class when a hotplug device is not available.'
    fi

    if [[ $script_name = rsync_bu ]]; then
        usage+='[-r] '
        msg+=$'\n    '"-r use rsync's --dry-run option"
    fi

    usage+='[-v] [-w]'
    msg+=$'\n    '"-v prints the script's version and exits"
    msg+=$'\n    -w Windows; make log file name Windows-FAT and NTFS compatible'

    # Display the message(s)
    # ~~~~~~~~~~~~~~~~~~~~~~
    echo "$usage" >&2
    if [[ ${1:-} != 'verbose' ]]; then
        echo "(use -h for help)" >&2
    else
        echo "$msg" >&2
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function usage
# vim: filetype=bash:
