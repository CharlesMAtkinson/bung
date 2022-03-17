# Copyright (C) 2018 Charles Atkinson
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

# Programmers' notes: function call tree
#
#    +-- msg_on_screen
#        |
#        +-- get_x_authority_or_user
#        |
#        +-- x_msg_yad
#        |
#        +-- x_msg_zenity

#--------------------------
# Purpose:
#   Gets the name of the X authority file or of the current X display user
# Arguments:
#   $1 current virtual termial, e.g. tty7
# Global variable usage:
#   Set conditionally:
#       x_authority_fn
#       user_to_run_x_msg
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function get_x_authority_or_user {
    fct "${FUNCNAME[0]}" "started. current_vt: $1"
    local array buf regex

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r current_vt=$1

    # Get the X display ID
    # ~~~~~~~~~~~~~~~~~~~~
    # * ps command may produce several lines of output
    # * Desired line starts with /usr/bin/X or /usr/lib/xorg/Xorg and includes -auth
    # * Desired line example:
    #     /usr/lib/xorg/Xorg :0 -seat seat0 -auth /var/run/lightdm/root/:0 -nolisten tcp vt7 -novtswitch
    # * Get second word (here :0) from the line
    regex='^/usr.*/(X|Xorg) .* -auth '
    buf=$(ps --format cmd --no-headers --tty "$current_vt" \
        | grep -E "$regex" \
    )
    array=($buf)
    display=${array[1]:-}
    regex='^[[:digit:]]*:[[:digit:]]+$'
    if [[ ! $display =~ $regex ]]; then
        msg W "Programming error: ${FUNCNAME[0]}: \$display ($display) does not match \$regex ($regex)"
        msg I 'Setting display to :0'
        display=:0    # Reasonable default guess
    fi

    # Thanks to the creators of VirtualGL/Bumblebee for the techniques :-)
    # https://github.com/Bumblebee-Project/bumblebee-gentoo/blob/master/x11-misc/virtualgl/files/vgl.confd
    # https://github.com/Bumblebee-Project/bumblebee-gentoo/blob/master/x11-misc/virtualgl/files/vgl.initd

    # Common case
    # ~~~~~~~~~~~
    # The most general match, taken from VirtualGL/Bumblebee code
    # Here is a sample from the wild of what the regex was designed for:
    # /usr/bin/X :0 -auth /var/lib/xdm/authdir/authfiles/A:0-5XTp2J
    buf=$(ps --format cmd --no-headers --tty $current_vt \
        | grep --only-matching '\B[-]auth\s*/var\S*auth\S*' \
    )
    x_authority_fn=${buf##* }
    if [[ -f $x_authority_fn ]]; then
        fct "${FUNCNAME[0]}" "returning (common case, x_authority_fn:$x_authority_fn)"
        return 0
    fi

    # lightdm
    # ~~~~~~~
    x_authority_fn=/var/run/lightdm/root/$display
    if [[ -f $x_authority_fn ]]; then

        # Has a user logged on?
        # ~~~~~~~~~~~~~~~~~~~~~
        regex="^[^ ]+ +($current_vt|$display) +"
        buf=$(w -h -s | grep -E "$regex" 2>&1)
        if [[ $buf = '' ]]; then    # No so use lightdm's authoity file
            fct "${FUNCNAME[0]}" "returning (lightdm showing login screen. x_authority_fn:$x_authority_fn)"
            return 0
        elif [[ $buf =~ $regex ]]; then    # Yes so get their name
            user_to_run_x_msg=${buf%% *}
            fct "${FUNCNAME[0]}" "returning (lightdm with $user_to_run_x_msg logged in)"
            return 0
        else
            msg W "Unable to determine X authority file for lightdm, buf:$buf"
            fct "${FUNCNAME[0]}" 'returning 1'
            return 1
        fi
    fi

    # kdm and some others
    # ~~~~~~~~~~~~~~~~~~~
    x_authority_fn=$(find /var/run/xauth/A${display}-* | tail --lines=1)
    if [[ -f $x_authority_fn ]]; then
        fct "${FUNCNAME[0]}" "returning (kdm or similar.  x_authority_fn:$x_authority_fn)"
        return 0
    fi

    # gdm
    # ~~~
    x_authority_fn=/var/gdm/$display.Xauth
    if [[ -f $x_authority_fn ]]; then
        fct "${FUNCNAME[0]}" "returning (gdm.  x_authority_fn:$x_authority_fn)"
        return 0
    fi

    # slim
    # ~~~~
    x_authority_fn=/var/run/slim.auth
    if [[ -f $x_authority_fn ]]; then
        fct "${FUNCNAME[0]}" "returning (slim.  x_authority_fn:$x_authority_fn)"
        return 0
    fi

    msg W 'Did not find the X authority file or logged in user; will not display messages on the X display'

    fct "${FUNCNAME[0]}" 'returning 1'
    return 1
}  # end of function get_x_authority_or_user

#--------------------------
# Name: msg_on_screen
# Purpose:
#   Messages on the local screen
# Arguments:
#   $1 dialog type: info, error or warning
#   $2 msg_first_line
#   $3 msg_extra_lines (may be empty)
#   $4 x_msg_pid control. Optional; "yes" to record the PID of the message process
# Global variables:
#   Read: none
#   Set: none
# Return code: always 0
#--------------------------
function msg_on_screen {
    fct "${FUNCNAME[0]}" 'started'
    local buf current_vt current_vt_cmd current_vt_pid current_vt_user
    local text x_msg_pid_flag x_msg_util

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r dialog_type=$1
    local -r msg_first_line=$2
    local -r msg_extra_lines=$3
    case ${4:-} in
        'x_msg_pid=yes' )
            x_msg_pid_flag=$true
            ;;
        '' )
            x_msg_pid_flag=$false
            ;;
        * )
            msg W "Programming error: ${FUNCNAME[0]}: \$3 has unexpected value"
            x_msg_pid_flag=$false
    esac

    # Combine lines
    # ~~~~~~~~~~~~~
    text=$msg_first_line
    [[ $msg_extra_lines != '' ]] && text+=$'\n\n'$msg_extra_lines

    # Which virtual terminal is being displayed?
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(fgconsole 2>&1)
    if (($?!=0)); then
        msg W "Unable to determine which virtual terminal is being displayed: $buf"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    current_vt=tty$buf
    msg D "Current virtual terminal: $current_vt"

    # What is being displayed?
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(ps --format pid,ucmd --no-headers --tty $current_vt 2>&1)
    if (($?!=0)); then
        msg W "Unable to find which command is running on the virtual terminal which is being displayed: $buf"
        fct "${FUNCNAME[0]}" 'returning 1'
        return 1
    fi
    buf=${buf##+( )}    # Strip any leading spaces
    current_vt_pid=${buf% *}
    current_vt_cmd=${buf#* }
    msg D "Current virtual terminal command: $current_vt_cmd"

    # Display notification
    # ~~~~~~~~~~~~~~~~~~~~
    case $current_vt_cmd in

        # Text terminal login prompt
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~
        agetty | getty )
          echo $'\n\r==================' > /dev/$current_vt
          echo $'\r'"| $script_name $script_ver" > /dev/$current_vt
          while read
          do
              echo $'\r'"| $REPLY" > /dev/$current_vt
          done < <(echo "$text")
          echo $'\r==================' > /dev/$current_vt
          ;;

        # X display
        # ~~~~~~~~~
        X | Xorg )
            msg D 'Current virtual terminal is an X display'

            # Get X authority file or X display user name
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            get_x_authority_or_user "$current_vt"
            if (($?!=0)); then
                fct "${FUNCNAME[0]}" 'returning 1'
                return 1
            fi

            # Choose the X message function
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            # yad if available, otherwise zenity
            if type yad &>/dev/null; then
                x_msg_function=x_msg_yad
            elif type zenity &>/dev/null; then
                x_msg_function=x_msg_zenity
            else
                msg W 'Can not find yad or zenity. Please install one (yad recommended)'
                fct "${FUNCNAME[0]}" 'returning 1'
                return 1
            fi

            # Display the message
            # ~~~~~~~~~~~~~~~~~~~
            # If there is only one line of text, put an empty line in front
            # of it to approximate vertical centering in the message window
            (($(echo "$text" | wc -l)==1)) && text=$'\n'$text
            export DISPLAY=$display
            $x_msg_function $dialog_type "$script_name $script_ver" \
                "$text " "$x_msg_pid_flag"
            unset DISPLAY
            # TODO: remove x_authority_fn code if the value is not used
            unset x_authority_fn
            ;;

        # User logged on in text terminal
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        * )
          msg D 'Current virtual terminal matched the wild card'
          buf=$(who | grep " $current_vt ")
          current_vt_user=${buf%% *}
          buf+=$'\n=================='
          buf+=$'\n'"| $script_name $script_ver"
          while read
          do
              buf+=$'\n'"| $REPLY"
          done < <(echo "$text")
          buf+=$'\n=================='
          echo "$buf" | write $current_vt_user $current_vt
    esac

    fct "${FUNCNAME[0]}" returning
    return
}  # end of function msg_on_screen

#--------------------------
# Name: x_msg_zenity
# Purpose:
#   Displays an X window with a message using zenity
# Arguments:
#   $1 dialog type: info, error or warning
#   $2 title
#   $3 text
#   $4 x_msg_pid control: $true or $false
# Global variables:
#   Read: none
#   Set: x_msg_pid (when x_msg_pid control is $true)
# Return code: always 0
#--------------------------
function x_msg_zenity {
    fct "${FUNCNAME[0]}" 'started'
    local cmd

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r dialog_type=$1
    local -r title=$2
    local -r text=$3
    local -r x_msg_pid_flag=$4

    # Display message
    # ~~~~~~~~~~~~~~~
    cmd=(zenity "--$dialog_type" "--title=$title" "--text=$text")
    if [[ ${user_to_run_x_msg:-} != '' ]]; then
        su --command "$(printf '%q ' "${cmd[@]}")" --shell /bin/bash \
            "$user_to_run_x_msg" &>/dev/null &
        unset user_to_run_x_msg
    else
        "${cmd[@]}" &>/dev/null &
    fi
    [[ $x_msg_pid_flag ]] && x_msg_pid=$!

    fct "${FUNCNAME[0]}" returning
    return
}  # end of function x_msg_zenity

#--------------------------
# Name: x_msg_yad
# Purpose:
#   Displays an X window with a message using yad
# Arguments:
#   $1 dialog type: info, error or warning
#   $2 title
#   $3 text
#   $4 x_msg_pid control: $true or $false
# Global variables:
#   Read: none
#   Set: x_msg_pid (when x_msg_pid control is $true)
# Return code: always 0
#--------------------------
function x_msg_yad {
    fct "${FUNCNAME[0]}" 'started'
    local cmd

    # TODO: make the icon files configurable?  Or detect the theme and set
    # them accordingly?
    local icon
    local -r error_icon=/usr/share/icons/Tango/scalable/status/dialog-error.svg
    local -r info_icon=/usr/share/icons/Tango/scalable/status/dialog-information.svg
    local -r warning_icon=/usr/share/icons/Tango/scalable/status/dialog-warning.svg

    # Parse arguments
    # ~~~~~~~~~~~~~~~
    local -r dialog_type=$1
    local -r title=$2
    local -r text=$3
    local -r x_msg_pid_flag=$4

    # Display message
    # ~~~~~~~~~~~~~~~
    # * No buttons are shown so the window cannot accdentally be closed by the
    #   user incidentally pressing Enter when the window has popped up and thus
    #   an OK or Cancel button has taken focus
    # * --image sets the icon that appears on the left side of dialog
    # * --selectable-labels allows the user to select the dialog's text and copy
    #   it to the clipboard
    # * --sticky makes window visible on all desktops
    # * --window-icon sets the window icon; it appears in task lists
    export LANG=C
    case $dialog_type in
        info )
            icon=$info_icon
            ;;
        error )
            icon=$error_icon
            ;;
        warning )
            icon=$warning_icon
    esac
    cmd=(yad --no-buttons --image "$icon" --on-top --selectable-labels \
        --sticky --title=" $title " --text "$text" --window-icon "$icon"
    )
    if [[ ${user_to_run_x_msg:-} != '' ]]; then
        su --command "$(printf '%q ' "${cmd[@]}")" --shell /bin/bash \
            "$user_to_run_x_msg" &>/dev/null &
        unset user_to_run_x_msg
    else
        "${cmd[@]}" &>/dev/null &
    fi
    [[ $x_msg_pid_flag ]] && x_msg_pid=$!

    fct "${FUNCNAME[0]}" returning
    return
}  # end of function x_msg_yad
# vim: filetype=bash:
