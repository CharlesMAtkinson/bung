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
# Name: run_pre_hooks
# Purpose:
#   * Services the Pre-hook keyword.  Specifically:
#   * Runs the commands in array $pre_hook_cmd subject to a timeout
#   * Writes any output from the command to log or screen
#   * If the return code from the pre-hook command is:
#     0: generates an information message and continues
#     1: generates an information message and finalises
#     2: generates a warning and continues
#     3: generates a warning and finalises
#     4: generates an error (implies does not continue)
#
# Usage:
#   * Before calling this function:
#       * $out_fn and $rc_fn must contain paths of writeable files.
#         They are set by initialise_1.scrippet.
#         Any existing content in the files will be removed.
# Syntax:
#   run_pre_hooks
#
# Global variables read:
#   pre_hook_cmd
#   pre_hook_idx
#   false
#   msg_lf
#   out_fn
#   rc_fn
#   true
# Global variables set: none
# Output:
#   * stdout and stderr to log or screen, either directly or via msg function
# Return: always 0 (does not retturn on error)
#--------------------------
function run_pre_hooks {
    fct "${FUNCNAME[0]}" started
    local cmd i msg out rc
    local -r pre_hook_rc_e=4
    local -r pre_hook_rc_i_continue=0
    local -r pre_hook_rc_i_finalise=1
    local -r pre_hook_rc_w_continue=2
    local -r pre_hook_rc_w_finalise=3

    # Run the pre-hook commands
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=pre_hook_idx;i++))
    do
        msg I "Running pre-hook command ${pre_hook_cmd[i]}"
        cmd=(${pre_hook_cmd[i]})
        run_cmd_with_timeout -o '<5' -e '>=5' -t "$pre_hook_timeout" \
            -T "$pre_hook_timeout_msgclass" -v
        rc=$?
        out=$(<"$out_fn")
        case $rc in
            0|1)    # Did not time out
                rc=$(<"$rc_fn")
                msg='Output from pre-hook command:'
                msg+=$'\n==== start of output from pre-hook command ==='
                msg+=$'\n'"$out"
                msg+=$'\n==== end of output from pre-hook command ==='
                case $rc in
                    $pre_hook_rc_i_continue) 
                        msg I "$msg"
                        ;;
                    $pre_hook_rc_i_finalise) 
                        msg I "$msg"
                        msg I 'finalising at request of pre-hook command'
                        finalise 0
                        ;;
                    $pre_hook_rc_w_continue) 
                        msg W "$msg"
                        ;;
                    $pre_hook_rc_w_finalise) 
                        msg I "$msg"
                        msg W 'finalising at request of pre-hook command'
                        finalise 1
                        ;;
                    $pre_hook_rc_e) 
                        msg E "$msg"
                        ;;
                    *) 
                        msg="Programming error: unexpected return code $rc"
                        msg E "$msg from pre-hook command"
                esac
                ;;
            2)
                msg $pre_hook_timeout_msgclass 'pre-hook command timed out'
        esac
    done

    fct "${FUNCNAME[0]}" 'returning 0'
    return 0
}  #  end of function run_pre_hooks
# vim: filetype=bash:
