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

source "$BUNG_LIB_DIR/my_cat.fun" || exit 1

#--------------------------
# Name: my_mailx
# Purpose: front end to the mailx command
# Syntax
#   my_mailx -a <email_address_list> -b <body> [-l <log_fn>] -s <subject>
#   Where
#       <email_address_list> is a comma-separated list of email addresses without friendly names
#       <body> is a text string to be used as the body of the mail
#       <log_fn> is the path of the log file to append to the body of the mail
# Global variables read: false, msg_lf, true
# Global variables set: mail_sent_flag
# Returns: always 0.  Does not return when there is an error
#--------------------------
function my_mailx {
    fct "${FUNCNAME[0]}" "started with arguments $*"
    local OPTIND    # Required when getopts is called in a function
    local args emsg opt opt_a_flag opt_b_flag opt_l_flag opt_s_flag
    local buf cmd rc
    local body body_fn email_address_list subject

    # Parse options
    # ~~~~~~~~~~~~~
    args=("$@")
    emsg=
    opt_a_flag=$false
    opt_b_flag=$false
    opt_l_flag=$false
    opt_s_flag=$false
    while getopts :a:b:l:s: opt "$@"
    do
        case $opt in
            a )
                opt_a_flag=$true
                email_address_list=$OPTARG
                ;;
            b )
                opt_b_flag=$true
                body=$OPTARG
                ;;
            l )
                opt_l_flag=$true
                body_fn=$OPTARG
                ;;
            s )
                opt_s_flag=$true
                subject=$OPTARG
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

    # Test for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! $opt_a_flag ]] && emsg+=$msg_lf'-a option is required'
    [[ ! $opt_b_flag ]] && emsg+=$msg_lf'-l option is required'
    [[ ! $opt_s_flag ]] && emsg+=$msg_lf'-s option is required'

    # Test remaining arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    (($#>0)) && emsg+=$msg_lf"Invalid non-option arguments: $*"

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        # These are programming error(s) so use error, not warning
        msg E "Programming error. ${FUNCNAME[0]} called with ${args[*]}$emsg"
    fi

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ! hash mailx 2>/dev/null; then
        msg I 'mailx command not available.  Not sending email'
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi
    if [[ $email_address_list = none ]]; then
        msg I 'Email address is 'none'.  Not sending email'
        fct "${FUNCNAME[0]}" 'returning 0'
        return 0
    fi

    # Validate option arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    # Now because the other option errors are programming errors
    if [[ $opt_l_flag ]];  then
        buf=$(ck_file "$log_fn" f:r 2>&1)
        if [[ $buf != '' ]]; then
            msg W "$buf"
            fct "${FUNCNAME[0]}" 'returning 1'
            return 1
        fi
    fi

    # Send email
    # ~~~~~~~~~~
    if [[ $opt_l_flag ]]; then
        body+=$'\n\n'$(my_cat "$log_fn")
    fi
    msg I "Sending '$subject' mail to $email_address_list"
    buf=$(echo "$body" \
        | iconv --from-code utf-8 --to-code ascii//translit \
        | fold -w 999 \
        | MAILRC=/dev/null mailx -n -s "$subject" "$email_address_list")
    if [[ $buf != '' ]]; then
        msg W "sending mail: $buf"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    mail_sent_flag=$true
    
    fct "${FUNCNAME[0]}" 'returning 0'
    return 0
}  #  end of function my_mailx
# vim: filetype=bash:
