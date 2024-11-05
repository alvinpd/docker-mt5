# Docker for MT5

This repository contains the tools and resources to run an MT5 terminal in a
docker/podman container on an Ubuntu Linux VPS.

# Running podman instances

These are the MetaTrader 5 instances run on the server:

```
$ podman run --rm -v ./docker:/docker -v ./.debby.mt5:/mt5:rw,U -v ./mt5-configs:/configs -p 5901:5900 localhost/docker-mt5 -c "/docker/boot.sh debby.ini"
$ podman run --rm -v ./docker:/docker -v ./.alvin.mt5:/mt5:rw,U -v ./mt5-configs:/configs -p 5902:5900 localhost/docker-mt5 -c "/docker/boot.sh alvin.ini"

```
# VNC Viewer on windows

These are to setup port forwarding to access the VNC server on the podman instances.

```
$ ssh -N -L 5900:localhost:5901 alvin@server # Connect to debby's VNC server
$ ssh -N -L 5900:localhost:5902 alvin@server # Connect to alvin's VNC server
```
