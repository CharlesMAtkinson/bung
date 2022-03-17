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
# Name: ck_ip_address
# Purpose: checks IP address validity
# Usage: ck_ip_address <putative ip_address>
# Outputs: none
# Returns: 
#   0 when $1 is a valid IP address
#   1 otherwise
#--------------------------
function ck_ip_address {
    local regex='^[[:digit:]]+(.[[:digit:]]+){3}$'
    [[ $1 =~ $regex ]] && return 0 || return 1
}  #  end of function ck_ip_address
# vim: filetype=bash:
