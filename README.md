# Ansible Collection - star_bird.k3s

## Description

This collection is designed to create a k3s cluster, containing one-or-more controlplane nodes and zero-or-more agent nodes. The controlplane mesh runs over tailscale, and theoretically this secures the API endpoints.

## Roles

The following roles exist:

- prereqs: Expects to be run across the entire cluster. It's responsible for meeting all of the pre-reqs, such as downloading the k3s binary, setting some systemctl things to forward/route traffic, etc.
- controlplane: Expects to be run on control plane nodes only. It will initialize the cluster if the first controlplane node (the "singleton") does not have a node-token file. It will install (or upgrade) ArgoCD, Kube-vip, and k3s on the singleton. For subsequent controlplane nodes, it will join them to the running cluster normally.
- agent: Expects to be run on agent nodes only. This will install k3s and join the agents to the cluster. Note: Currently, this is not done with an agent token.

## Variables

This playbook expects to be provided with the following variables:
- cluster_cidr: The CIDR netblock for the cluster. By default, k3s will use 10.42.0.0/16
- service_cidr: The CIDR netblock for the cluster. By default, k3s will use 10.43.0.0/16
- kube_vip_enabled: Bool, this controls if kube_vip is installed to provide a resilient virtual IP for pointing the cluster & kubectl at, so we don't lose control if the first control plane node happens to fail. Disable this to provide your own solution, or (currently only option) to use the singleton IP. [WIP/stub: Configuring your own HA/Loadbalancer for the cluster will be an option later.]
- kube_vip_version: The version of kube-vip to install.
- kube_vip_address: The IP Address to use as a virtual IP.
- kube_vip_interface: The interface out of which kube-vip should ARP the VIP.
- bw_node_key_secret_name: The bitwarden secret name to find the node key in, as the 'password' field.
- tailscale_authkey: This is populated by the TS_KEY environment variable, which should contain a _durable_ tailscale [auth key](https://tailscale.com/kb/1085/auth-key). When k3s is restarted, it will re-run tailscaled in such a way that it will reauthenticate with the API key, which is stored in the k3s config file. That means it needs to be rotated regularly... No automation is currently provided for this.
- argocd_version: The version of ArgoCD to install.
- k9s_version: The version of k9s to install.
- k3s_version: The version of k3s to install.
- systemd_dir: [WIP: Why is this a variable?] /etc/systemd/system

## TODO: More cleanup
