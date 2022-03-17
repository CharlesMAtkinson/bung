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
# Name: get_fs_type
# Purpose: gets the file system type
# Arguments:
#       $1: fs_spec, as described in the fstab man page
# Global variable usage:
#   Read:
#       $true and $false values
#   Set:
#       fs_type
# Output: none except via function fct
# Return code: always 0; does not return on error
#--------------------------
function get_fs_type {
    fct "${FUNCNAME[0]}" "started, \$1 (fs_type): ${1:-}"
    local buf blkid_out_test_regex cifs_regex dev_regex nfs_regex rc
    local fs_spec=${1:-}

    cifs_regex='^//'
    dev_regex='^/dev/'
    nfs_regex='^[-[:alnum:]]+(\.[-[:alnum:]]+)*:/' 
    blkid_out_test_regex=' TYPE="[^"]+" '

    # Get the file system type
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $fs_spec =~ $dev_regex  ]]; then
        [[ ! -b "$fs_spec" ]] && msg E "File system device file $fs_spec does not exist"
        buf=$(blkid -p "$fs_spec" 2>&1)
        rc=$?
        (($?>0)) && msg E "Unable to get the file system type. blkid rc: $rc, output: $buf"
        [[ $buf = '' ]] && msg E "Unable to get the file system type; no output from blkid $fs_spec.  Has it been formatted?"
        [[ ! $buf =~ $blkid_out_test_regex ]] \
            && msg E "Unable to get the file system type; blkid output does not match regex $blkid_out_test_regex: $buf"
        buf=${buf##* TYPE=\"}
        fs_type=${buf%%\"*}
    elif [[ $fs_spec =~ $cifs_regex  ]]; then
        fs_type=cifs
    elif [[ $fs_spec =~ $nfs_regex  ]]; then
        fs_type=NFS
    else
        msg E "Invalid fs_spec from the Mount configuration: $fs_spec (does not look like /dev/ file, CIFS or NFS)"
    fi 

    fct "${FUNCNAME[0]}" "returning, fs_type: $fs_type"
    return
}  # end of function get_fs_type
# vim: filetype=bash:
