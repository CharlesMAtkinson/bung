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
# Name: fct
# Purpose: function call trace (for debugging)
# $1 - name of calling function 
# $2 - message.  If it starts with "started" or "returning" then the output is prettily indented
#--------------------------
function fct {

    if [[ ! $debugging_flag ]]; then
        return 0
    fi  

    fct_indent="${fct_indent:=}"

    case $2 in
        'started'* )
            fct_indent="$fct_indent  "
            msg D "$fct_indent$1: $2"
            ;;  
        'returning'* )
            msg D "$fct_indent$1: $2"
            fct_indent="${fct_indent#  }"  
            ;;  
        * ) 
            msg D "$fct_indent$1: $2"
    esac

}  # end of function fct
# vim: filetype=bash:
