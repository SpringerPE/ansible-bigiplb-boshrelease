# Add-on BOSH Release for [ansible-boshrelease](https://github.com/SpringerPE/ansible-boshrelease)

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
Have a look at [ansible-boshrelease](https://github.com/SpringerPE/ansible-boshrelease)
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
        content: |
          when HTTP_REQUEST {
            if {not [HTTP::header exists Docker-Distribution-Api-Version] } {
              HTTP::header insert "Docker-Distribution-Api-Version" "registry/2.0"
            }
            if {not [HTTP::header exists X-Real-IP] } {
              HTTP::header insert "X-Real-IP" [IP::remote_addr]
            }
            if {not [HTTP::header exists X-Forwarded-Proto] } {
              HTTP::header insert "X-Forwarded-Proto" "https"
            }
            if {not [HTTP::header exists X-Forwarded-For] } {
              HTTP::header insert "X-Forwarded-For" [IP::remote_addr]
            }
          }
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

Note that irules will be deleted only if they have a content, in the
same way they were created: an irule without content means just a 
reference (it will not be created/deleted), but if it includes a
content, it is assumed that it has to be managed here.

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
      irules:
      - name: "/CloudFoundry/ir.docker-registry.tools.springer.com"
        content: true
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


# Mysql-Galera cluster example

This is an example about how to define a MySQL Galera cluster using the
[cf-myslq-release](https://github.com/cloudfoundry/cf-mysql-release) bosh release.
Here the proxies are not used, so it is a deployment of 2 mysql nodes and one arbitrator.
The reason not to use a proxy is just to simplify the infrastructure, and all they
functionality has been defined in the F5. Also, optionally, it helps to make the routing
persistent to the same backend from the same client by using an irule. You do not need
the irule if you know the clients are able to handle (or do not cause) deadlocks
and rollbacks.

```
  jobs:
  - release: cf-mysql
    name: mysql
  - name: smoke-tests-user
    release: cf-mysql
  - name: ansible-hooks
    release: ansible
  - name: ansible-bigiplb
    release: ansible-bigiplb
    properties:
      ansible_bigiplb:
        virtual_server_name: "vs.exp-mysql-galera.dc.springernature.pe.3306"
        virtual_server_ip: "2.2.2.2"
        virtual_server_port: 3306
        virtual_server_profiles:
        - "/Common/tcp"
        irules:
        - name: "/CloudFoundry/ir00_persistence.exp-mysql-galera.dc.springernature.pe"
          content: "when CLIENT_ACCEPTED { persist uie \"[IP::client_addr]\" }"
        pool_name: "pl.exp-mysql-galera.dc.springernature.pe.3306"
        pool_members_port: 3306
        pool_monitors:
       - name: "/Cloudfoundry/hm.exp-mysql-galera.dc.springernature.pe.9200"
         port: 9200
         type: "http"
         parent: "http"
         parent_partition: "Common"
         timeout: 4
         interval: 5
         time_until_up: 30
         send: "GET /api/v1/status HTTP/1.1\r\nUser-Agent: F5-healthcheck\r\nConnection: Close\r\n\r\n"
         receive: "^HTTP/1\.1 200 OK"
        server:
        - device: "XXXXXXXXXXXX"
          ip: "1.1.1.1"
          user: "user"
          password: "pass"
          partition: "CloudFoundry"
```


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
        content: |
          when HTTP_REQUEST {
            if {not [HTTP::header exists Docker-Distribution-Api-Version] } {
	      HTTP::header insert "Docker-Distribution-Api-Version" "registry/2.0"
            }
            if {not [HTTP::header exists X-Real-IP] } {
              HTTP::header insert "X-Real-IP" [IP::remote_addr]
            }
            if {not [HTTP::header exists X-Forwarded-Proto] } {
              HTTP::header insert "X-Forwarded-Proto" "https"
            }
            if {not [HTTP::header exists X-Forwarded-For] } {
              HTTP::header insert "X-Forwarded-For" [IP::remote_addr]
            }
          }
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

The automatic instance management is done on each node by taking the default IP 
address of itself, so if a node has multiple IP addresses the one with the 
default GW will be taken.

If a node suddenly crashes, it won't trigger the drain actions and its IP will
remain in the F5 LB as inactive. If Bosh resurrector is enabled, it could happen
that a new instance gets a different IP (than the crashed node) and no process
will remove the old IP from the F5 pool, in case of this situation, the way
-for now- is manually delete the inactive node from the pool. The errand job
to clean the F5 resources is not affected by this situation because it always
gets the facts (nodes) from the F5.


# Design

All variables used in this release are are defined in the ansible inventory file,
so the playbooks are re-usable outside this release (useful for testing) by 
re-defining a inventory with the variables needed by the playbooks.

All actions/playbooks (thanks to ansible) are idempotent.


# Creating a new final release

Run: `./bosh_final_release`


# Author

SpringerNature Platform Engineering, José Riguera López (jose.riguera@springer.com)

Copyright 2017 Springer Nature



# License

Apache 2.0 License
