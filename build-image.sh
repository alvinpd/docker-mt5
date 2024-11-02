#!/bin/sh

podman build --cgroup-manager=cgroupfs -t docker-mt5 .

