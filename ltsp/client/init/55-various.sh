# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Handle various little things that don't deserve a separate file
# @LTSP.CONF: FSTAB_x IGNORE_EPOPTES

various_main() {
    # initrd-bottom may have renamed the real init
    if [ -f /sbin/init.ltsp ]; then
        re rm /sbin/init
        re mv /sbin/init.ltsp /sbin/init
    fi
    re rm -f "/var/crash/"*
    # Some live CDs don't have sshfs; allow the user to provide it
    if ! is_command sshfs && [ -x "/etc/ltsp/bin/sshfs-$(uname -m)" ]
    then
        re ln -s "../../etc/ltsp/bin/sshfs-$(uname -m)" /usr/bin/sshfs
    fi
    # Disable systemd-gpt-auto-generator (DiscoverablePartitionsSpec)
    rw rm -f /lib/systemd/system-generators/systemd-gpt-auto-generator
    config_epoptes
    config_fstab
    config_locale
    config_machine_id
    config_motd
}

config_epoptes() {
    # Symlink server epoptes certificate
    if [ "$IGNORE_EPOPTES" != "1" ] && [ -f /etc/ltsp/epoptes.crt ]; then
        re mkdir -p /etc/epoptes
        re ln -sf ../ltsp/epoptes.crt /etc/epoptes/server.crt
        test -x /usr/bin/epoptes && rw chmod -x /usr/bin/epoptes
    fi
}

config_fstab() {
    # TODO: if mount.nfs isn't available, and nfs fstab entries exist,
    # comment them out and handle them via klibc nfsmount?
    {
        echo "# Generated by \`ltsp init\`, see man:ltsp(8)"
        re echo_values "FSTAB_[[:alnum:]_]*"
    } >/etc/fstab
}

config_locale() {
    # TODO: quick hack for ubuntu live CDs; revisit later
    test -f /etc/default/locale || return 0
    grep -q LANG /etc/default/locale && return 0
    echo "# Generated by \`ltsp init\`, see man:ltsp(8)
LANG=${LANG:-C.UTF-8}
${LANGUAGE:+LANGUAGE=$LANGUAGE}" >> /etc/default/locale
}

# The dbus machine id should be unique for each client, otherwise problems may
# occur, e.g. if a thin client has the same id as the server, then `sudo gedit`
# on the client session which runs on the server gives "access denied"!
# It also helps if it's constant, so we generate it from the client MAC
# address. That way we don't pollute e.g. ~/.pulse/* with random entries on
# fat clients. See also `man machine-id`.
config_machine_id() {
    printf "%s00000000000000000000\n" "$(echo "$MAC_ADDRESS" | tr -d ':')" \
        > /etc/machine-id
    if [ -f /var/lib/dbus/machine-id ]; then
        re ln -sf ../../../etc/machine-id /var/lib/dbus/machine-id
    fi
}

# /etc/init/mounted-run.conf calls `run-parts /etc/update-motd.d`, and that
# takes more than a (completely useless) second. But we don't want to remove
# the whole mounted-run service as it prepares /run too. So remove most scripts
# there but leave the header and footer.
config_motd() {
    re rm -f /etc/update-motd.d/[1-9][0-8]*
}
