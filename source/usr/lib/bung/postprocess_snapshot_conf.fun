# Copyright (C) 2014 Charles Atkinson
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
# Name: postprocess_snapshot_conf
# Purpose: 
#   * Completes the snapshot and mount data as far as is practicable
# Arguments: none
# Global variable usage:
#   Read:
#       msg_lf
#       snapshot_idx
#       snapshot_org_vol[]
#       snapshot_size[]
#       snapshot_vol[]
#   Write:
#       emsg: any error messages added
#       mount_fs_spec[]
# Output: none
# Return value: 1 when an error is detected, 0 otherwise
#--------------------------
function postprocess_snapshot_conf {
    fct "${FUNCNAME[0]}" started
    local buf i j n_vgs oIFS org_vol valid_vgs_regex vg vol

    # Nothing to do?
    # ~~~~~~~~~~~~~~
    if ((snapshot_idx==-1)); then
        fct "${FUNCNAME[0]}" 'returning (nothing to do)'
        return 0
    fi

    # Initialise
    # ~~~~~~~~~~
    local my_emsg=
    local my_rc=0

    # Get list of LVM volume groups
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(vgdisplay 2>&1)
    (($?>0)) && { emsg+=$msg_lf"Could not list LVM groups.  vgdisplay output: $buf"; return 1; }
    valid_vgs_regex=
    n_vgs=0
    for vg in $(echo "$buf" | grep '  VG Name ' | sed 's/VG Name//' )
    do
        ((n_vgs++))
        valid_vgs_regex+="|$vg"
    done
    valid_vgs_regex=${valid_vgs_regex#|}
    msg D "LVM VGs found: ${valid_vgs_regex//|/ }"

    # Complete the data for each snapshot
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for ((i=0;i<=snapshot_idx;i++))
    do
        # No VGs?
        # ~~~~~~~
        if ((n_vgs==0)); then
            my_emsg+=$msg_lf'Snapshot(s) configured but no LVM volume groups found'
            break
        fi

        # Original volume path
        # ~~~~~~~~~~~~~~~~~~~~
        org_vol=${snapshot_org_vol[i]}
        if [[ ! $org_vol =~ ^/ ]]; then
            # Relative path so make absolute
            if ((n_vgs==1)); then
                org_vol=/dev/$valid_vgs_regex/$org_vol
                msg D "Converted snapshot org_vol from ${snapshot_org_vol[i]} to $org_vol"
                snapshot_org_vol[i]=$org_vol
            else
                my_emsg+=$msg_lf"Invalid original volume path $org_vol (relative path but there is more than one VG: ${valid_vgs_regex//|/ })"
            fi
        fi
        msg D "snapshot_org_vol[$i]: ${snapshot_org_vol[$i]}"

        # Snapshot volume path /dev/<vgname>/*
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        vol=${snapshot_vol[i]}
        if [[ ! $vol =~ ^/ ]]; then
            # Relative path so make absolute
            if ((n_vgs==1)); then
                vol=/dev/$valid_vgs_regex/$vol
                msg D "Converted snapshot vol from ${snapshot_vol[i]} to $vol"
                snapshot_vol[i]=$vol
            else
                my_emsg+=$msg_lf"Invalid snapshot volume path $vol (relative"
                my_emsg+=" path but there is more than one VG:"
                my_emsg+=" ${valid_vgs_regex//|/ })"
                continue
            fi
        else
            buf=^/dev/$valid_vgs_regex
            if [[ ! $vol =~ $buf ]]; then
                my_emsg+=$msg_lf"Invalid snapshot volume path $vol (does not"
                my_emsg+=" match regex $buf"
                continue
            fi
        fi
        msg D "snapshot_vol[$i]: ${snapshot_vol[$i]}"

        # Snapshot volume path /dev/mapper/*
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        oIFS=$IFS
        IFS=/
        buf=(${snapshot_vol[i]})
        IFS=$oIFS
        if ((${#buf[*]}!=4)); then
            my_emsg+=$msg_lf"Invalid snapshot /dev/<vgname>/*:"
            my_emsg+=" ${snapshot_vol[i]} (not three components)"
            continue
        fi
        # buf[2] has the VG name, buf[3] has the LV name
        snapshot_mapper[i]=/dev/mapper/${buf[2]//-/--}-${buf[3]//-/--}
        msg D "snapshot_mapper[$i]: ${snapshot_mapper[$i]}"

        # Set up for mounting
        # ~~~~~~~~~~~~~~~~~~~
        j=${snapshot_mount_idx[i]}
        mount_fs_spec[j]=${snapshot_mapper[i]}
        msg D "Set up ${mount_fs_spec[j]} to mount on ${mount_fs_file[j]}"
    done

    [[ $my_emsg != '' ]] && { my_rc=1; emsg+=$my_emsg; }
    
    fct "${FUNCNAME[0]}" "returning with rc $my_rc"
    return $my_rc
}  # end of function postprocess_snapshot_conf
# vim: filetype=bash:
