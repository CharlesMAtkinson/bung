# bung

## Introduction

bung (BackUp Next Generation) backs up files, MariaDB, OpenLDAP, postgres and -- via an extensible templates system with git support - routers and switches

bung was created in 2013 and is now known to be in regular use for backing up hundreds of laptops, PCs, phones, servers, routers and switches. It backs up files, MariaDB, OpenLDAP, postgres and -- via an extensible templates system with git support -- Cisco switches, MikroTik routers and Tejas optical line terminals.

Backups are written to local or remote file systems. Local file systems can be mounted when the backup starts and unmounted when it ends.  This minimises the danger of accidentally removing backup files.

The rsync-based files backup creates a "rolling full" backup which is easy to browse and restore from using everyday tools. Changed and deleted files are kept for a configurable number of days. When the source is on an LVM volume, snapshots can be used.

Backup jobs are scheduled or initiated by plugging in hotplug storage such as USB disks. When hotplug storage starts a backup, on-screen notifications (terminal or GUI) tell of the start and end of the backup.

When backing up to a remote file system, commands are run via ssh. For security, when run as root, bung on the remote server validates the commands before they are run.

Developed in a production environment, bung's log messages are designed to give the information needed to investigate problems.

Backup reports are sent by email.

bung is written in bash and uses the GPL-2.0+ license.

Full documentation is in source/usr/share/doc/bung

## Forking

When forking, please read tools/git-store-meta/README-for-bung.md
