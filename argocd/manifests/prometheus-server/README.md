# Custom Prometheus Server (no operator)

Bare Kubernetes objects to run a Prometheus server with **remote write receiver** enabled, exposed via **Ingress** with **TLS** and **basic auth** (user/password) for both read and write.

## Contents

- **configmap.yaml** – Prometheus config (`prometheus.yml`). Scrape and storage; remote write receiver is enabled by container args, not the config file.
- **deployment.yaml** – Deployment with `--web.enable-remote-write-receiver`. Single replica, non-root, emptyDir for storage.
- **service.yaml** – ClusterIP Service on port 9090.
- **secret-basic-auth.yaml** – Basic auth secret (htpasswd format) for the Ingress. **Replace with your own credentials before production.**
- **ingress.yaml** – Ingress (edge TLS via cert-manager `lab-ca-issuer`). Host is set by the ApplicationSet to `prometheus-server.<ingress-domain>`.

## Features

- **No Prometheus Operator** – Plain Deployment, ConfigMap, Service, Secret, Ingress.
- **Remote write receiver** – Enabled with `--web.enable-remote-write-receiver`. Clients can push to `https://<host>/api/v1/write` (with the same basic auth as the UI).
- **TLS** – cert-manager issues the certificate for the Ingress host using ClusterIssuer `lab-ca-issuer`.
- **Basic auth** – Read (UI, query API) and write (remote write API) are protected by the same username/password via the Ingress.

## Prerequisites

- **cert-manager** with ClusterIssuer `lab-ca-issuer` (for Ingress TLS).
- **Ingress controller** that supports basic auth if you rely on it (e.g. **nginx**). The OpenShift default router may not apply the nginx auth annotations; in that case either deploy an nginx Ingress controller and use it for this host, or protect Prometheus by other means (e.g. network policy, OAuth).

## Basic auth secret

The Ingress expects a Secret `prometheus-basic-auth` in the same namespace with key **auth** containing one line of htpasswd output (`user:hash`).

**Default (dev only):** user `prometheus`, password `changeme`. **Replace before production:**

```bash
# Create a file with htpasswd line (install apache2-utils or httpd-tools if needed)
htpasswd -nb YOUR_USER YOUR_PASSWORD > auth

# Create or replace the secret
kubectl create secret generic prometheus-basic-auth --from-file=auth -n couchbase --dry-run=client -o yaml | kubectl apply -f -
```

Or use a Kustomize secretGenerator in an overlay (keep the generated secret out of Git).

## Ingress host

The ApplicationSet injects the Ingress host from the Argo CD cluster secret annotation `ingress-domain`, so the deployed host is **prometheus-server.\<ingress-domain\>** (e.g. `prometheus-server.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`). No need to set the host in these manifests.

## Remote write URL

After deployment, remote write clients should use:

- **URL:** `https://prometheus-server.<ingress-domain>/api/v1/write`
- **Auth:** HTTP Basic with the same user/password as the UI.

Example Prometheus remote write config (in another Prometheus or agent):

```yaml
remote_write:
  - url: https://prometheus-server.<your-ingress-domain>/api/v1/write
    basic_auth:
      username: YOUR_USER
      password: YOUR_PASSWORD
```

## Sync

This app is deployed by the **prometheus-server** ApplicationSet (sync-wave 2). Ensure the cluster secret has the `ingress-domain` annotation (e.g. set by the cluster-objects PreSync hook).
