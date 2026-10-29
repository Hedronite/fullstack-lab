# Builder VM (Colima)

A disposable Apple-silicon VM for lab work: Docker engine plus a single-node
k3s cluster (traefik off). Lab files stay on the host through the home mount,
so the VM holds nothing you cannot rebuild.

| setting | value |
|---|---|
| arch / vmType | aarch64 / vz (virtiofs, home mounted writable) |
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
```

The script refuses to reuse an existing profile, writes `vm/colima.yaml` as the
profile config, starts it, waits for the node to be Ready, then runs a docker
build, a `terraform init/validate` and a k8s rollout.

Remove it with `colima delete -p builder2 -f`.

## Not carried over by a rebuild

Images built only inside an old VM, docker volumes, k3s Secrets/ConfigMaps/PVCs,
anything applied by hand, registry logins, and kubeconfig client certs (they are
regenerated). Keep those in git or a secret store, not in the VM.
