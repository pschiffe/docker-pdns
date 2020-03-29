# PDNS example for Kubernetes

## Files
 - master-daemonset.yaml : Daemonset for PDNS supermaster
 - slave-daemonset.yaml : Daemonset for PDNS slaves
 - admin-dashboard.yaml : Deployment for PDNS-Admin Web Dashboard
 - mariadb.yaml : Example Mysql Deployment
 
## Example setup

This example deploys a supermaster and two slaves on the host network, so pdns can be reached from external networks. Access to the admin-dashboard has to be configured separately with ingress. The admin-dashboard uses a kubernetes clusterip service to use the supermaster-api. Supermaster, slaves and dashboard use the same MariaDB example deployment with different databases (not recommended for production environments).

## Requirements

### Node Labels
The Daemonsets use node-role labels as nodeSelector:

    kubectl label node node1 node-role.kubernetes.io/pdns-master=true
    kubectl label node node2 node-role.kubernetes.io/pdns-slave=true
    kubectl label node node3 node-role.kubernetes.io/pdns-slave=true

Any other node labels will also work.

### Service Names
Service names in the pdns namespace **must not** start with 'pdns' or they will break the pdns.conf environment templating.

### Pod-CIDR
Replace "10.244.0.0/16" in the manifests with your cluster's pod-cidr.

### Node IPs
Replace IPs and hostnames in the daemonset environments with your own node IPs and domains.

Used in this example: 
| component | host | ip |
|--|--|--|
| supermaster | ns1.example.com | 10.0.0.1 |
| slave1 | ns2.example.com | 10.0.0.2 |
| slave2 | ns3.example.com | 10.0.0.3 |
