# Lab 16: edge rollout and service

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, manifests, tasks and checker are our own.
It covers Kubernetes exam topics that the public CKA curriculum lists (rolling updates and
rollbacks, Services and their selectors, probes, resource requests, workload autoscaling); no
upstream lab text is used.

## Scenario

A small edge API runs as three Pods behind a Service, with a HorizontalPodAutoscaler. The on-call
engineer found it like this. The Service selector has a typo, so it has no endpoints, and its
`targetPort` points at a port nothing listens on. The Deployment recreates all Pods at once on
every update, keeps no history to roll back to, waits an hour before calling a stuck rollout
failed, runs an unpinned `:latest` image, has no readiness probe and no CPU request. The
autoscaler names a Deployment that does not exist and allows a single Pod. `starter/` is valid YAML
that gets all of this wrong.

## Tasks

Edit the three manifests in `starter/`.

1. Make the Service reach the Pods: the selector must match the Pod template labels, and
   `targetPort` must be a container port (by number or by name).
2. Make the rollout safe: `RollingUpdate` with `maxUnavailable: 0` and a non-zero `maxSurge`,
   `progressDeadlineSeconds` of 300 or less, `revisionHistoryLimit` of at least 2.
3. Make the Pod trustworthy: a pinned image tag (or digest), a `readinessProbe`, and a CPU request.
4. Make the autoscaler real: target the Deployment by kind and name, keep a CPU `Utilization`
   metric, `minReplicas` of at least 2 and `maxReplicas` not below it.
5. (Not graded.) In one sentence each: what does Kubernetes do when the new Pods never become
   Ready (does it roll back by itself?), which command returns to the previous revision, and why
   does an HPA on CPU utilization need a request when the node has plenty of spare CPU?

`reference/` is the worked answer. Do not open it until you are done.

## What the checker does

`check.sh` parses the three files with Nushell and prints one `Task n:` line per failed check, then
`RESULT 16-edge-rollout-and-service fix PASS|FAIL`. It is static and offline: it never calls
`kubectl`, never contacts a cluster and never writes into your tree. Nothing in this lab changes
a cluster.

## Versions

Nushell 0.116 in the lab image `hedronite/fullstack-lab-ops:nickel1.18-nu0.116`; the checker needs
no other tool.
