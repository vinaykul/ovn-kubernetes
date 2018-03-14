#!/bin/bash

set -xe

source "$(dirname "${BASH_SOURCE[0]}")/ovs-common.inc"

LOCAL_IP="$(get_self_internal_ip)"
ENCAP_TYPE=geneve

OVN_SB_DB="$(get_nbsb_kube_remote sb)"
OVN_NB_DB="$(get_nbsb_kube_remote nb)"

while [ ! -S $DBSOCK ]
do
  echo "ovs-vswitchd.bash: Waiting for local OVS db process to start.."
  sleep 1
done

ovs-vsctl --no-wait set Open_vSwitch . \
  external_ids:ovn-remote="tcp:$OVN_SB_DB" \
  external_ids:ovn-nb="tcp:$OVN_NB_DB" \
  external_ids:ovn-encap-ip="$LOCAL_IP" \
  external_ids:ovn-encap-type="$ENCAP_TYPE"

echo "ovs-vswitchd.bash: Starting ovs-vswitchd.."
exec ovs-vswitchd "unix:$DBSOCK" -vconsole:info
