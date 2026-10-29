#!/usr/bin/env bash
# Rebuild the lab builder VM from scratch.
#   ./vm/bootstrap.sh <profile>            VM + smoke tests
#   LAB_IMAGE=1 ./vm/bootstrap.sh <p>      also build the full lab image (slow)
#   LAB_INSECURE_REGISTRY=host:port ...    trust a plain-HTTP registry (optional)
set -euo pipefail
profile="${1:?usage: bootstrap.sh <profile>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
chome="${COLIMA_HOME:-$HOME/.colima}"
ctx="colima-$profile"

if colima list 2>/dev/null | awk "NR>1{print \$1}" | grep -qx "$profile"; then
  echo "profile $profile already exists; refusing to touch it" >&2; exit 1
fi

mkdir -p "$chome/$profile"
cfg="$chome/$profile/colima.yaml"
cp "$here/colima.yaml" "$cfg"
if [[ -n "${LAB_INSECURE_REGISTRY:-}" ]]; then
  sed -i.bak "s|insecure-registries: \[\]|insecure-registries: [\"${LAB_INSECURE_REGISTRY}\"]|" "$cfg" && rm -f "$cfg.bak"
fi

echo "== colima start $profile"; time colima start "$profile"
colima list

echo "== kubernetes"
kubectl --context "$ctx" wait --for=condition=Ready node --all --timeout=180s
kubectl --context "$ctx" get nodes -o wide

echo "== docker build smoke"
docker --context "$ctx" build -q -t lab-smoke:local "$here/smoke/docker"
docker --context "$ctx" run --rm lab-smoke:local

echo "== terraform smoke (in container, no host install needed)"
docker --context "$ctx" run --rm -v "$here/smoke/tf:/src:ro" hashicorp/terraform:1.10.5 \
  sh -c "cp -r /src /w && cd /w && terraform init -input=false -no-color >/dev/null && terraform validate -no-color && terraform version"

echo "== k8s smoke"
kubectl --context "$ctx" apply -f "$repo/labs-examples/k8s/deployment.yaml"
kubectl --context "$ctx" rollout status deploy/lab-nginx --timeout=180s
kubectl --context "$ctx" delete -f "$repo/labs-examples/k8s/deployment.yaml"

if [[ "${LAB_IMAGE:-0}" == 1 ]]; then
  echo "== full lab image"
  time docker --context "$ctx" build -t lab:local "$repo"
  docker --context "$ctx" run --rm lab:local zsh -lc "terraform version | head -1; kubectl version --client; helm version --short; go version; rustc --version; uv --version"
fi
echo "== bootstrap $profile OK"
