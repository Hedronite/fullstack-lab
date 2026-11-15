# Lab 18: a Deployment whose failures stay visible

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, manifest, tasks and checker are our own.
It covers topics the public CKA and CKS curricula list (container output streams, probes,
Deployment rollout history, container immutability at runtime); no upstream lab text is used.

## Scenario

`status-api` is a small service that reports whether other services are healthy. The on-call
engineer found its Deployment like this. It keeps no rollout history (`revisionHistoryLimit: 0`),
waits an hour before calling a stuck rollout failed, writes its log to a file inside the container
(so `kubectl logs --previous` shows nothing after a crash), has no probes, runs `privileged` with a
writable root filesystem, and uses the `:latest` image tag. `starter/` is valid YAML that gets all
of this wrong. The point of the lab: after the service heals, the record of what failed must still
be there, and a failure must be able to say what happened.

## Tasks

Edit `starter/deployment.yaml`.

1. A crash can explain itself: the container sets `terminationMessagePolicy: FallbackToLogsOnError`.
2. Logs where Kubernetes looks: remove the `--log-file` argument and the log volume mount under
   `/var/log`; the app logs to stdout and stderr.
3. History and a deadline: `revisionHistoryLimit` of 5 or more, `progressDeadlineSeconds` of 600 or less.
4. Probes: a `readinessProbe` and a `livenessProbe` (`failureThreshold` 3 or more).
5. Immutable at runtime: `readOnlyRootFilesystem: true` with an `emptyDir` mounted at `/tmp`;
   not `privileged`, and `allowPrivilegeEscalation: false`.
6. Same program every restart: pin the image tag (or a digest).
7. (Not graded.) In one sentence each: why does `kubectl logs --previous` need the app to log to
   stdout, what does `FallbackToLogsOnError` read when the termination message file is empty, and
   why is a rollout history a record you want to keep after a rollback?

`reference/` is the worked answer. Do not open it until you are done.

## What the checker does

`check.sh` parses `deployment.yaml` with Nushell and prints one `Task n:` line per failed check,
then `RESULT 18-visible-failure-deployment fix PASS|FAIL`. It is static and offline: it never
calls `kubectl`, never contacts a cluster and never writes into your tree. Nothing in this lab
changes a cluster.

## Versions

Nushell 0.116 in the lab image `hedronite/fullstack-lab-ops:nickel1.18-nu0.116`; the checker needs
no other tool.
