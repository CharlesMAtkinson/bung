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
# Name: ck_non_empty_string
# Purpose: checks non-empty string validity
# Usage: ck_non_empty_string <putative non_empty_string>
# Outputs: none
# Returns: 
#   0 when $1 is a non-empty string
#   1 otherwise
#--------------------------
function ck_non_empty_string {
    [[ ${1:-} != '' ]] && return 0 || return 1
}  #  end of function ck_non_empty_string
# vim: filetype=bash:
