# Multi-Cluster Ingress

Apply these manifests **only to the config-cluster** (gke-primary). MCI's controller will propagate the rules to all member clusters and create:

- a global static IP (reserved by Terraform: `platform-edge-ip`)
- a global external HTTPS load balancer
- backend services per `MultiClusterService`, with NEGs in each cluster
- the managed SSL cert (reserved by Terraform: `platform-edge-cert`)

```sh
kubectl --context $PRIMARY apply -f multi-cluster-service.yaml
kubectl --context $PRIMARY apply -f multi-cluster-ingress.yaml
```

Verify with:

```sh
kubectl --context $PRIMARY -n web-app-a describe mci platform-edge
```

The MCI status reports per-cluster NEGs once both clusters have healthy pods. Cloud Armor and per-backend timeouts are attached via the `BackendConfig` objects in each app's base manifests.
