# Ansible Collection - star_bird.k3s

## Description

This collection is designed to create a k3s cluster, containing one-or-more controlplane nodes and zero-or-more agent nodes. The controlplane mesh runs over tailscale, and theoretically this secures the API endpoints.

## Roles

The following roles exist:

### prereqs

Expects to be run across the entire cluster. It's responsible for meeting all of the pre-reqs, such as downloading the k3s binary, setting some systemctl things to forward/route traffic, etc.

### controlplane
Expects to be run on control plane nodes only. It will initialize the cluster if the first controlplane node (the "singleton") does not have a node-token file. It will install k3s on the singleton, configured to use wireguard. For subsequent controlplane and agent nodes, it will join them to the running cluster normally.

#### NOTE: HA Kubernetes cluster needs a cluster load balancer for the API

While the controlplane nodes will cluster, the other controlplane nodes and the agents will point to the IP of the first controlplane node as their initial point of contact. This represents a single point of failure.

https://docs.k3s.io/datastore/cluster-loadbalancer

For simpler installations where appropriate, we provide an option for installing Kube-VIP which will have the k8s cluster loadbalance for itself. As long as a single controlplane server is alive, the VIP (virtual IP) will be pointed to the controlplane API.

In addition to that, you can bring your own IP to the party, and use this instead of the IP address of the first controlplane node. Just define controlplane_api_ip instead of leaving it undefined.

### agent

agent: Expects to be run on agent nodes only. This will install k3s and join the agents to the cluster. Note: Currently, this is not done with an agent token.

### systemd-resolved

This is a convenience role added to switch a system to using systemd-resolved. This is what Tailscale prefers to use if MagicDNS is in play on linux. Without this, there are a couple of fail states you can run into that break MagicDNS.

For more information, read here:
https://tailscale.com/blog/sisyphean-dns-client-linux

This also gives systemd-resolved a config file that hardcodes CloudFlare DNS as resolvers of last resort (i.e. FallbackDNS).

Don't use this if it's not appropriate for your environment.

## Variables

This playbook expects to be provided with the following variables:
- cluster_cidr: The CIDR netblock for the cluster. By default, k3s will use 10.42.0.0/16
- service_cidr: The CIDR netblock for the cluster. By default, k3s will use 10.43.0.0/16
- bitwarden_node_key_secret_name: The bitwarden secret name to find the node key in, as the 'password' field.
- k3s_ tailscale_authkey: This is populated by the TS_KEY environment variable, which should contain a _durable_ tailscale [auth key](https://tailscale.com/kb/1085/auth-key). When k3s is restarted, it will re-run tailscaled in such a way that it will reauthenticate with the API key, which is stored in the k3s config file. That means it needs to be rotated regularly... No automation is currently provided for this.
- argocd_version: The version of ArgoCD to install.
- k3s_version: The version of k3s to install.

## TODO: More cleanup
