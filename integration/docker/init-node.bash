#!/bin/bash

set -ex

source "$(dirname "${BASH_SOURCE[0]}")/ovs-common.inc"

NB="$(get_nbsb_kube_remote nb)"
export OVN_NB_DB="tcp:$NB"

ROLE="$(get_self_role)"

if [ "$ROLE" == "master" ]; then
  exec /opt/ovn-go-kube/ovnkube -daemonset -init-master "$(get_self_name)" -k8s-cacert "$(get_ca_cert_path)" -k8s-token "$(get_token)" -k8s-apiserver "$(get_api_server)" -cluster-subnet "$(get_cluster_cidr)" -service-cluster-ip-range "$(get_service_cidr)"
elif [ "$ROLE" == "worker" ]; then
  /opt/ovn-go-kube/ovnkube -daemonset -init-gateways -init-node "$(get_self_name)" -k8s-cacert "$(get_ca_cert_path)" -k8s-token "$(get_token)" -k8s-apiserver "$(get_api_server)" -cluster-subnet "$(get_cluster_cidr)" -service-cluster-ip-range "$(get_service_cidr)"
  #sleep forever
  tail -f /dev/null
else
  exit 1
fi
