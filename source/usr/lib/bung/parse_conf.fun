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

# Functions in this file:
#   * parse_conf: entry to parsing
#   * parse_conf_email_for_report: parse common keyword "Email for report"
#   * parse_conf_mount: parse common keyword "Mount"
#   * parse_conf_notification_plug_in: parse common keyword "Notification plug-in"
#   * parse_conf_post_hook: parse common keyword "Post-hook"
#   * parse_conf_pre_hook: parse common keyword "Pre-hook"
#   * parse_conf_snapshot: parse common keyword "Snapshot"
#   * parse_conf_subkey_value: utility function to parse a subkey value

# Programmer's notes
#   * Only common configuration file parsing functions are defined in this file
#   * In case configuration file parsing functions are used by a single
#     script, define them in that script
#   * In case configuration file parsing functions are used by a few
#     scripts, define them in a separate lib/parse_conf_*.fun file

#--------------------------
# Name: parse_conf
# Purpose: parses the configuration file
# Arguments:
#   $1 - pathname of file to parse
#   $2 - "mounts_only" if only Mount lines are to be processed.
# Global variable usage:
#   Read:
#       keyword_validation[]
#       true and false
#   Set:
#       emsg: creates and appends any error messages
#       wmsg: creates and appends any error messages
#       keyword_validation[]
# Output: none
# Return value:
#   0 when no error detected
#   1 when an error is detected
# Usage notes:
#   * Expects the configuration file to have lines with:
#       > Comments: lines beginning with zero or more whitespace characters
#         followed by #.  Discarded
#       > Empty lines: Comprising zero or more spaces and tabs.  Discarded
#       > <keyword> = <value>
#         Tabs and spaces surrounding the keyword and surrounding the value are
#         discarded.
#         Tabs and spaces within the keyword are discarded and the remaining
#         string is normalised to lower case.
#         Tabs and spaces within the value are retained.
#   * Generates an error when keywords are invalidly repeated
#   * Assumes caller has ensured the config file is readable
#   * Validates keywords, does not validate their values
#   * Requires shopt -s extglob
#   * Uses fd 3
#--------------------------
function parse_conf {
    fct "${FUNCNAME[0]}" "started with conf_fn: ${1:-}, mounts_only: ${2:-}"
    local buf line line_n keyword keyword_norm mounts_only_flag 
    local pc_emsg rc regex valid_keywords value
    local -A keyword_seen
    local -r no_data_regex='^[[:space:]]*($|#)'

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#==0)) || (($#>2)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 1 or 2"
        msg E "$msg (args: $*)"
    fi

    # Initialisation
    # ~~~~~~~~~~~~~~
    local -r conf_fn=$1
    [[ ! ${2:-} = mounts_only ]] && mounts_only_flag=$false || mounts_only_flag=$true
    pc_emsg=

    # Normalise the keyword validation array members, ensuring a simple
    # space-separated list with single spaces at beginning and end.
    # This allows callers to create the strings in a conveniently legible way.
    keyword_validation[name]=" $(echo ${keyword_validation[name]}) "
    keyword_validation[repeat_invalid]=" $(echo ${keyword_validation[repeat_invalid]}) "

    # Error traps
    # ~~~~~~~~~~~
    emsg=
    wmsg=
    if [[ -h /proc/$$/fd/3 ]]; then
        emsg+=$msg_lf"Programming error: ${FUNCNAME[0]} called with fd 3 already in use"
        return 1
    fi
    if [[ $(shopt -p extglob) != 'shopt -s extglob' ]]; then
        emsg+=$msg_lf"Programming error: ${FUNCNAME[0]} called with extglob not set"
        return 1
    fi
    buf=$(tail -1 "$conf_fn"; echo X)
    buf=${buf: -2}
    [[ $buf != $'\nX' ]] && msg E "Invalid configuration file, '$conf_fn' (does not end with a line end)"

    # For each line in the config file ...
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    line_n=0
    exec 3< "$conf_fn"                               # Set up for reading on fd 3
    while read -r -u 3 line                          # For each line of the config file
    do
        msg D "${FUNCNAME[0]}: line: $line"
        ((line_n++))
        [[ $line =~ $no_data_regex ]] && continue    # Skip comments and empty lines
        line=${line%%*([[:space:]])}                 # Strip any trailing spaces and tabs
        line=${line##*([[:space:]])}                 # Strip any leading spaces and tabs

        keyword=${line%%=*}                          # Strip first = and everything after
        keyword=${keyword%%*([[:space:]])}           # Strip any trailing spaces and tabs
        keyword_norm=${keyword//*([[:space:]])}      # Remove all whitespace
        keyword_norm=${keyword_norm,,}               # Convert to lower case
        keyword_norm=${keyword_norm//-/_}            # Convert any - to _
        [[ $mounts_only_flag && $keyword_norm != mount ]] && continue
        regex=" $keyword_norm "

        if [[ ! ${keyword_validation[name]} =~ $regex ]]; then
            pc_emsg+=$msg_lf"line $line_n: invalid keyword '$keyword'"
            continue
        fi
        value="${line#*=}"                           # Strip up to first =
        value="${value##*([[:space:]])}"             # Strip any leading spaces and tabs
        msg D "${FUNCNAME[0]}: keyword: $keyword, keyword_norm: $keyword_norm, value: $value"

        # Error trap invalidly repeated keywords
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ ${keyword_validation[repeat_invalid]} =~ $regex ]]; then
            if [[ ! ${keyword_seen[$keyword_norm]:-} ]]; then
                keyword_seen[$keyword_norm]=$true
            else
                pc_emsg+=$msg_lf"line $line_n: repeated keyword $keyword"
            fi
        fi

        # Assign the value to a variable or variables
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        # TODO: change all these to call a parse_conf_$keyword_norm function?
        case "$keyword_norm" in
            checkhotplugusage )
                parse_conf_checkhotplugusage "$keyword" "$value" "$line_n"
                ;;
            dg_gs1526e )
                parse_conf_DG_GS1526E "$keyword" "$value" "$line_n"
                ;;
            emailforreport )
                parse_conf_email_for_report "$keyword" "$value" "$line_n"
                ;;
            hotplugdevice )
                parse_conf_hotplugdevice "$keyword" "$value" "$line_n"
                ;;
            logretention )
                log_retention=$value
                ;;
            maxmemorysize )
                max_memory_size=$value
                ;;
            mount )
                parse_conf_mount "$keyword" "$value" "$line_n"
                ;;
            mysql )
                parse_conf_mysql "$keyword" "$value" "$line_n"
                ;;
            notificationplug_in )
                parse_conf_notification_plug_in "$keyword" "$value" "$line_n"
                ;;
            numberofopenfiles )
                n_open_files=$value
                ;;
            openldap )
                parse_conf_openldap "$keyword" "$value" "$line_n"
                ;;
            organisationname )
                org_name=$value
                ;;
            postgresql )
                parse_conf_postgresql "$keyword" "$value" "$line_n"
                ;;
            post_hook )
                parse_conf_post_hook "$keyword" "$value" "$line_n"
                ;;
            pre_hook )
                parse_conf_pre_hook "$keyword" "$value" "$line_n"
                ;;
            rsync )
                parse_conf_rsync "$keyword" "$value" "$line_n"
                ;;
            shutdown )
                shutdown=$value
                ;;
            snapshot )
                parse_conf_snapshot "$keyword" "$value" "$line_n"
                ;;
            subsidiaryscript )
                parse_conf_subsidiaryscript "$keyword" "$value" "$line_n"
                ;;
            sysinfo )
                parse_conf_sysinfo "$keyword" "$value" "$line_n"
                ;;
            templated )
                parse_conf_templated "$keyword" "$value" "$line_n"
                ;;
            * )
                pc_emsg+=$msg_lf"Programming error: ${FUNCNAME[0]}: case statement and \$2 do not agree. keyword_norm: $keyword_norm"
                ;;
        esac
    done
    exec 3<&- # free file descriptor 3

    # Messaging
    # ~~~~~~~~~
    if [[ $pc_emsg = '' ]]; then
        rc=0
    else
        rc=1
        emsg=$emsg$pc_emsg
    fi

    fct "${FUNCNAME[0]}" "returning with rc $rc"
    return $rc
}  # end of function parse_conf

#--------------------------
# Name: parse_conf_email_for_report
# Purpose:
#   Parses an "Email for report" line from the configuration file
# Arguments:
#   $1 - the "Email for report" keyword as read from the configuration file (not normalised)
#   $2 - the "Email for report" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       true and false
#   Set:
#       email_for_report_idx incremented
#       pc_emsg appended with any error message
#       unparsed_str
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_email_for_report {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf email no_log idx rc unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if [[ ${3:-} = '' ]]; then
        msg="Programmming error: ${FUNCNAME[0]} called with less than 3 arguments"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse the value
    # ~~~~~~~~~~~~~~~
    # The value format/syntax is:
    # Email for report = email_address [msg_level=I|W|E] [no_log]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    email=$parsed_word

    if [[ $email != '' ]]; then
        idx=$((++email_for_report_idx))
        email_for_report[idx]=$email
        email_for_report_msg_level[idx]=I
        email_for_report_no_log_flag[idx]=$false

        # Parse any subkeywords
        # ~~~~~~~~~~~~~~~~~~~~~
        local -A subkey_validation
        subkey_validation[name]='msg_level no_log'
        subkey_validation[value_required]='msg_level'
        subkey_validation[value_invalid]='no_log'
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done

        [[ ${parsed_word,,} = no_log ]] \
            && email_for_report_no_log_flag[idx]=$true
    else
        pc_emsg+=$msg_lf"Email for report value missing on line $line_n"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_email_for_report

#--------------------------
# Name: parse_conf_mount
# Purpose:
#   Parses a Mount line from the configuration file
#   Note: does not error trap sub-values except [hotplug=yes|no] (which are converted to $true or $false)
# Arguments:
#   $1 - the "Mount" keyword as read from the configuration file (not normalised)
#   $2 - the "Mount" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       true and false
#   Set:
#       mount_idx incremented
#       pc_emsg appended with any error message
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_mount {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf fs_spec fs_file

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#!=3)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 3"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse the value
    # ~~~~~~~~~~~~~~~
    # Mount = <fs_spec> <fs_file> [ignore_already_mounted]
    #     [ignore_files_under_fs_file] [no_fsck] [options=<options>]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    fs_spec=$parsed_word

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    fs_file=$parsed_word

    if [[ $fs_file != '' ]]; then
        mount_fs_file[++mount_idx]=$fs_file
        mount_fs_spec[mount_idx]=
        mount_fs_spec_conf[mount_idx]=$fs_spec
        mount_fsck[mount_idx]=$true
        mount_ignore_already_mounted[mount_idx]=$false
        mount_ignore_files_under_fs_file[mount_idx]=$false
        mount_o_option[mount_idx]=
        mount_snapshot_idx[mount_idx]=-1

        # Parse any subkeywords
        # ~~~~~~~~~~~~~~~~~~~~~
        local -A subkey_validation
        subkey_validation[name]='
            options
            ignore_already_mounted
            ignore_files_under_fs_file
            no_fsck
        '
        subkey_validation[value_required]='options'
        subkey_validation[value_invalid]='
            ignore_already_mounted
            ignore_files_under_fs_file
            no_fsck
        '
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done
    else
        [[ $fs_spec = '' ]] && msg_part='fs_spec' || msg_part='fs_file'
        pc_emsg+=$msg_lf"Mount $msg_part missing (line $line_n)"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_mount

#--------------------------
# Name: parse_conf_notification_plug_in
# Purpose:
#   Parses an "Notification plug-in report" line from the configuration file
# Arguments:
#   $1 - the "Notification plug-in report" keyword as read from the configuration file (not normalised)
#   $2 - the "Notification plug-in report" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       true and false
#   Set:
#       notification_plug_in_idx incremented
#       pc_emsg appended with any error message
#       unparsed_str
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_notification_plug_in {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf conffile executable no_log idx rc unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if [[ ${3:-} = '' ]]; then
        msg="Programmming error: ${FUNCNAME[0]} called with less than 3 arguments"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse the value
    # ~~~~~~~~~~~~~~~
    # The value format/syntax is:
    # Email for report = executable conffile [msg_level=I|W|E] [no_log]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    executable=$parsed_word
    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    conffile=$parsed_word

    if [[ $conffile != '' ]]; then
        idx=$((++notification_plug_in_idx))
        notification_plug_in_executable[idx]=$executable
        notification_plug_in_conffile[idx]=$conffile
        notification_plug_in_conf_err_flag[idx]=$false
        notification_plug_in_msg_level[idx]=I
        notification_plug_in_no_log_flag[idx]=$false
        notification_plug_in_user[idx]=bung

        # Parse any subkeywords
        # ~~~~~~~~~~~~~~~~~~~~~
        local -A subkey_validation
        subkey_validation[name]=' msg_level no_log user '
        subkey_validation[value_required]=' msg_level user '
        subkey_validation[value_invalid]=' no_log '
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
            parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done

        [[ ${parsed_word,,} = no_log ]] \
            && notification_plug_in__nolog_flag[idx]=$true
    else
        pc_emsg+=$msg_lf"Notification plug-in keyword value(s) missing on line $line_n"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_notification_plug_in

#--------------------------
# Name: parse_conf_post_hook
# Purpose:
#   Parses a Post-hook line from the configuration file
#   Note: does not error trap sub-values
# Arguments:
#   $1 - the "Post-hook" keyword as read from the configuration file (not normalised)
#   $2 - the "Post-hook" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       line_n
#       true and false
#   Set:
#       pc_emsg appended with any error message
#       unparsed_str
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_post_hook {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if [[ ${3:-} = '' ]]; then
        msg="Programmming error: ${FUNCNAME[0]} called with less than 3 arguments"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value
    ((++post_hook_idx))

    # Parse any subkeywords
    # ~~~~~~~~~~~~~~~~~~~~~
    # Post-hook = [run=normal|always] [timeout=<duration>] [timeout_msgclass=<msgclass>]
    #    <command and any args>
    post_hook_run[post_hook_idx]=normal
    post_hook_timeout[post_hook_idx]=10
    post_hook_timeout_msgclass[post_hook_idx]=E
    local -A subkey_validation
    subkey_validation[name]='run timeout timeout_msgclass'
    subkey_validation[value_required]='timeout timeout_msgclass run'
    subkey_validation[value_invalid]=
    local +r subkey_validation
    local -r data_after_subkeys_OK=$true
    local done=$false
    while [[ ! $done ]]
    do
       parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
    done

    # Parse the value (command and any args)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ $unparsed_str = '' ]] \
        && pc_emsg+=$msg_lf"line $line_n: a command is required"
    post_hook_cmd[post_hook_idx]=$unparsed_str

    if [[ $pc_emsg = $initial_pc_emsg ]]; then
        my_rc=0
    else
        my_rc=1
        ((--post_hook_idx))
    fi
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_post_hook

#--------------------------
# Name: parse_conf_pre_hook
# Purpose:
#   Parses a Pre-hook line from the configuration file
#   Note: does not error trap sub-values
# Arguments:
#   $1 - the "Pre-hook" keyword as read from the configuration file (not normalised)
#   $2 - the "Pre-hook" value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       line_n
#       true and false
#   Set:
#       pc_emsg appended with any error message
#       unparsed_str
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_pre_hook {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf msg

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value
    ((++pre_hook_idx))

    # Parse any subkeywords
    # ~~~~~~~~~~~~~~~~~~~~~
    # The line syntax is:
    # Pre-hook = [timeout=<duration>] [timeout_msgclass=<msgclass>]
    #    <command and any args>
    pre_hook_timeout[pre_hook_idx]=10
    pre_hook_timeout_msgclass[pre_hook_idx]=E
    local -A subkey_validation
    subkey_validation[name]='timeout timeout_msgclass'
    subkey_validation[value_required]='timeout timeout_msgclass'
    subkey_validation[value_invalid]=
    local +r subkey_validation
    local -r data_after_subkeys_OK=$true
    local done=$false
    while [[ ! $done ]]
    do
       parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
    done

    # Parse the value (command and any args)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ $unparsed_str = '' ]] \
        && pc_emsg+=$msg_lf"line $line_n: a command is required"
    pre_hook_cmd[pre_hook_idx]=$unparsed_str

    if [[ $pc_emsg = $initial_pc_emsg ]]; then
        my_rc=0
    else
        my_rc=1
        ((--pre_hook_idx))
    fi
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_pre_hook

#--------------------------
# Name: parse_conf_snapshot
# Purpose:
#   Parses a Snapshot line from the configuration file
#   Note: does not error trap sub-values
# Arguments:
#   $1 - the keyword as read from the configuration file (not normalised)
#   $2 - the value from the configuration file
#   $3 - the configuration file line number
# Global variable usage:
#   Read:
#       true and false
#   Set:
#       snapshot_idx incremented
#       pc_emsg appended with any error message
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_snapshot {
    fct "${FUNCNAME[0]}" "started with keyword: ${1:-}, value: ${2:-}, line_n: ${3:-}"
    local buf my_rc org_vol snap_vol fs_file unparsed_str

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#!=3)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 3"
        msg E "$msg (args: $*)"
    fi
    local -r keyword=$1
    local -r value=$2
    local -r line_n=$3

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    unparsed_str=$value

    # Parse the value
    # ~~~~~~~~~~~~~~~
    #    Snapshot = <original volume name> <snapshot volume name>
    #    <fs_file> [ignore_files_under_fs_file] [size=<size>]

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    org_vol=$parsed_word

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    snap_vol=$parsed_word

    parse_conf_word $line_n
    if (($?!=0)); then
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    fs_file=$parsed_word

    if [[ $fs_file != '' ]]; then

        # Assign the positional values
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        ((++snapshot_idx)); ((++mount_idx))
        snapshot_org_vol[snapshot_idx]=$org_vol
        snapshot_vol[snapshot_idx]=$snap_vol
        mount_fs_file[mount_idx]=$fs_file

        # Set the cross-reference indices
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        mount_snapshot_idx[mount_idx]=$snapshot_idx
        snapshot_mount_idx[snapshot_idx]=$mount_idx

        # Set default values
        # ~~~~~~~~~~~~~~~~~~
        mount_fsck[mount_idx]=$true
        mount_ignore_already_mounted[mount_idx]=$false
        mount_ignore_files_under_fs_file[mount_idx]=$false
        mount_notification_email[mount_idx]=
        mount_o_option[mount_idx]=

        # Set signal values
        # ~~~~~~~~~~~~~~~~~
        # These signal that no value has been configured
        snapshot_size[snapshot_idx]=

        # Parse any subkeywords
        # ~~~~~~~~~~~~~~~~~~~~~
        local -A subkey_validation
        subkey_validation[name]='
            ignore_files_under_fs_file
            size
        '
        subkey_validation[value_required]='size'
        subkey_validation[value_invalid]='ignore_files_under_fs_file'
        local +r subkey_validation
        while [[ $unparsed_str != '' ]]
        do
           parse_conf_subkey_value "${FUNCNAME[0]}" $line_n
        done
    else
        ((mount_idx--))
        pc_emsg+=$msg_lf"fs_file (mountpoint) missing (line $line_n)"
    fi

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function parse_conf_snapshot

#--------------------------
# Name: parse_conf_subkey_value
# Purpose:
#   Parses a sub-keyword value
# Arguments:
#   $1 - the calling function
#   $2 - configuration file line number
# Global variable usage:
#   Read:
#       subkey_validation[]
#       true and false
#       unparsed_str
#   Set:
#       unparsed_str
#       pc_emsg appended with any error message
# Output: none except via function fct
# Return value:
#   0 when no error detected
#   1 when an error is detected
#--------------------------
function parse_conf_subkey_value {
    fct "${FUNCNAME[0]}" "started with caller: ${1:-}, line_n: ${2:-}"
    local buf caller idx initial_pc_emsg line_n my_rc regex
    local regex subkey subkey_norm subkey_val

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    if (($#!=2)); then
        msg="Programmming error: ${FUNCNAME[0]} called with $# arguments instead of 2"
        msg E "$msg (args: $*)"
    fi
    local -r caller=$1
    local -r line_n=$2

    # Initialise
    # ~~~~~~~~~~
    local -r initial_pc_emsg=$pc_emsg
    local -r initial_unparsed_str=$unparsed_str

    # Normalise the sub-keyword validation array members, ensuring a simple
    # space-separated list with single spaces at beginning and end.
    # This allows callers to create the strings in a conveniently legible way.
    subkey_validation[name]=" $(echo ${subkey_validation[name]}) "
    subkey_validation[value_invalid]=" $(echo ${subkey_validation[value_invalid]}) "
    subkey_validation[value_required]=" $(echo ${subkey_validation[value_required]}) "

    # Get the sub-keyword
    # ~~~~~~~~~~~~~~~~~~~
    # Terminated by =, whitespace or no more string to parse
    subkey=${unparsed_str%%[=[:space:]]*}
    unparsed_str=${unparsed_str#$subkey}            # Discard used characters
    subkey_norm=${subkey,,}                         # Normalise to lower case
    unparsed_str=${unparsed_str##*([[:space:]])}    # Discard any leading spaces and tabs

    # Is there a sub-keyword value?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ${unparsed_str:0:1} = = ]]; then
        unparsed_str=${unparsed_str#=}                  # Discard the =
        parse_conf_word $line_n
        subkey_val=$parsed_word
    else
        subkey_val=
    fi
    msg D "subkey:$subkey, subkey_val: $subkey_val"

    # Validate
    # ~~~~~~~~
    # TODO: introduce repeated subkeyword control?  Currently any subkeywords
    # can be repeated (man pages).  Classification and detection could follow
    # the keyword model except the subkeyword seen array would have to be
    # local to caller.
    regex=" $subkey_norm "
    if [[ ! "${subkey_validation[name]}" =~ $regex ]]; then
        if [[ ${data_after_subkeys_OK:-$false} ]]; then
            unparsed_str=$initial_unparsed_str
            done=$true
            fct "${FUNCNAME[0]}" "returning with rc 0. unparsed_str: '$unparsed_str'"
            return 0
        else
            pc_emsg+=$msg_lf"line $line_n: invalid subkeyword '$subkey'"
            fct "${FUNCNAME[0]}" "returning with rc 1. unparsed_str: '$unparsed_str'"
            return 1
        fi
    fi
    if [[ ${subkey_validation[value_invalid]} =~ $regex \
        && $subkey_val != '' \
    ]]; then
        pc_emsg+=$msg_lf"line $line_n: invalid $subkey value '$subkey_val' (no value required)"
        fct "${FUNCNAME[0]}" "returning with rc 1. unparsed_str: '$unparsed_str'"
        return 1
    fi
    if [[ ${subkey_validation[value_required]} =~ $regex \
        && $subkey_val = '' \
    ]]; then
        pc_emsg+=$msg_lf"line $line_n: $subkey requires a value"
        fct "${FUNCNAME[0]}" "returning with rc 1. unparsed_str: '$unparsed_str'"
        return 1
    fi

    # Set caller-dependent array index
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Cannot do this for parse_conf_snapshot because it uses both snapshot_idx
    # and mount_idx
    # TODO: same for email_for_report_idx and subsidiaryscript_idx?
    case $caller in
        parse_conf_mount )
            idx=$mount_idx
            ;;
        parse_conf_notification_plug_in )
            idx=$notification_plug_in_idx
            ;;
        parse_conf_post_hook )
            idx=$post_hook_idx
            ;;
        parse_conf_pre_hook )
            idx=$pre_hook_idx
    esac

    # Assign sub-keyword value to a variable
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    case "$subkey_norm" in
        --bwlimit )
            rsync_bwlimit=$subkey_val
            ;;
        --exclude-from )
            rsync_exclude_fn=$subkey_val
            ;;
        --timeout )
            rsync_timeout=$subkey_val
            ;;
        backup_dir )
            rsync_backup_dir=$subkey_val
            ;;
        compression )
            compression=$subkey_val
            ;;
        debug )
            subsidiaryscript_debug[subsidiaryscript_idx]=$true
            ;;
        defaults_file )
            defaults_fn=$subkey_val
            ;;
        dest_dir )
            dest_dir=$subkey_val
            ;;
        dest_dir_usage_warning )
            dest_dir_usage_warning=$subkey_val
            ;;
        dest_dir_windows )
            dest_dir_windows_flag=$true
            ;;
        device_type )
            device_type=$subkey_val
            ;;
        email )
            ck_hotplug_usage_email+=,$subkey_val
            ;;
        email_wait )
            hotplug_dev_note_email_wait=$subkey_val
            ;;
        exclude )
            exclude=$subkey_val
            ;;
        git_root )
            git_root_dir=$subkey_val
            ;;
        hostname )
            hostname=$subkey_val
            ;;
        identity_file )
            identity_fn=$subkey_val
            ;;
        ignore_already_mounted )
            mount_ignore_already_mounted[mount_idx]=$true
            ;;
        ignore_files_under_fs_file )
            mount_ignore_files_under_fs_file[mount_idx]=$true
            ;;
        ionice )
            subsidiaryscript_ionice[subsidiaryscript_idx]=$subkey_val
            ;;
        maxbackupage )
            ck_hotplug_usage_max_backup_age=$subkey_val
            ;;
        maxdevicechangedays )
            ck_hotplug_usage_max_device_change_days=$subkey_val
            ;;
        msg_level )
            [[ $caller = parse_conf_email_for_report ]] && email_for_report_msg_level[idx]=$subkey_val
            [[ $caller = parse_conf_notification_plug_in ]] && notification_plug_in_msg_level[idx]=$subkey_val
            ;;
        missing_device_message_class )
            hotplug_dev_missing_msgclass=$subkey_val
            ;;
        nice )
            subsidiaryscript_nice[subsidiaryscript_idx]=$subkey_val
            ;;
        no_fsck )
            mount_fsck[idx]=$false
            ;;
        no_log )
            [[ $caller = parse_conf_email_for_report ]] && email_for_report_no_log_flag[idx]=$true
            [[ $caller = parse_conf_notification_plug_in ]] && notification_plug_in_no_log_flag[idx]=$true
            ;;
        nocompression )
            rsync_nocompression_flag=$true
            ;;
        no-numeric-ids )
            rsync_no_numeric_ids_flag=$true
            ;;
        notification_email )
            hotplug_dev_note_email=$subkey_val
            ;;
        notification_screen )
            hotplug_dev_note_screen_flag=$true
            ;;
        options )
            [[ $caller = parse_conf_mount ]] && mount_o_option[idx]=$subkey_val
            [[ $caller = parse_conf_rsync ]] && rsync_options=$subkey_val
            ;;
        organisation )
            ck_hotplug_usage_org=$subkey_val
            ;;
        password )
            password=$subkey_val
            ;;
        remote_host_log_dir )
            remote_host_log_dir=$subkey_val
            ;;
        remote_host_pid_dir )
            remote_host_pid_dir=$subkey_val
            ;;
        remote_host_timeout )
            remote_host_timeout=$subkey_val
            ;;
        retention )
            retention=$subkey_val
            ;;
        retry )
            retry_max=$subkey_val
            ;;
        run )
            case $caller in
                parse_conf_post_hook ) post_hook_run=$subkey_val ;;
                * ) msg E "Programming error: ${FUNCNAME[0]}: $LINENO: unsupported caller $caller" ;;
            esac
            ;;
        schedule )
            subsidiaryscript_schedule[subsidiaryscript_idx]=$subkey_val
            ;;
        size )
            snapshot_size[snapshot_idx]=$subkey_val
            ;;
        template )
            template_fn=$subkey_val
            ;;
        tftp_root )
            tftp_root=$subkey_val
            ;;
        tftp_server )
            tftp_server=$subkey_val
            ;;
        timeout )
            case $caller in
                parse_conf_post_hook ) post_hook_timeout[idx]=$subkey_val ;;
                parse_conf_pre_hook ) pre_hook_timeout[idx]=$subkey_val ;;
                parse_conf_templated ) templated_timeout=$subkey_val ;;
                * ) msg E "Programming error: ${FUNCNAME[0]}: $LINENO: unsupported caller $caller" ;;
            esac
            ;;
        timeout_msgclass )
            case $caller in
                parse_conf_post_hook ) post_hook_timeout_msgclass[idx]=$subkey_val ;;
                parse_conf_pre_hook ) pre_hook_timeout_msgclass[idx]=$subkey_val ;;
                * ) msg E "Programming error: ${FUNCNAME[0]}: $LINENO: unsupported caller $caller" ;;
            esac
            ;;
        timestamp_format )
            timestamp_format=$subkey_val
            ;;
        user )
            notification_plug_in_user[idx]=$subkey_val
            ;;
        username )
            username=$subkey_val
            ;;
        verbose )
            rsync_verbose_level=$subkey_val
            ;;
        * )
            pc_emsg+=$msg_lf"Programming error: ${FUNCNAME[0]}: case statement and \$2 do not agree. subkey_norm: $subkey_norm"
            ;;
    esac

    [[ $pc_emsg = $initial_pc_emsg ]] && my_rc=0 || my_rc=1
    fct "${FUNCNAME[0]}" "returning with rc $my_rc. unparsed_str: '$unparsed_str', subkey: ${subkey:-}, subkey_val: ${subkey_val:-}"
    return $my_rc
}  # end of function parse_conf_subkey_value
# vim: filetype=bash:
