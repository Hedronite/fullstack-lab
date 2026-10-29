#!/usr/bin/env bash
# Lab smoke suite for the builder VM. Runs the same checks on any profile.
# usage: vm/labs.sh <kube-context> <lab-image> <repo-dir>
# Exit code is the number of failed checks. No cloud credentials are used.
set -u
fails=0
CTX=$1 IMG=$2 REPO=$3
export PATH=/opt/homebrew/bin:$PATH
WS=${LAB_WORKSPACE:-$HOME/lab-workspaces}/default
mkdir -p "$WS"
D="docker --context $CTX"; K="kubectl --context $CTX"
res() { printf 'RESULT %-30s %s\n' "$1" "$2"; [[ "$2" == FAIL ]] && fails=$((fails+1)); return 0; }
echo "== S1 recipe smoke: docker build + nodes"
printf "FROM alpine:3.20\nRUN echo docker build ok > /ok\nCMD [\"cat\",\"/ok\"]\n" | $D build -q -t lab-smoke:local - >/dev/null && $D run --rm lab-smoke:local && $K get nodes --no-headers | grep -q " Ready " && res S1-docker-build-node-ready PASS || res S1-docker-build-node-ready FAIL
echo "== L0 toolchain in $IMG"
$D run --rm "$IMG" zsh -c 'terraform version|head -1; kubectl version --client|head -1; helm version --short; k9s version -s 2>/dev/null|head -1; go version; rustc --version; uv --version; gh --version|head -1' && res L0-toolchain PASS || res L0-toolchain FAIL
echo "== L1 workspace tf lab (mock provider, no creds)"
if [[ ! -d "$WS/week1/tf/01-lifecycle-cli-broken" ]]; then res L1-tf-workspace-lab SKIP; else
$D run --rm -v "$WS:/workspace:ro" "$IMG" zsh -c 'cp -R /workspace/week1/tf/01-lifecycle-cli-broken /tmp/l1 && cd /tmp/l1 && rm -rf .terraform && terraform init -input=false -no-color >/dev/null && terraform validate -no-color && echo VALIDATE_OK && terraform test -no-color; echo TEST_RC=$?' 2>&1 | tail -15 | tee "$WS/.l1.out"
grep -q VALIDATE_OK "$WS/.l1.out" && res L1-tf-init-validate PASS || res L1-tf-init-validate FAIL
grep -q 'TEST_RC=0' "$WS/.l1.out" && res L1-tf-test PASS || res L1-tf-test FAIL
fi
echo "== L2 repo tf example: init/validate/plan/apply (local provider)"
$D run --rm -v "$REPO/labs-examples/tf:/src:ro" "$IMG" zsh -c 'cp -R /src /tmp/l2 && cd /tmp/l2 && terraform init -input=false -no-color >/dev/null && terraform validate -no-color && terraform plan -no-color -out p >/dev/null && terraform apply -no-color p >/dev/null && cat hello.txt' && res L2-tf-init-validate-plan-apply PASS || res L2-tf-init-validate-plan-apply FAIL
echo "== L3 k8s deploy+svc in scratch ns"
$K create ns lab-scratch >/dev/null
( $K -n lab-scratch apply -f "$REPO/labs-examples/k8s/" && $K -n lab-scratch rollout status deploy/lab-nginx --timeout=180s && \
  $K -n lab-scratch run probe --image=busybox:1.36 --restart=Never --rm -i --timeout=120s -- wget -qO- -T5 http://lab-nginx | grep -q nginx ) && res L3-k8s-deploy-svc PASS || res L3-k8s-deploy-svc FAIL
echo "== L4 NetworkPolicy default-deny (CKA NetworkPolicy theme)"
cat <<'Y' | $K -n lab-scratch apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny-ingress}
spec: {podSelector: {}, policyTypes: [Ingress]}
Y
if $K -n lab-scratch run probe2 --image=busybox:1.36 --restart=Never --rm -i --timeout=120s -- wget -qO- -T5 http://lab-nginx >/dev/null 2>&1; then res L4-netpol-deny FAIL; else res L4-netpol-deny PASS; fi
$K delete ns lab-scratch --wait=true >/dev/null && res L3L4-cleanup PASS || res L3L4-cleanup FAIL
echo "== L5 kubectl from inside the lab container (VM-IP kubeconfig)"
IP=$($K get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
$K config view --minify --flatten --context "$CTX" | sed -E "s#server: https://[^:]+:#server: https://$IP:#" > $WS/.lab-kc-$CTX
$D run --rm -v $WS/.lab-kc-$CTX:/root/.kube/config:ro "$IMG" kubectl get nodes --no-headers && res L5-container-kubectl PASS || res L5-container-kubectl FAIL
rm -f $WS/.lab-kc-$CTX
rm -f "$WS/.l1.out"
echo "labs: $fails failed"
exit $fails
