#!/usr/bin/env bash
# Rebuild the lab builder VM from scratch.
#   ./vm/bootstrap.sh <profile>            VM + smoke tests
#   LAB_IMAGE=1 ./vm/bootstrap.sh <p>      also build the full lab image (slow)
#   LAB_INSECURE_REGISTRY=host:port ...    trust a plain-HTTP registry (optional)
#   LAB_WORKSPACE=<dir>                    host dir mounted rw for lab work
#                                          (default ~/lab-workspaces; the repo is mounted ro)
set -euo pipefail
profile="${1:?usage: bootstrap.sh <profile>}"
if [[ ! "$profile" =~ ^[A-Za-z0-9._-]+$ || "$profile" == *..* ]]; then
  echo "invalid profile name: $profile" >&2; exit 2
fi
if [[ -n "${LAB_INSECURE_REGISTRY:-}" && ! "${LAB_INSECURE_REGISTRY}" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]]; then
  echo "LAB_INSECURE_REGISTRY must be host:port" >&2; exit 2
fi
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
chome="${COLIMA_HOME:-$HOME/.colima}"
ctx="colima-$profile"

if colima list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$profile"; then
  echo "profile $profile already exists; refusing to touch it" >&2; exit 1
fi

mkdir -p "$chome/$profile"
cfg="$chome/$profile/colima.yaml"
ws="${LAB_WORKSPACE:-$HOME/lab-workspaces}"
mkdir -p "$ws"; ws="$(cd "$ws" && pwd)"
# Mount only the repo (read-only) and the lab workspace (read-write), not all of $HOME.
awk -v repo="$repo" -v ws="$ws" '
  /^mounts: \[\]/ { print "mounts:"; print "  - location: \"" repo "\""; print "    writable: false";
                     print "  - location: \"" ws "\""; print "    writable: true"; next } { print }' \
  "$here/colima.yaml" > "$cfg"
if [[ -n "${LAB_INSECURE_REGISTRY:-}" ]]; then
  sed -i.bak "s|insecure-registries: \[\]|insecure-registries: [\"${LAB_INSECURE_REGISTRY}\"]|" "$cfg" && rm -f "$cfg.bak"
fi

# Build inside the guest so BuildKit is used; the context is streamed as a tarball.
gbuild() { tar -C "$2" -cf - . | colima ssh -p "$profile" -- docker build -q -t "$1" -; }

echo "== colima start $profile"; time colima start "$profile"
colima list

echo "== kubernetes"
kubectl --context "$ctx" wait --for=condition=Ready node --all --timeout=180s
kubectl --context "$ctx" get nodes -o wide

echo "== docker build smoke"
gbuild lab-smoke:local "$here/smoke/docker"
docker --context "$ctx" run --rm lab-smoke:local

echo "== terraform smoke (in a container, no host install needed)"
tar -C "$here/smoke/tf" -cf - . | docker --context "$ctx" run --rm -i --entrypoint sh hashicorp/terraform:1.10.5 \
  -c 'mkdir /w && cd /w && tar -xf - && terraform init -input=false -no-color >/dev/null && terraform validate -no-color && terraform version'

echo "== k8s smoke"
# autoActivate is off: the host's current docker/kube context is left alone; use --context.
kubectl --context "$ctx" apply -f "$repo/labs-examples/k8s/deployment.yaml"
kubectl --context "$ctx" rollout status deploy/lab-nginx --timeout=180s
kubectl --context "$ctx" delete -f "$repo/labs-examples/k8s/deployment.yaml"

if [[ "${LAB_IMAGE:-0}" == 1 ]]; then
  echo "== full lab image"
  time gbuild lab:local "$repo"
  docker --context "$ctx" run --rm lab:local zsh -c 'terraform version | head -1; kubectl version --client; helm version --short; go version; rustc --version; uv --version'
fi
echo "== labs"
"$here/labs.sh" "$ctx" "$( [[ "${LAB_IMAGE:-0}" == 1 ]] && echo lab:local || echo ghcr.io/hedronite/lab:latest )" "$repo"
echo "== bootstrap $profile OK"
