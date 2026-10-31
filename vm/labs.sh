#!/usr/bin/env bash
# Lab smoke suite for the builder VM. Runs the same checks on any profile.
# usage: vm/labs.sh <kube-context> <lab-image> <repo-dir>
#   <lab-image> must carry an explicit tag or digest (no implicit :latest).
# Exit code is the number of failed checks. No cloud credentials are used.
set -u
umask 077
export PATH=/opt/homebrew/bin:$PATH

BUSYBOX="busybox:1.36@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"
ALPINE="alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc"

die() { echo "labs.sh: $*" >&2; exit 64; }
[[ $# -eq 3 ]] || die "usage: labs.sh <kube-context> <lab-image> <repo-dir>"
CTX=$1 IMG=$2 REPO=$3
kubectl config get-contexts -o name 2>/dev/null | grep -qxF -- "$CTX" || die "kube context not found: $CTX"
docker context inspect "$CTX" >/dev/null 2>&1 || die "docker context not found: $CTX"
img_re='^[a-z0-9]([a-z0-9._/-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9._-]+)*(:[A-Za-z0-9_][A-Za-z0-9._-]{0,127})?(@sha256:[a-f0-9]{64})?$'
[[ "$IMG" =~ $img_re ]] || die "malformed image ref: $IMG"
[[ "$IMG" == *@sha256:* || "${IMG##*/}" == *:* ]] || die "image needs an explicit tag or digest: $IMG"
[[ -d "$REPO/labs-examples/tf" && -d "$REPO/labs-examples/k8s" ]] || die "not a lab repo dir: $REPO"

WS=${LAB_WORKSPACE:-$HOME/lab-workspaces/default}
mkdir -p "$WS"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/labs.XXXXXX")
kc="$tmp/kubeconfig"; l1out="$tmp/l1.out"
# shellcheck disable=SC2329  # invoked via trap
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

fails=0
D=(docker --context "$CTX"); K=(kubectl --context "$CTX")
res() { printf 'RESULT %-30s %s\n' "$1" "$2"; [[ "$2" == FAIL ]] && fails=$((fails+1)); return 0; }

echo "== S1 recipe smoke: docker build + nodes"
if printf 'FROM %s\nRUN echo docker build ok > /ok\nCMD ["cat","/ok"]\n' "$ALPINE" | "${D[@]}" build -q -t lab-smoke:local - >/dev/null \
   && "${D[@]}" run --rm lab-smoke:local && "${K[@]}" get nodes --no-headers | grep -q " Ready "; then
  res S1-docker-build-node-ready PASS; else res S1-docker-build-node-ready FAIL; fi

echo "== L0 toolchain in $IMG"
if "${D[@]}" run --rm "$IMG" zsh -c 'terraform version|head -1; kubectl version --client|head -1; helm version --short; k9s version -s 2>/dev/null|head -1; go version; rustc --version; uv --version; gh --version|head -1'; then
  res L0-toolchain PASS; else res L0-toolchain FAIL; fi

echo "== L1 workspace tf lab (mock provider, no creds)"
if [[ ! -d "$WS/week1/tf/01-lifecycle-guardrails" ]]; then res L1-tf-workspace-lab SKIP; else
  # shellcheck disable=SC2016
  "${D[@]}" run --rm -v "$WS:/workspace:ro" "$IMG" zsh -c 'cp -R /workspace/week1/tf/01-lifecycle-guardrails /tmp/l1 && cd /tmp/l1 && rm -rf .terraform && terraform init -input=false -lockfile=readonly -no-color >/dev/null && terraform validate -no-color && echo VALIDATE_OK && terraform test -no-color; echo TEST_RC=$?' 2>&1 | tail -15 | tee "$l1out"
  if grep -q VALIDATE_OK "$l1out"; then res L1-tf-init-validate PASS; else res L1-tf-init-validate FAIL; fi
  if grep -q 'TEST_RC=0' "$l1out"; then res L1-tf-test PASS; else res L1-tf-test FAIL; fi
fi

echo "== L2 repo tf example: init/validate/plan/apply (local provider)"
if "${D[@]}" run --rm -v "$REPO/labs-examples/tf:/src:ro" "$IMG" zsh -c 'cp -R /src /tmp/l2 && cd /tmp/l2 && terraform init -input=false -no-color >/dev/null && terraform validate -no-color && terraform plan -no-color -out p >/dev/null && terraform apply -no-color p >/dev/null && cat hello.txt'; then
  res L2-tf-init-validate-plan-apply PASS; else res L2-tf-init-validate-plan-apply FAIL; fi

echo "== L3 k8s deploy+svc in scratch ns"
"${K[@]}" create ns lab-scratch >/dev/null
if "${K[@]}" -n lab-scratch apply -f "$REPO/labs-examples/k8s/" && "${K[@]}" -n lab-scratch rollout status deploy/lab-nginx --timeout=180s \
   && "${K[@]}" -n lab-scratch run probe --image="$BUSYBOX" --restart=Never --rm -i --timeout=120s -- wget -qO- -T5 http://lab-nginx | grep -q nginx; then
  res L3-k8s-deploy-svc PASS; else res L3-k8s-deploy-svc FAIL; fi

echo "== L4 NetworkPolicy default-deny"
"${K[@]}" -n lab-scratch apply -f - >/dev/null <<'Y'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny-ingress}
spec: {podSelector: {}, policyTypes: [Ingress]}
Y
if "${K[@]}" -n lab-scratch run probe2 --image="$BUSYBOX" --restart=Never --rm -i --timeout=120s -- wget -qO- -T5 http://lab-nginx >/dev/null 2>&1; then
  res L4-netpol-deny FAIL; else res L4-netpol-deny PASS; fi
if "${K[@]}" delete ns lab-scratch --wait=true >/dev/null; then res L3L4-cleanup PASS; else res L3L4-cleanup FAIL; fi

echo "== L5 kubectl from inside the lab container (VM-IP kubeconfig)"
IP=$("${K[@]}" get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
# Admin kubeconfig: 0600 temp file outside the workspace, removed by the trap.
"${K[@]}" config view --minify --flatten --context "$CTX" | sed -E "s#server: https://[^:]+:#server: https://${IP}:#" > "$kc"
# Streamed over stdin: the VM does not mount the host temp dir, and nothing is bind-mounted.
if "${D[@]}" run --rm -i "$IMG" sh -c 'umask 077; mkdir -p /root/.kube && cat > /root/.kube/config && kubectl get nodes --no-headers' < "$kc"; then
  res L5-container-kubectl PASS; else res L5-container-kubectl FAIL; fi

echo "labs: $fails failed"
exit "$fails"
