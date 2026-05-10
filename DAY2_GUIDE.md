# Voting App Infrastructure - Day 2 Operations Guide

This guide explains how to perform the mandatory "Day 2" scenarios required for the final project.

## 1. OS & Security Patching (Zero Downtime)
To demonstrate updating the underlying EC2 worker nodes (AMIs) with the latest patches without interrupting service:

1.  Open `voting-infra/terraform.tfvars`.
2.  Locate the `kubernetes_version` variable.
3.  Update the value to a newer minor or patch version (e.g., from `1.30` to `1.31`).
4.  Run `terraform apply`.
5.  **Observation:** Terraform will update the EKS cluster first, then perform a rolling update of the Managed Node Group. Because `max_unavailable` is set to `1` in the `eks` module, at least 3 nodes will remain healthy at all times, ensuring zero downtime for the application pods.

## 2. Schema Changes
To demonstrate a backend change that updates the RDS database schema:

1.  In `voting-infra/k8s-specifications/base/db/db-migrations/`, create a new file named `V2__Add_timestamp_to_votes.sql`.
2.  Add a SQL command (e.g., `ALTER TABLE votes ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;`).
3.  Open `voting-infra/k8s-specifications/base/db/kustomization.yaml`.
4.  Add the new file to the `configMapGenerator` list.
5.  Commit and push to the `voting-infra` repository.
6.  **Observation:** ArgoCD will detect the change and sync the `db-migration` Job. The Flyway container will run, detect the new `V2` migration, and apply it to the RDS instance automatically.

## 3. Chaos Defense
If the instructor triggers a failure:
1.  **Open Grafana:** Go to `https://grafana.wyxiao.games`.
2.  **Loki Logs:** Use the "Explore" tab, select the "Loki" datasource, and query `{app="vote"}` to see real-time application errors.
3.  **Metrics:** Use the "Node Exporter / Nodes" dashboard to check for CPU/Memory/Disk spikes that might have triggered an alert.
4.  **Recovery:** If a service is down, check ArgoCD to see if a specific pod is in `CrashLoopBackOff` and describe the pod to see the logs.
