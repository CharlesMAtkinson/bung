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
# Name: remove_old_backups
# Purpose: removes old backup files accordig to the policy set by the retention sub-keyword
# Syntax
#   remove_old_backups -m <dir_or_tree> -n <name_pattern> -s <starting_point> 
#   Where
#      -m is mode.  Must be tree or dir
#       When dir, old backup files are removed only from the <starting_point> directory
#       When tree
#           Old backup files are removed from the <starting_point> tree
#           After removing old backup files, empty directories in the tree are removed
#      -n is as for find's -name test
#      -s is as for for find's starting_point except only one can be used 
# Global variables read: msg_lf
# Global variables set: none
# Returns: always 0.  Does not return when there is an error
#--------------------------
function remove_old_backups {
    fct "${FUNCNAME[0]}" "started with arguments $*"
    local OPTIND    # Required when getopts is called in a function
    local args opt opt_m_flag opt_n_flag opt_s_flag
    local buf cmd rc
    local array candidate_files emsg fn i n_files_to_keep oIFS target_percent usage
    local -r dir_or_tree_re='^(dir|tree)$'
    local -r retention_days_re='[[:digit:]](days)?$'
    local -r retention_days_0_re='0(days)?$'
    local -r retention_old_backups_re='old_backups$'
    local -r retention_percent_usage_re='percent_usage(,[[:digit:]]+min_old_backups)?$'
    local -r use_percent_re='^[[:digit:]]+%$'

    # Parse options
    # ~~~~~~~~~~~~~
    args=("$@")
    emsg=
    opt_m_flag=$false
    opt_n_flag=$false
    opt_s_flag=$false
    while getopts :m:n:s: opt "$@"
    do
        case $opt in
            m )
                opt_m_flag=$true
                dir_or_tree=$OPTARG
                ;;
            n )
                opt_n_flag=$true
                name_pat=$OPTARG
                ;;
            s )
                opt_s_flag=$true
                starting_point=$OPTARG
                ;;
            : )
                emsg+=$msg_lf"Option $OPTARG must have an argument"
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done
    shift $(($OPTIND-1))

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive options

    # Test for mandatory options not set
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_m_flag ]] && emsg+=$msg_lf'-m option is required'
    [[ ! $opt_n_flag ]] && emsg+=$msg_lf'-n option is required'
    [[ ! $opt_s_flag ]] && emsg+=$msg_lf'-s option is required'

    # Test remaining arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    (($#>0)) && emsg+=$msg_lf"Invalid non-option arguments: $*"

    # Validate option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $dir_or_tree =~ $dir_or_tree_re ]] && emsg+=$msg_lf"Invalid -m value $dir_or_tree"

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        # These are programming error(s) so use error, not warning
        msg E "Programming error. ${FUNCNAME[0]} called with ${args[*]}$emsg"
    fi

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if [[ ! -d "$starting_point" ]]; then
        msg I "Directory $starting_point does not exist so no old backups to remove"
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi
    if [[ $retention =~ $retention_days_0_re ]]; then
        msg I "Retention is $retention (0 days) so not removing old backup files"
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi

    # Remove old files
    # ~~~~~~~~~~~~~~~~
    [[ ! $starting_point =~ $absolute_path_re ]] && starting_point=$(realpath "$starting_point")
    msg I "Removing old files under '$starting_point' for retention $retention"
    if [[ $retention =~ $retention_percent_usage_re || $retention =~ $retention_old_backups_re ]]; then
        msg D "Getting candidate files' mtimes and paths"
        cmd=(find "$starting_point/")
        [[ $dir_or_tree = dir ]] && cmd+=(-maxdepth 1)
        cmd+=(-name "$name_pat" -type f -printf "%T+\t%p\n")
        msg D "cmd: ${cmd[*]}"
        oIFS=$IFS
        IFS=$'\n'
        candidate_files=($("${cmd[@]}" | sort )) 
        IFS=$oIFS
        if [[ $debugging_flag ]]; then
            for ((i=0;i<${#candidate_files[*]};i++))
            do
                msg D "\${candidate_files[$i]}: ${candidate_files[i]}"
            done
        fi
    fi
    if [[ $retention =~ $retention_percent_usage_re ]]; then
        # Syntax: <number>percent_usage[,<number>min_old_backups]
        buf=${retention%min_old_backups}
        if [[ $buf = $retention ]]; then
            n_files_to_keep=0
        else
            n_files_to_keep=${buf#*,}
        fi
        buf=${retention%,*}
        target_percent=${buf%percent_usage}
        usage=
        for ((i=0;i<${#candidate_files[*]}-n_files_to_keep;i++))
        do
            cmd=(df "$starting_point")
            buf=$("${cmd[@]}" 2>&1)
            case $buf in
                Filesystem* )
                    ;;
                * )
                    msg E "Unexpected output from '${cmd[*]}': $buf"
                    ;;
            esac
            array=($buf)
            if [[ ${array[11]} =~ $use_percent_re ]]; then
                usage=${array[11]//%}
                msg I "Usage is $usage%"
                ((usage<=target_percent)) && break
            else
                msg E "Unexpected output from '${cmd[*]}' (12th word does not match '$use_percent_re'): $buf"
            fi
            fn=${candidate_files[i]#*$'\t'}
            msg I "Removing $fn"
            cmd=(rm "$fn")
            buf=$("${cmd[@]}" 2>&1)
            if [[ $buf != '' ]]; then
                msg W "Unexpected output from '${cmd[*]}': $buf"
            fi
        done
        if [[ $usage != '' ]]; then
            (((n_files_to_keep>0)&&(usage>target_percent))) && msg I "Stopped removing old files to keep $n_files_to_keep"
        else
            msg="No old files removed because there were only"
            msg I "$msg ${#candidate_files[*]} old files (<= $n_files_to_keep)"
        fi
    elif [[ $retention =~ $retention_old_backups_re ]]; then
        n_files_to_keep=${retention%old_backups}
        msg I "Currently ${#candidate_files[*]} backup files"
        for ((i=0;i<${#candidate_files[*]}-n_files_to_keep;i++))
        do
            fn=${candidate_files[i]#*$'\t'}
            msg I "Removing $fn"
            cmd=(rm "$fn")
            buf=$("${cmd[@]}" 2>&1)
            if [[ $buf != '' ]]; then
                msg W "Unexpected output from '${cmd[*]}': $buf"
            fi
        done
    else
        cmd=(find "$starting_point/")
        [[ $dir_or_tree = dir ]] && cmd+=(-maxdepth 1)
        cmd+=(-mtime +$((${retention%days}-1)) -name "$name_pat" -type f -execdir rm {} +)
        msg D "cmd: ${cmd[*]}"
        buf=$("${cmd[@]}" 2>&1)
        if [[ $buf != '' ]]; then
            msg W "Unexpected output from '${cmd[*]}': $buf"
        fi
    fi

    # Remove empty directories
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $dir_or_tree = tree ]]; then
        msg I "Removing empty directories under '$starting_point'"
        cmd=(find "$starting_point/" -depth -mindepth 1 -type d -empty -delete)
        msg D "cmd: ${cmd[*]}"
        buf=$("${cmd[@]}" 2>&1)
        if [[ $buf != '' ]]; then
            msg W "Unexpected output from '${cmd[*]}': $buf"
        fi
    fi

    fct "${FUNCNAME[0]}" 'returning 0'
    return 0
}  #  end of function remove_old_backups
# vim: filetype=bash:
