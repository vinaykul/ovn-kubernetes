#!/bin/bash

[[ ${__GUARD_VAR_COMMON_API} -eq 1 ]] && return || readonly __GUARD_VAR_COMMON_API=1

OVN_K8S_NODE_NAME="${OVN_K8S_NODE_NAME:-"$HOSTNAME"}"

source "$(dirname "${BASH_SOURCE[0]}")/kubeapi.bash"

get_self_name(){
  [ -z "$OVN_K8S_NODE_NAME" ] && return 1
  echo "$OVN_K8S_NODE_NAME"
}

get_cluster_cidr(){
  [ -z "$OVN_K8S_CLUSTER_CIDR" ] && return 2
  echo "$OVN_K8S_CLUSTER_CIDR"
}

get_service_cidr(){
  [ -z "$OVN_K8S_SERVICE_CIDR" ] && return 3
  echo "$OVN_K8S_SERVICE_CIDR"
}

get_self_subnet(){
  local S
  #jq will return 0 on a empty input
  S="$( kube_api_get_node "$OVN_K8S_NODE_NAME" | jq -er '.metadata.annotations["ovn_host_subnet"]')"
  [ -z "$S" ] && return 4
  echo "$S"
}

get_node_internal_ip(){
  local D
  D="$(kube_api_get_node "$1" | jq -er '.status.addresses[] | select(.type == "InternalDNS") | .address')"
  [ -z "$D" ] && return 5
  local P
  P="$(dig +short "$D")"
  if [ -z "$P" ]; then
    # Try to get node IP from hosts file (only works for local node - should meet the need here and get around AWS DNS flakiness)
    echo "WARNING: Unable to acquire IP for $D from DNS. Trying local hosts file.."
    P="$(cat /etc/hosts | grep $D | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')"
  fi
  [ -z "$P" ] && return 5
  echo "$P"
}

get_self_internal_ip(){
  get_node_internal_ip "$OVN_K8S_NODE_NAME"
}

get_self_role() {
  local L
  L="$( kube_api_get_node "$OVN_K8S_NODE_NAME" | jq -e '.metadata.labels')"
  [ -z "$L" ] && return 6
  echo "$L" | jq -er '."kubernetes.io/role"'
}

get_self_system_uuid() {
  local I
  I="$( kube_api_get_node "$OVN_K8S_NODE_NAME" | jq -er '.status.nodeInfo.systemUUID')"
  [ -z "$I" ] && return 7
  echo "${I,,}"
}
