# Prometheus Server (Helm)

Prometheus server deployed via the [prometheus-community Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus) with **remote write receiver** enabled, **StatefulSet**, **10Gi PVC**, and **Ingress** with **TLS** and **basic auth** (user/password) for both read and write.

## Contents

- **values.yaml** – Helm values for the chart (StatefulSet, 10Gi PVC, Ingress with TLS + basic auth, minimal scrape config, remote write receiver). Ingress host is overridden at deploy time by the ApplicationSet via `helm.parameters`.
- **secret-basic-auth.yaml** – Basic auth secret (htpasswd format) for the Ingress. **Replace with your own credentials before production.**

## Features

- **Helm chart** – [prometheus-community/prometheus](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus); no Prometheus Operator.
- **Remote write receiver** – `server.extraArgs.web.enable-remote-write-receiver`. Clients can push to `https://<host>/api/v1/write` (same basic auth as the UI).
- **StatefulSet + 10Gi PVC** – `server.statefulSet.enabled: true`, `server.persistentVolume.size: 10Gi`.
- **TLS** – cert-manager issues the certificate for the Ingress host using ClusterIssuer `lab-ca-issuer`.
- **Basic auth** – Read (UI, query API) and write (remote write API) protected by the same username/password via Ingress annotations.

## Prerequisites

- **cert-manager** with ClusterIssuer `lab-ca-issuer` (for Ingress TLS).
- **Ingress controller** that supports basic auth if you rely on it (e.g. **nginx**). The OpenShift default router may not apply the nginx auth annotations; in that case either deploy an nginx Ingress controller for this host or protect Prometheus by other means.

## Basic auth secret

The Ingress expects a Secret `prometheus-basic-auth` in the same namespace with key **auth** containing one line of htpasswd output (`user:hash`).

**Default (dev only):** user `prometheus`, password `changeme`. **Replace before production:**

```bash
htpasswd -nb YOUR_USER YOUR_PASSWORD > auth
kubectl create secret generic prometheus-basic-auth --from-file=auth -n couchbase --dry-run=client -o yaml | kubectl apply -f -
```

Or use a Kustomize secretGenerator in an overlay (keep the generated secret out of Git).

## Ingress host

The ApplicationSet injects the Ingress host via **Helm parameters** from the Argo CD cluster secret annotation `ingress-domain`, so the deployed host is **prometheus-server.\<ingress-domain\>** (e.g. `prometheus-server.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`). The placeholder in `values.yaml` is overridden by `server.ingress.hosts[0]` and `server.ingress.tls[0].hosts[0]`.

## Remote write URL

- **URL:** `https://prometheus-server.<ingress-domain>/api/v1/write`
- **Auth:** HTTP Basic with the same user/password as the UI.

Example `remote_write` config:

```yaml
remote_write:
  - url: https://prometheus-server.<your-ingress-domain>/api/v1/write
    basic_auth:
      username: YOUR_USER
      password: YOUR_PASSWORD
```

## Sync

Deployed by the **prometheus-server** ApplicationSet (sync-wave 2). The Application uses two sources: (1) Helm chart from prometheus-community with valueFiles from this directory and host parameters from the cluster; (2) Git path to this directory so `secret-basic-auth.yaml` is applied. Ensure the cluster secret has the `ingress-domain` annotation (e.g. set by the cluster-objects PreSync hook).
