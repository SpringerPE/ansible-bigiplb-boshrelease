#!/usr/bin/env bash

# It needs to load the bigip_irule_bigsuds created by Ryan to manage irules without admin privileges
export ANSIBLE_LIBRARY=/var/vcap/packages/ansible-bigiplb/library:${ANSIBLE_LIBRARY}

