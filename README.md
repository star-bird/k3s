# Ansible Collection - star_bird.k3s

## Description

This collection is designed to create a k3s cluster, containing one-or-more controlplane nodes and zero-or-more agent nodes. The controlplane mesh runs over tailscale, and theoretically this secures the API endpoints.

## Roles

The following roles exist. If you wish to use a given role, they should be specified in the order provided below.

Roles expected to be run as root.

### OPTIONAL: systemd-resolved

This is a convenience role added to switch a system to using systemd-resolved. This is what Tailscale prefers to use if MagicDNS is in play on linux. Without this, there are a couple of fail states you can run into that break MagicDNS.

For more information, you can read the tailscale blog article about the [sisyphean task that is dns on linux](https://tailscale.com/blog/sisyphean-dns-client-linux).

This also gives systemd-resolved a config file that hardcodes CloudFlare DNS as resolvers of last resort (i.e. FallbackDNS).

Don't use this if it's not appropriate for your environment.

### prereqs

Expects to be run across the entire cluster. It's responsible for meeting all of the pre-reqs, such as downloading the k3s binary, setting some systemctl things to forward/route traffic, etc.

You do not need to call this role from your own playbook. It's automatically pulled in by other roles as needed.

#### Variables

##### prereq_k3s_version

The k3s version you wish to install.

### controlplane

Expects to be run on control plane nodes only. It will initialize the cluster if the first controlplane node (the "singleton") does not have a node-token file. It will install k3s on the singleton, configured to use wireguard. For subsequent controlplane and agent nodes, it will join them to the running cluster normally.

#### Variables

##### k3s_tailscale_authkey

Defaults to looking up TS_KEY environment variable. This should be a durable tailscale API key with a tag automatically applied. You should expect to rotate this API key on the hosts; since on a reboot k3s will restart tailscaled.service in a way that tries to re-use this key as it's specified in the k3s config file.

[Tailscale documentation on creating API keys](https://tailscale.com/kb/1101/api)

Applying a tag disables automatic required re-auth on the key. You can see tailscale docs on this [here](https://tailscale.com/kb/1028/key-expiry)

##### controlplane-cluster_cidr

If you are going to have multiple k3s clusters on the same tailnet, they need to have non-conflicting CIDRs so the routes don't conflict.

This defaults to 10.42.0.0/16, as per [k3s docs.](https://docs.k3s.io/cli/server?_highlight=cluster&_highlight=cidr#networking)

If you wish to use IPv6 or dual-stack network configuration, please see the relevant [k3s docs.](https://docs.k3s.io/networking/basic-network-options#dual-stack-ipv4--ipv6-networking)

##### controlplane_service_cidr

This is similar to above, however it defaults to 10.43.0.0/16

##### controlplane_extra_server_args

If you wish to pass additional args to k3s binary when the service is bing started (i..e `k3s server` is being run by systemd), then add them here. by default this is an empty string.

##### controlplane_cluster_name

This should be the name of the group for all k3s servers, controlplane and agent. We use this to make the controlplane ip accessible to all hosts (including agent hosts which do not run the controlplane tasks.)

##### controlplane_token_secret_name

The name of the bitwarden secret in the collection which contains the node token.

##### controlplane_argocd_enabled

Enables ArgoCD to be installed via helm after the first controlplane node is brought online.

##### controlplane_argocd_chart_version

The helm chart version to use for the installation

##### controlplane_argocd_values

The values to pass to helm for the ArgoCD chart installation.

##### Additional components: tailscale operator

This has the same variables as above, however the names replace "argocd" with "tailscale".

#### HA Kubernetes cluster needs a cluster load balancer for the API

While the controlplane nodes will cluster, the other controlplane nodes and the agents will point to the IP of the first controlplane node as their initial point of contact. This represents a single point of failure.

K3s has documentation about this [here.](https://docs.k3s.io/datastore/cluster-loadbalancer)

There are a couple ways to do that, however since we're primarily focused on using tailscale, our solution focuses on using tailscale operator and tailnet exclusively. Tailscale - the service - remains as a SPOF, however for the project I'm accepting the risk of cloud-provider level outages (i.e. an AWS or Tailscale outage can prevent new machines from joining the mesh VPN; however machines already up and running generally continue to do so - just don't reboot them).

Step 1: HA (high availability) Solution

There are a lot of ways we can do this. However, there is a way we can do this without taking on any additional dependencies beyond tailscale: set up a [Service without a selector](https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors) and creating a [custom EndPoint slice](https://kubernetes.io/docs/concepts/services-networking/service/#custom-endpointslices) ourselves.

This gives us a ClusterIP we can set up redundant subnet routers for over tailscale, rendering the cluster API endpoint free from SPOFs though in the event of a rolling reboot of all cluster nodes or similar there may be some minor disruption as tailscale switches from one subnet router to the next.

If you need to perform a rolling reboot of the cluster and must minimize downtime, it is recommended to wait until all N tailscale proxy pods are back online before rolling to the next. Minor disruption (on the order of a minute or less) has been observed during testing;  our goal is to avoid SPOFs that can render the cluster unusable/broken, and this scope is not intended to include zero-downtime deployments - for now.

If this is a problem, then you need a more robust solution that allows for authenticated connection to the kubernetes API for purposes of hitting the healthcheck endpoint. There are a number of ways this can be accomplished, and generally this will require a full loadbalancer such as HAProxy, NginX, or similar and because there are limited ways to get this onto Tailscale and still allow mTLS auth, they are beyond the scope of this project.

In order to just expose this ClusterIP using tailscale operator (i.e. expose it as a machine with an open port), just add the appropriate annotation to the Instance (see below). Please note, there will only be a single instance connecting to the tailnet to provide this access, so it's still a SPOF. We recommend using redundant subnet routers instead.

You can find examples of how to configure this in the examples/ subdirectory.
- connector.yaml gives an example of a tailscale connector pointed at a cluster IP.
- service_lb.yaml shows how to set up a service without a selector and to create a custom EndpointSlice pointed at the tailscale IPs of the control nodes.

You will need to approve the routes in the tailscale admin console, and you will need to configure the tls-san for the kubernetes cluster controlplane nodes, so you will need to set the following ansible variable for your control plane:

```
controlplane_extra_server_args: "--tls-san 10.45.78.177"
```

Once that is done, you will need to update the configurations to point at the ClusterIP instead of the default tailscale IP of the first controlplane node, and run the playbook a third time:

```
controlplane_api_ip: 10.45.78.177
```

Note: You cannot know the ClusterIP ahead of time. You will need to stand the cluster up, then create the custom resources, then modify controlplane_extra_server_args and then continue. Alternatively, you could set up a custom domain name on your network, stand up the cluster with tls-san set, and assign the IP address to the A record after the ClusterIP is known.


### agent

agent: Expects to be run on agent nodes only. This will install k3s and join the agents to the cluster. Note: Currently, this is not done with an agent token.

#### variables

These are the variables available to the agent role.

##### k3s_tailscale_authkey

Same as the controlplane version. We name it the same in both roles, so you only have to define it once.

##### agent_extra_args

Works the same as controlplane_extra_args.

##### agent_token_secret_name

This is the same as the controlpane version. It can even point to the same secret and use the same node token. Alternatively, you can create an [agent token](https://docs.k3s.io/cli/token#agent) and create a secret for having agents join.
