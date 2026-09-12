<h1 align="center">hedronite-lab</h1>

<p align="center">
  <strong>A student OS and a devops workshop on your laptop.</strong><br>
  <em>Install once. Two verbs after: <code>hedronos</code> and <code>lab</code>.</em>
</p>

<p align="center">
  <a href="https://github.com/VirtualMachinist/hedronos"><img src="https://img.shields.io/badge/student_OS-hedronos-b87333?style=flat&colorA=0a0a0e" alt="hedronos"></a>
  <a href="https://github.com/VirtualMachinist/hedronite-devops-lab"><img src="https://img.shields.io/badge/devops_toolbox-lab-1e3a8a?style=flat&colorA=0a0a0e" alt="lab"></a>
  <a href="https://ghcr.io/hedronite/lab"><img src="https://img.shields.io/badge/GHCR-hedronite%2Flab-1e3a8a?style=flat&colorA=0a0a0e" alt="ghcr.io/hedronite/lab"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/VirtualMachinist/hedronite-devops-lab?style=flat&colorA=0a0a0e&colorB=b87333" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#whats-mounted">Mounts</a> ·
  <a href="https://github.com/VirtualMachinist/hedronos">Student OS repo</a>
</p>

<p align="center">
  Built by <a href="https://hedronite.com">Hedronite</a>'s
  <a href="https://github.com/VirtualMachinist">VirtualMachinist</a>.
  This repo is the <strong><code>lab</code></strong> verb — not HedronOS itself.
</p>

---

**hedronite-lab** is the umbrella install story for two verbs on one laptop:

| Verb | Repo | Role |
|---|---|---|
| **`hedronos`** | [`VirtualMachinist/hedronos`](https://github.com/VirtualMachinist/hedronos) | Terminal student OS (Boot → Home → lessons) |
| **`lab`** | **this repo** | Disposable devops toolbox in `ghcr.io/hedronite/lab` |

**Start with the HedronOS install** — it wires the kernel, the TUI, and the `lab` function in one pass:

```bash
curl -fsSL https://raw.githubusercontent.com/VirtualMachinist/hedronos/main/install.sh | bash
```

Use **`lab` alone** below only if you want the workshop without the student OS.

## What this repo is

An ephemeral DevOps lab in a single container image: Terraform with multi-version tfenv, kubectl, helm, krew, k9s, Go, Python via uv, Rust, Rails 7, R with tidyverse, Prometheus, Grafana, and bench tools (gh, jq, yq, tmux, vim, neovim, zsh).

Start it, work, throw it away. Anything worth keeping lives in a bind-mount; the container holds nothing precious. Certification practice and infrastructure experiments run in a room that resets to clean every time you enter.

## Quick start

**Needs:** a container runtime (OrbStack, Docker Desktop, or Colima) and zsh on the host.

Pick a runtime:

- **OrbStack** (recommended on macOS): fastest VirtioFS bind-mounts and native Rosetta for amd64 images on Apple silicon. `brew install orbstack`.
- **Colima**: open source; on Apple silicon:

```bash
colima start --arch aarch64 --vm-type=vz --vz-rosetta
```

- **Docker Desktop**: works if you already run it.

Pull the image:

```bash
docker pull ghcr.io/hedronite/lab:latest
```

Install the shell function (VirtualMachinist is the source of truth for raw URLs):

```zsh
source <(curl -fsSL https://raw.githubusercontent.com/VirtualMachinist/hedronite-devops-lab/main/shell/lab.zsh)
```

Or clone and source locally:

```zsh
git clone https://github.com/VirtualMachinist/hedronite-devops-lab.git
source /path/to/hedronite-devops-lab/shell/lab.zsh
```

Add whichever line you choose to `~/.zshrc`.

Verify:

```bash
lab echo ok
```

## Usage

Four patterns cover everything.

Interactive shell:

```bash
lab
```

One command, then gone:

```bash
lab terraform version
```

Chained — each command in its own fresh container:

```bash
lab terraform init && lab terraform plan
```

Toolchain runners pass through unchanged:

```bash
lab uv run pytest
```

Every invocation starts a new container and removes it on exit. State that must survive belongs under `/workspace`.

Pair with the student OS anytime: [`hedronos`](https://github.com/VirtualMachinist/hedronos#two-verbs) for lessons; **`lab`** for infra practice.

## What's mounted

| Container path | Host path | Mode | Purpose |
|---|---|---|---|
| `/workspace` | `~/lab-workspaces/default` (override: `LAB_WORKSPACE`) | rw | scratch that survives the container |
| `/labs` | `LAB_LABS` if set and the path exists | ro | optional practice corpus |
| `/tomes` | `LAB_TOMES` if set and the path exists | ro | optional reference books |
| `/root/.aws` | `~/.aws` if present | ro | AWS credentials |
| `/root/.config/gcloud` | `~/.config/gcloud` if present | ro | GCP credentials |
| `/root/.azure` | `~/.azure` if present | ro | Azure credentials |
| `/root/.kube` | `~/.kube` if present | ro | cluster access |
| `/root/.ssh` | `~/.ssh` if present | ro | git identity |

By default only `/workspace` is mounted. Set `LAB_LABS` and/or `LAB_TOMES` when you have local practice material; otherwise you see a one-line note that corpus mounts are optional.

Read-only is deliberate for everything except `/workspace`. The container can use your credentials and your corpus; it cannot alter either.

## Cloud credentials

The image contains no credentials and never will. No Dockerfile layer copies a secret, and the `.gitignore` blocks common leak paths. Credentials reach the container only through the read-only mounts above.

Each cloud CLI can run under a `[lab]` profile — scoped, revocable access instead of your daily identity:

```bash
bash scripts/setup-lab-profile.sh
```

Inside the container: `AWS_PROFILE=lab`, `gcloud config configurations activate lab`, or the Azure service principal the script created.

## Kubernetes (optional)

kubectl in the container points wherever your host kubeconfig points. An advanced path joins a k3s worker named `hedronite-devops-lab`; **v1 one-click install does not require a cluster.**

Once a context exists:

```bash
kubectl config use-context hedronite-devops-lab
lab kubectl get nodes
```

See `labs-examples/k8s/` for a first deployment.

## Observability

For scratch work the image ships `prometheus` and `grafana` as plain binaries — start inside the container, discard with the container. For monitoring that persists, `helm/prom-stack-values.yaml` configures kube-prometheus-stack; `labs-examples/obs/` walks through both.

## Philosophy

Cattle, not pets. A lab machine you configure by hand becomes a machine you fear to lose. The container is disposable by construction: every run starts from the same image, and the image rebuilds from one Dockerfile anyone can read.

Study material mounts read-only. Scratch lands in `/workspace`. Delete the container mid-session and you lose only a process table.

## Contributing / extending

Tool versions are `ARG`s at the top of the Dockerfile. Bump one, tag a release, and CI publishes multi-arch images to GHCR:

```bash
git tag v0.1.1
git push origin v0.1.1
```

To add a language, add one layer in the toolchain section and end with a smoke command matching the existing layers.

## License

MIT. See [LICENSE](LICENSE).
