# Copyright (C) 2022 Charles Atkinson
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
# Name: postprocess_rsync_conf
# Purpose:
#     Processes rsync values from the conf file
# Arguments: none
# Global variable usage:
#   Sets backup_retention_0_nowarn_flag[]
#   May change backup_retention[]
# Output: none
# Return value: always 0
#--------------------------
function postprocess_rsync_conf {
    fct "${FUNCNAME[0]}" started
    local hostname identityfile username
    local -r remote_dir_regex='^[^/:]*:'
    local -r trailing_slash_regex='/$'

    # Do nothing when there was no rsync keyword
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ${src_dir:-} = '' ]]; then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi

    # Ensure SRC has trailing /
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    # Required for rsync to work as intended
    if [[ ! ${src_dir:-} =~ $trailing_slash_regex ]]; then
        src_dir=$src_dir/
    fi

    # Ensure DEST does not have trailing /
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # bung internal convention
    if [[ ${dest_dir:-} =~ $trailing_slash_regex ]]; then
        dest_dir=${dest_dir%%*(/)}
    fi

    # Note any remote directories
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ${src_dir:-} =~ $remote_dir_regex ]] \
        && src_dir_remote_flag=$true \
        || src_dir_remote_flag=$false
    [[ ${dest_dir:-} =~ $remote_dir_regex ]] \
        && dest_dir_remote_flag=$true \
        || dest_dir_remote_flag=$false

    # Sub-keyword "options" dependent actions
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $rsync_options = '' ]]; then

        # Default any unconfigured config values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # This cannot be done in parse_conf_rsync as would follow the general
        # pattern because err_trap_rsync_conf assumes that any values come
        # from the configration file when checking for sub-keywords which cannot
        # validly be used when the "options" sub-keyword is used
        [[ ${backup_retention:-} = '' ]] \
            && backup_retention=28
        [[ ${rsync_backup_dir:-} = '' ]] \
            && rsync_backup_dir='_Changed and deleted files'
        [[ ${rsync_nocompression_flag:-} = '' ]] \
            && rsync_nocompression_flag=$false
        [[ ${rsync_no_numeric_ids_flag:-} = '' ]] \
            && rsync_no_numeric_ids_flag=$false
        [[ ${rsync_timeout:-} = '' ]] \
            && rsync_timeout=600
        [[ ${rsync_verbose_level:-} = '' ]] \
            && rsync_verbose_level=1

        # Set backup_retention_0_nowarn_flag
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $backup_retention != '0,nowarn' ]]; then
            backup_retention_0_nowarn_flag=$false
        else
            backup_retention=0
            backup_retention_0_nowarn_flag=$true
        fi
    fi

    fct "${FUNCNAME[0]}" returning
}  # End of function postprocess_rsync_conf
