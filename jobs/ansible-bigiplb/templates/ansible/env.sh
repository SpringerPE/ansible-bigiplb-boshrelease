#!/usr/bin/env bash

# It needs to load the bigip_irule_bigsuds created by Ryan to manage irules without admin privileges
if [ -z ${ANSIBLE_LIBRARY+x} ]; then
    ANSIBLE_LIBRARY=/var/vcap/packages/ansible-bigiplb/library
else
    ANSIBLE_LIBRARY=/var/vcap/packages/ansible-bigiplb/library:${ANSIBLE_LIBRARY}
fi
export ANSIBLE_LIBRARY

