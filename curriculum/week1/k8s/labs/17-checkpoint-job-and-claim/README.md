# Lab 17: checkpoint job and claim

Author: Evan Eugene Pincham · Licence: MIT, same as this repository (see `/LICENSE`).
Written for Hedronite from scratch: the scenario, manifests, tasks and checker are our own.
It covers Kubernetes exam topics that the public CKA curriculum lists (Jobs and their failure
handling, persistent volumes and claims, access modes, storage classes and reclaim policies); no
upstream lab text is used.

## Scenario

A toy training program, `trainjob`, writes numbered checkpoints and resumes from the newest one
that verifies. It exits 78 when its configuration does not match the checkpoint, a failure that
retrying cannot fix. It runs as a Kubernetes Job. The on-call engineer found the manifests like
this. The Job keeps its checkpoints in an `emptyDir`, so a replaced Pod starts from zero. Its
retry budget is 50 with no time limit, an exit code 78 is retried like any other failure, a node
drain counts against the budget, and the image is `:latest`. The claim that should hold the
checkpoints asks for `ReadWriteMany`, names a class that does not exist, and the StorageClass
leaves `reclaimPolicy` unset, which means `Delete`. `starter/` is valid YAML that gets all of this
wrong.

## Tasks

Edit the three manifests in `starter/`.

1. Keep the data: the StorageClass sets `reclaimPolicy: Retain`, and the claim's
   `storageClassName` names that class.
2. One writer: the claim requests exactly `ReadWriteOncePod`, and the Job mounts it through a
   `persistentVolumeClaim` volume with the claim's name (not an `emptyDir`).
3. A budget: `restartPolicy: Never`, `backoffLimit` between 1 and 6, `activeDeadlineSeconds` of
   7200 or less.
4. Stop on what retrying cannot fix: a `podFailurePolicy` rule with `action: FailJob` on exit code
   78 (`onExitCodes`, operator `In`), and a rule with `action: Ignore` on the `DisruptionTarget`
   Pod condition so a node drain is not charged to the budget.
5. Same program every attempt: pin the image tag (or a digest).
6. (Not graded.) In one sentence each: why does a checkpoint written to an `emptyDir` survive a
   container crash but not a drained node, what does `ReadWriteOnce` still allow that
   `ReadWriteOncePod` does not, and why should a resume verify a checkpoint before it trusts it?

`reference/` is the worked answer. Do not open it until you are done.

## What the checker does

`check.sh` parses the three files with Nushell and prints one `Task n:` line per failed check, then
`RESULT 17-checkpoint-job-and-claim fix PASS|FAIL`. It is static and offline: it never calls
`kubectl`, never contacts a cluster and never writes into your tree. Nothing in this lab changes
a cluster.

## Versions

Nushell 0.116 in the lab image `hedronite/fullstack-lab-ops:nickel1.18-nu0.116`; the checker needs
no other tool.
