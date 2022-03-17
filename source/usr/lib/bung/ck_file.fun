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
# Name: ck_file
# Purpose: for each file listed in the argument list: checks that it is 
#   * reachable and exists
#   * is of the type specified (block special, ordinary file or directory)
#   * has the requested permission(s) for the user
#   * optionally, is absolute (begins with /)
# Usage: ck_file [ path <file_type>:<permissions>[:[a]] ] ...
#   where 
#     file  is a file name (path)
#     file_type  is b (block special file), f (file) or d (directory)
#     permissions  is none or more of r, w and x
#     a  requests an absoluteness test (that the path begins with /)
#   Example: ck_file foo d:rwx:
# Outputs:
#   * For the first requested property each file does not have, a message to
#     stderr
#   * For the first detected programminng error, a message to
#     stderr
# Returns: 
#   0 when all files have the requested properties
#   1 when at least one of the files have the requested properties
#   2 when a programming error is detected
#--------------------------
function ck_file {

    local absolute_flag buf file_name file_type perm perms retval

    # For each file ...
    # ~~~~~~~~~~~~~~~~~
    retval=0
    while [[ $# -gt 0 ]]
    do  
        file_name=$1
        file_type=${2%%:*}
        buf=${2#$file_type:}
        perms=${buf%%:*}
        absolute=${buf#$perms:}
        [[ $absolute = $buf ]] && absolute=
        case $absolute in 
            '' | a )
                ;;
            * )
                echo "ck_file: invalid absoluteness flag in '$2' specified for file '$file_name'" >&2
                return 2
        esac
        shift 2

        # Is the file reachable and does it exist?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        case $file_type in
            b ) 
                if [[ ! -b $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not a block special file" >&2
                    retval=1
                    continue
                fi  
                ;;  
            f ) 
                if [[ ! -f $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not an ordinary file" >&2
                    retval=1
                    continue
                fi  
                ;;  
            d ) 
                if [[ ! -d $file_name ]]; then
                    echo "directory '$file_name' is unreachable, does not exist or is not a directory" >&2
                    retval=1
                    continue
                fi
                ;;
            * )
                echo "Programming error: ck_file: invalid file type '$file_type' specified for file '$file_name'" >&2
                return 2
        esac

        # Does the file have the requested permissions?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        buf="$perms"
        while [[ $buf ]]
        do
            perm="${buf:0:1}"
            buf="${buf:1}"
            case $perm in
                r )
                    if [[ ! -r $file_name ]]; then
                        echo "$file_name: no read permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                w )
                    if [[ ! -w $file_name ]]; then
                        echo "$file_name: no write permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                x )
                    if [[ ! -x $file_name ]]; then
                        echo "$file_name: no execute permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                * )
                    echo "Programming error: ck_file: invalid permisssion '$perm' requested for file '$file_name'" >&2
                    return 2
            esac
        done

        # Does the file have the requested absoluteness?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $absolute = a && ${file_name:0:1} != / ]]; then
            echo "$file_name: does not begin with /" >&2
            retval=1
        fi

    done

    return $retval

}  #  end of function ck_file
# vim: filetype=bash:
