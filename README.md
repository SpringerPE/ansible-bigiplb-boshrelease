# Add-on BOSH Release for [ansible-boshrelease](https://github.com/SpringerPE/ansible-bigiplb-boshrelease)

Add-on release with ansible playbooks to manage F5 BIG-IP load balancers.
It allows you to define/update a F5 virtual server with a pool of backend nodes
managed automatically by BOSH (no need to use static IPs). When you update the 
number of instances of the job, the new/old instance will be added/removed 
from the pool, and when the node is removed it will keep it available 
waiting to drain the active connections (with a timeout). 
Everything automatic!, just change the number of instances and run `bosh deploy`! 


## Usage

This is and add-on release, it will work only if it is deployed together with the 
*ansible-boshrelease* on the nodes, in particular with **ansible-hook**s job.
Have a look at [ansible-boshrelease](https://github.com/SpringerPE/ansible-bigiplb-boshrelease)
for the requirements and to see how it works.

Considering v2 manifest style, add the new releases in the `releases` block:

```
releases:
  [...]
- name: ansible
  version: latest
- name: ansible-bigiplb
  version: latest
```

then in your `instance_groups`, add:
 
```
instance_groups:
  [...]
  jobs:
  [...]
  - name: ansible-hooks
    release: ansible
  - name: ansible-bigiplb
    release: ansible-bigiplb
```

finally define the `properties` of the VIP and F5 device:

```
  properties:
    ansible_bigiplb:
      virtual_server_name: "vs.docker-registry.tools.springer.com.443"
      virtual_server_ip: "10.10.35.230"
      virtual_server_port: 443
      virtual_server_vlans:
      - "/Common/VLAN-999"
      virtual_server_profiles:
      - "/Common/http-default-springer"
      - "/CloudFoundry/docker-registry.tools.springer.com"
      irules:
      - name: "/CloudFoundry/ir.docker-registry.tools.springer.com"
      pool_name: "pl.docker-registry.tools.springer.com.5000"
      pool_members_port: 5000
      server:
      - device: "f5-device"
        ip: "127.0.0.1"
        user: "user"
        password: "password"
        partition: "CloudFoundry"
  [...]
```

and that's all!, run `bosh-deploy` and see how everything is done in the
F5: vip and pool created and nodes added to the pool. Moreover, when the 
number of the instances of the job changes, they will be added or 
removed from the F5 pool. 


Deleting a deployment requires a special consideration, if you do it
directly, the F5 will keep the VIP and pool configuration (empty). In order
to remove also those settings and maintain everything clean, before deleting 
the deployment, you have to define an errand job:

```
- name: f5-clean
  lifecycle: errand
  instances: 1
  vm_type: medium
  stemcell: trusty
  vm_extensions: []
  azs:
  - Online_Prod
  networks:
  - name: online
  jobs:
  - name: ansible-distclean
    release: ansible
  - name: ansible-bigiplb
    release: ansible-bigiplb
  properties:
    ansible_bigiplb:
      virtual_server_name: "vs.docker-registry.tools.springer.com.443"
      virtual_server_ip: "10.10.35.230"
      virtual_server_port: 443
      pool_name: "pl.docker-registry.tools.springer.com.5000"
      pool_members_port: 5000
      server:
      - device: "f5-device"
        ip: "127.0.0.1"
        user: "user"
        password: "password"
        partition: "CloudFoundry"

```

then run: `bosh run errand f5-clean` to delete all F5 settings. After that
you can run `bosh delete deployment <name>`.


## Additional features

There is another way to use this release: as an errand job. Useful if you do not
want to include ansible in all the instances of your deployment, or you want to 
automate a F5 LB pool with bosh for other jobs, just create an errand job in your
manifest including the `ansible-deploy` job:

```
- name: f5-setup
  lifecycle: errand
  instances: 1
  vm_type: medium
  stemcell: trusty
  vm_extensions: []
  azs:
  - Online_Prod
  networks:
  - name: online
  jobs:
  - name: ansible-deploy
    release: ansible
  - name: ansible-bigiplb
    release: ansible-bigiplb
  properties:
    ansible_bigiplb:
      virtual_server_name: "vs.docker-registry.tools.springer.com.443"
      virtual_server_ip: "10.10.35.230"
      virtual_server_port: 443
      virtual_server_vlans:
      - "/Common/VLAN-999"
      virtual_server_profiles:
      - "/Common/http-default-springer"
      - "/CloudFoundry/docker-registry.tools.springer.com"
      irules:
      - name: "/CloudFoundry/ir.docker-registry.tools.springer.com"
      pool_name: "pl.docker-registry.tools.springer.com.5000"
      pool_members_port: 5000
      server:
      - device: "f5-device"
        ip: "127.0.0.1"
        user: "user"
        password: "password"
        partition: "CloudFoundry"
```

and run `bosh run errand f5-setup` 


# Known issues

The automatic instance management is done by each node by taking the default IP 
address of each one, so if a node has multiple IP addresses the one with the 
default GW will be taken.


# Design

All variables used in this release are are defined in the ansible inventory file,
so the playbooks are usable outside this release (useful for testing) by 
defining a similar inventory.

All actions/playbooks (thanks to ansible) are idempotent.


# Author

José Riguera López (SpringerNature) (jose.riguera@springer.com)



# License

Apache 2.0 License
