# Copyright (C) 2023 Charles Atkinson
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
# Name: my_cat
# Purpose: 
#   Same as "cat --show-nonprinting FILE" (where FILE is not -) except when FILE is > 500,000 bytes.
#   When FILE ($1) is > 500,000 bytes, excerpt the most relevant lines.
# Arguments:
#   $1 - pathname of input file
# Global variable usage: none
# Output: normally as described under "Purpose" above; error messages on stderr
# Return value: 1 when an error is detected, 0 otherwise
# Usage notes:
#--------------------------
function my_cat {
    local buf fn=${1:-} rc size
    local -r max_size=500000

    # Argument error trap
    # ~~~~~~~~~~~~~~~~~~~
    if [[ $fn = '' ]]; then
        echo "Programming error: $script_name, called ${FUNCNAME[0]} with $1 not set" >&2
        return 1
    fi

    # Get size of the input file
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    size=$(stat --printf=%s "$fn" 2>&1)
    if (($?>0)); then
        echo "$script_name: unable to stat '$fn': $size" >&2
        return 1
    fi

    # Output
    # ~~~~~~
    if ((size<max_size)); then
        cat --show-nonprinting "$fn"
    else
        # The warning and error regexes below are also used in the
        # run_subsidiary_scripts function; any changes here should be
        # reflected there.
        # TODO: add mysqldump warnings and errors
        buf="$fn is > $max_size bytes.  Here are some excerpts."
        buf+=$'\n\n'
        buf+=$(sed -En \
                -e '/is unreachable, does not exist or is not a directory$/p' \
                -e '/^IO error encountered/p' \
                -e '/^No return code found /p' \
                -e '/^cannot delete non-empty directory:/p' \
                -e '/^rsync error:/p' \
                -e '/^rsync: /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} .* started on /{N;p}' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Exiting with /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ LVM snapshot volume /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Removed snapshot volume /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Return code [^ ]+ from subsidiary script/p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ Running /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ There was at least one /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ rsync return code /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ (ERROR|WARN): /p' \
                -e '/^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} [^ ]+ (Mounted|Unmounted) /p' \
                "$fn"
        )
        echo "$buf"
    fi

    return
}  # end of function my_cat
# vim: filetype=bash:
