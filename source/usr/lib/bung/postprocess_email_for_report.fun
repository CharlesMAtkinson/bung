# Copyright (C) 2021 Charles Atkinson
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
# Name: postprocess_email_for_report
# Purpose:
#     Processes any email addresses for reports from the conf file
# Arguments: none
# Global variable usage:
#   Write
#       email_for_report[0]
#       email_for_report_no_log_flag[0]
#       email_for_report_msg_level[0]
# Output: none
# Return value: always 0; does not return on error
#--------------------------
function postprocess_email_for_report {

    # Set default if no email address configured
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if ((email_for_report_idx==-1)); then
        email_for_report[++email_for_report_idx]=root
        email_for_report_no_log_flag[email_for_report_idx]=$false
        email_for_report_msg_level[email_for_report_idx]=I
    fi

    return 0
}  # End of function postprocess_email_for_report
# vim: filetype=bash:
