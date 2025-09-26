# lxc-config-export
Export config from Proxmox LXCs.

Your Proxmox host has access to all your LXCs and all your mounted external storage. So it's the ideal place to take backups from.

Provide a yaml file with the paths you want to export and the container id. If the path is on proxmox host, provide no id.
You can export single files or whole directories.

Usage:  
```export-lxc.sh <backup-dir> [yaml-file]```

```./export-lxc.sh /media/bak/minix/lxc/config-backups```





Schedules can be made via cron/systemd.
If no conf file is provided, conf.yml is searched in same dir as the sh file.


## Examples
A yaml with some common LXCs you may be running:
```
backups:

  - lxc: 131
    path: /opt/dashy/user-data

  - lxc: 131
    path: /opt/dashy/public/item-icons

  - lxc: 132
    path: /opt/homepage/config

  - lxc: 199
    path: /opt/mirrorr/data

  - path: /etc/samba  #Paths in Proxmox host
  - path: /root/lxc-config-export   #The config of this tool :)

  - lxc: 103
    path: /etc/pihole/dnsmasq.conf

  - lxc: 103
    path: /etc/pihole/hosts

  - lxc: 103
    path: /etc/pihole/pihole.toml
```



## Example systemd service

### lxc-config-export.service
```
[Unit]
Description=Run export-lxc

[Service]
Type=oneshot
ExecStart=bash -c "./export-lxc.sh /media/bak/minix/lxc/config-backups"
WorkingDirectory=/root/lxc-config-export
```

### lxc-config-export.timer
```
[Unit]
Description=Schedule export-lxc

[Timer]
OnCalendar=Fri *-*-* 19:16:00
Persistent=true

[Install]
WantedBy=timers.target
```

Then:
```
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now lxc-config-export.timer
```

Check it ```systemctl status lxc-config-export.timer```
Run it now ```systemctl start lxc-config-export.service``` and ```journalctl -u lxc-config-export.service```
