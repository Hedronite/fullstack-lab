# Builder VM (Colima)

A disposable Apple-silicon VM for lab work: Docker engine plus a single-node
k3s cluster (traefik off). Exactly two host directories are mounted: this repo
(read-only) and the lab workspace (`LAB_WORKSPACE`, default
`~/lab-workspaces/default`, read-write). Your home directory is not mounted, so
lab files live on the host and the VM holds nothing you cannot rebuild.
The host docker/kube context is not switched; commands use `--context colima-<profile>`.

| setting | value |
|---|---|
| arch / vmType | aarch64 / vz (virtiofs; repo ro + lab workspace rw) |
| cpu / memory | 3 / 6 GiB |
| disk / root disk | 40 GiB / 20 GiB |
| runtime | docker + k3s v1.35.0+k3s1, `--disable=traefik` |
| registry | optional plain-HTTP registry via `LAB_INSECURE_REGISTRY` |

## Rebuild

Needs `colima`, `docker` and `kubectl` on the host (`brew install colima docker kubectl`).

```bash
git clone https://github.com/Hedronite/fullstack-lab && cd fullstack-lab
./vm/bootstrap.sh builder2                         # VM + smoke tests
LAB_IMAGE=1 ./vm/bootstrap.sh builder2             # also build the lab image
LAB_INSECURE_REGISTRY=registry.example:3000 ./vm/bootstrap.sh builder2
LAB_IMAGE_REF=ghcr.io/hedronite/lab:v0.1.1 ./vm/bootstrap.sh builder2   # pick the published image
```

Without `LAB_IMAGE=1`, labs run against the published image pinned by digest in
`bootstrap.sh`; override with `LAB_IMAGE_REF` (a tag or digest is required, there
is no implicit `:latest`). Helper images (`alpine`, `busybox`) are digest-pinned too.

The script refuses to reuse an existing profile, writes `vm/colima.yaml` as the
profile config, starts it, waits for the node to be Ready, then runs a docker
build, a `terraform init/validate`, a k8s rollout, then `vm/labs.sh`.

## Labs

`vm/labs.sh <context> <image> <repo>` runs the same checks against any profile
and exits with the number of failures. No cloud credentials are used. Run
directly, it first checks that the context exists, the image ref is well formed
and carries a tag or digest, and the repo dir holds `labs-examples/`. It reads
`LAB_WORKSPACE` (default `~/lab-workspaces/default`). The admin kubeconfig for L5
is written mode 0600 to a temp dir outside the workspace, streamed into the
container over stdin, and removed on exit, Ctrl-C or TERM.

| check | what |
|---|---|
| S1 | docker build + node Ready |
| L0 | toolchain versions in the lab image |
| L1 | workspace terraform lab: init, validate, `terraform test` (mock provider; skipped if absent) |
| L2 | `labs-examples/tf`: init, validate, plan, apply (local provider) |
| L3 | `labs-examples/k8s` deploy + service in a scratch namespace, probed from a pod |
| L4 | default-deny NetworkPolicy blocks the same probe |
| L5 | kubectl from inside the lab container via the VM IP |

Remove it with `colima delete -p builder2 --data -f` (without `--data` the 40 GiB data disk stays behind; `LIMA_HOME=~/.colima/_lima limactl disk delete colima-builder2` clears it).

## Not carried over by a rebuild

Images built only inside an old VM, docker volumes, k3s Secrets/ConfigMaps/PVCs,
anything applied by hand, registry logins, and kubeconfig client certs (they are
regenerated). Keep those in git or a secret store, not in the VM.
