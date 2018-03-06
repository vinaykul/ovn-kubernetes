#!/bin/bash

docker run --rm -it --entrypoint /bin/bash -e TERM=linux -w /root \
  -v /opt/ovn-kubernetes:/opt/ovn-kubernetes \
  -v /opt/cni/bin:/host/opt/cni/bin \
  -v /etc/cni/net.d:/host/etc/cni/net.d \
  -v "$(readlink -f "$(dirname "$0")")"/docker:/root \
  vmware/photon-2.0-ovnkube:v0.1.0 -l
