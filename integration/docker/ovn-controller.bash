#!/bin/bash

set -xe

source "$(dirname "${BASH_SOURCE[0]}")/ovs-common.inc"

mkdir -p /etc/openvswitch
id_file=/etc/openvswitch/system-id.conf

test -s $id_file || get_self_system_uuid > $id_file

while [ ! -S $DBSOCK ]
do
  echo "ovn-controller.bash: Waiting for local OVS db process to start.."
  sleep 1
done

ovs-vsctl --no-wait set Open_vSwitch . external_ids:system-id=$(cat $id_file)

exec ovn-controller "unix:$DBSOCK" -vconsole:info
