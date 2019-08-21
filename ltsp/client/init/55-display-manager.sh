# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle tasks related to display managers.
# Patching arbitrary .conf files is hard; let's try appending the sections
# we want to the existing files and hope this properly overrides
# @LTSP.CONF: AUTOLOGIN RELOGIN GDM3_CONF LIGHTDM_CONF SDDM_CONF

display_manager_main() {
    local _ALUSER _AUTOLOGIN _RELOGIN host

    if [ -z "$AUTOLOGIN" ]; then
        _AUTOLOGIN=false
        _ALUSER=
    else
        _AUTOLOGIN=true
        _ALUSER=${AUTOLOGIN##*/}
        host=${AUTOLOGIN%%/*}
        if [ "$host/$_ALUSER" = "$AUTOLOGIN" ] &&
            echo "$HOSTNAME" | re grep -q "$host"
        then
            _ALUSER=$(echo "$HOSTNAME" | re sed "s/$host/$_ALUSER/")
        fi
    fi
    if [ "$RELOGIN" = "1" ]; then
        _RELOGIN=true
    else
        _RELOGIN=false
    fi
    re configure_lightdm
    re configure_gdm
    re configure_sddm
}

configure_lightdm() {
    is_command lightdm || return 0
    re mkdir -p /etc/lightdm
    {
        echo "
# Generated by \`ltsp init\`, see man:ltsp(8)
# You can append content here by specifying the LIGHTDM_CONF parameter
[Seat:*]
# Work around https://github.com/CanonicalLtd/lightdm/issues/49
greeter-show-manual-login=true
greeter-hide-users=false
autologin-user=$_ALUSER"
        if [ -f "$LIGHTDM_CONF" ]; then
            re cat "$LIGHTDM_CONF"
        elif [ -n "$LIGHTDM_CONF" ]; then
            echo "$LIGHTDM_CONF"
        fi
    } >>/etc/lightdm/lightdm.conf
}

configure_gdm() {
    local aluser conf

    aluser=$1
    is_command gdm3 || return 0
    re mkdir -p /etc/gdm3
    # Some distributions used daemon.conf instead of upstream custom.conf?
    if [ -f /etc/gdm3/daemon.conf ]; then
        conf=/etc/gdm3/daemon.conf
    else
        conf=/etc/gdm3/custom.conf
    fi
    {
        echo "
# Generated by \`ltsp init\`, see man:ltsp(8)
# You can append content here by specifying the GDM3_CONF parameter
[daemon]
AutomaticLoginEnable=$_AUTOLOGIN
AutomaticLogin=$_ALUSER"
        if [ -f "$GDM3_CONF" ]; then
            re cat "$GDM3_CONF"
        elif [ -n "$GDM3_CONF" ]; then
            echo "$GDM3_CONF"
        fi
    } >>"$conf"
}

configure_sddm() {
    is_command sddm || return 0
    # Defining a session is required for autologin to work in sddm
    for session in /usr/share/xsessions/plasma.desktop \
        /usr/share/xsessions/*.desktop
    do
        test -f "$session" && break
    done
    if [ -f "$session" ]; then
        session=${session#/usr/share/xsessions/}
    else
        session=
    fi
    {
        echo "
# Generated by \`ltsp init\`, see man:ltsp(8)
# You can append content here by specifying the SDDM_CONF parameter
[Autologin]
User=$_ALUSER
Session=$session
Relogin=$_RELOGIN"
        if [ -f "$SDDM_CONF" ]; then
            re cat "$SDDM_CONF"
        elif [ -n "$SDDM_CONF" ]; then
            echo "$SDDM_CONF"
        fi
    } >>/etc/sddm.conf
}