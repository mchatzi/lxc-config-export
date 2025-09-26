# lxc-config-export
Export config from Proxmox LXCs.

Your Proxmox host has access to all your LXCs and all your mounted external storage. So it's the ideal place to take backups from.

Provide a yaml file with the paths you want to export and the container id. If the path is on proxmox host, provide no id.
You can export single files or whole directories.

Usage:  
```export-lxc.sh <backup-dir> [yaml-file]```

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

  - path: /etc/samba
  - path: /root/lxc-config-mirrorr

  - lxc: 103
    path: /etc/pihole/dnsmasq.conf

  - lxc: 103
    path: /etc/pihole/hosts

  - lxc: 103
    path: /etc/pihole/pihole.toml
```

