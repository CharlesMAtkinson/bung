# Copyright (C) 2020 Charles Atkinson
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
# Name: postprocess_templated_conf
# Purpose:
#     Processes templated values from the conf file
# Arguments: none
# Global variable usage:
#     identity_file may be adjusted
#     template_file may be adjusted
# Output: none
# Return value: always 0
#--------------------------
function postprocess_templated_conf {
    fct "${FUNCNAME[0]}" started
    local i
    local -r absolute_path_regex='^/'

    # dest_dir
    # ~~~~~~~~
    # Normalise
    if [[ ${dest_dir:-} != '' ]]; then
        dest_dir=${dest_dir//\/\//\/}    # Change any // to /
        dest_dir=${dest_dir%/}           # Remove any trailing /
    fi

    # git_root_dir
    # ~~~~~~~~~~~~
    # Normalise
    if [[ ${git_root_dir:-} != '' ]]; then
        git_root_dir=${git_root_dir//\/\//\/}    # Change any // to /
        git_root_dir=${git_root_dir%/}           # Remove any trailing /
    fi

    # identity_file 
    # ~~~~~~~~~~~~~
    # If relative make relative to ~/.ssh
    if [[ ${identity_fn:-} != '' ]]; then
        if [[ ! ${identity_fn:-} =~ $absolute_path_regex ]]; then
            identity_fn=~/.ssh/$identity_fn
        fi
        identity_fn=${identity_fn//\/\//\/}    # Change any // to /
    fi

    # template_file 
    # ~~~~~~~~~~~~~
    # If relative make relative to /etc/bung
    if [[ ${template_fn:-} != '' ]]; then
        if [[ ! ${template_fn:-} =~ $absolute_path_regex ]]; then
            template_fn=/etc/bung/$template_fn
        fi
        template_fn=${template_fn//\/\//\/}    # Change any // to /
    fi

    # tftp_root
    # ~~~~~~~~
    # Normalise
    if [[ ${tftp_root:-} != '' ]]; then
        tftp_root=${tftp_root//\/\//\/}    # Change any // to /
        tftp_root=${tftp_root%/}           # Remove any trailing /
    fi

    fct "${FUNCNAME[0]}" returning
}  # End of function postprocess_templated_conf
# vim: filetype=bash:
