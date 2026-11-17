# `lab.toml`: lab manifests and the image floor

Every lab declares the tools it needs in one `lab.toml`. The published image,
`ghcr.io/hedronite/lab`, is built from the union of those manifests plus a
fixed baseline, the **floor** (`image/floor.toml`). A new lab that needs a new
tool changes the union, and the image follows. A lab that only uses tools
already in the union changes nothing.

`scripts/lab_manifest.py` is the reference implementation of everything on
this page. Where this page and the script disagree, the script wins and this
page is the bug.

```bash
scripts/lab_manifest.py validate             # floor + every lab.toml + coverage + union
scripts/lab_manifest.py union                # resolved union as JSON
scripts/lab_manifest.py union --format args  # NAME_VERSION=x lines for image build args
python3 -m unittest discover -s scripts/tests
```

Python 3.11 or later, standard library only. Exit codes: 0 ok, 1 invalid or
conflicting, 2 usage.

## Where a manifest lives

One manifest per lab, in the directory Hedronite owns for that lab:

| Lab source | Manifest |
|---|---|
| Hedronite-authored lab (`curriculum/<week>/<area>/labs/<lab>/`) | `labs/<lab>/lab.toml` |
| Lab pulled from a submodule (listed in `labs.txt`, not `local:`) | `graders/<lab>/lab.toml`, beside the grader. Submodule files are never edited or copied |
| Example (`labs-examples/<name>/`) | `labs-examples/<name>/lab.toml` |

`validate` fails if any lab in `labs.txt`, any lab directory with a `check.sh`
or `starter/`, or any example has no manifest, or has two. Directories named
`upstream`, `.git`, `node_modules`, `target`, and `.terraform` are not scanned.

## Manifest format

```toml
schema = "hedronite.lab/v1"

[lab]
id      = "tf-01"                      # required, unique: ^[a-z0-9][a-z0-9.-]{0,63}$
aliases = ["01-lifecycle-guardrails"]  # optional; other names `lab <id>` accepts, unique too
title   = "Lifecycle guardrails"       # required
kind    = "fix"                        # required: fix | explain | build | example
family  = "terraform"                  # required: terraform | kubernetes | observability | rust |
                                       #   ops | bun | gleam | python | go | nix | polyglot
date    = "2026-11-16"                 # optional, YYYY-MM-DD, for `lab <date>`
source  = "curriculum/week1/tf/labs/01-lifecycle-guardrails"  # optional, repo-relative, must exist

[grade]
backend = "check-sh"                   # required: terraform-test | check-sh | manual | none
entry   = "curriculum/week1/tf/labs/01-lifecycle-guardrails/check.sh"
                                       # required for terraform-test and check-sh; repo-relative file
network = "none"                       # required: none | egress (what grading needs)

[tools]                                # required, at least one entry
terraform = "= 1.10.5"                 # tool name from the floor registry = version constraint

[[tf_providers]]                       # optional, Terraform labs only
source  = "hashicorp/aws"
version = "= 6.71.0"

[needs]                                # optional
vendored = ["cargo"]                   # inputs the lab ships offline: cargo | go | npm | nix | uv
```

Unknown keys are errors, so a typo cannot silently drop a requirement.

**Kinds.** `fix`: ships broken, the grader fails until the student fixes it.
`explain`: ships correct, the grader is a regression check and the student
writes up why. `build`: the student builds from a starter. `example`: a guided
walkthrough with no grader.

### Version constraints

A constraint is `*` (any version) or comma-separated clauses, all of which must
hold. Versions are dotted numbers, up to four parts.

| Clause | Meaning |
|---|---|
| `1.18.0` or `= 1.18.0` | exactly 1.18.0 |
| `= 1.98` | any 1.98.x (a shorter version matches as a prefix) |
| `>= 1.7`, `> 1.7`, `<= 2.0`, `< 2.0`, `!= 1.9.0` | comparisons |
| `~> 6.0` | `>= 6.0, < 7.0` (Terraform-style pessimistic) |
| `~> 1.3.2` | `>= 1.3.2, < 1.4.0` |

Pre-release tags (`-rc1`) and caret ranges (`^1.2`) are rejected.

### Tool names

A manifest may only name a tool the floor knows: one in `[tools]`,
`[optional]`, or `[catalog]` of `image/floor.toml`. An unknown name fails
validation; add it to `[catalog]` first, with its pin and binaries, so the
image build knows how to install it. A name in `[retired]` (Ruby, Rails, R,
Deno) fails with the recorded reason. Bringing one back is a deliberate change
to the floor, not something a manifest can do.

## The floor: `image/floor.toml`

| Section | Meaning |
|---|---|
| `[vars]` | Named pins that are still open, referenced as `"${NAME}"` in a version. Override for a trial resolve with `LAB_VAR_<NAME>=value` |
| `[toggles]` | On/off switches for `[optional]` tools. Override with `LAB_TOGGLE_<NAME>=1` or `0` |
| `[tools.<name>]` | Always in the image |
| `[optional.<name>]` | In the image when its toggle is on, or when any lab declares it |
| `[catalog.<name>]` | Known, not in the image until a lab declares it; then it stays as long as one does |
| `[retired.<name>]` | Removed, with a `reason`. Declaring one is an error |
| `[[tf_mirror]]` | Terraform providers baked into the offline mirror (`/opt/tf-mirror`) |

Tool entries take `bins` (required: the commands it puts on `PATH`), and one of
`version` (exact), `status = "pending-pin"` (must be pinned before the image is
built; `validate` warns), or `source = "apt"` (distribution package, unpinned).
`note` is free text.

### Open pins

Two decisions are still open, so they are variables rather than fixed values:

- **Bun**: `BUN_VERSION` in `[vars]`, currently `1.3.14`. Moving to a 1.4+
  release is a one-line change; every lab that pins Bun is re-checked against
  the new value, and any lab that no longer fits fails validation by name.
- **OpenTofu, Fish, Lua**: `[toggles]` `opentofu`, `fish`, `lua`, all off. Each
  has a matching version variable (`OPENTOFU_VERSION`, `FISH_VERSION`,
  `LUA_VERSION`), empty until chosen. A lab may still declare one of these
  tools; it then enters the union regardless of the toggle.

Try a decision before making it:

```bash
LAB_VAR_BUN_VERSION=1.4.4 scripts/lab_manifest.py validate
LAB_TOGGLE_FISH=1 LAB_VAR_FISH_VERSION=4.2.1 scripts/lab_manifest.py union
```

## Union rules

1. The union is every floor `[tools]` entry, every `[optional]` entry whose
   toggle is on, and every `[optional]` or `[catalog]` entry that at least one
   manifest declares.
2. Each tool has one pinned version, taken from the floor. Every manifest's
   constraint on that tool must accept it. If one does not, validation fails
   and names the lab and its constraint. The resolver never picks a different
   version: a person changes the pin or updates the lab.
3. A tool with no pin yet (`pending-pin`, or an empty variable) is a warning
   now and must be pinned before an image is built from the union.
4. Offline Terraform: for a lab with `network = "none"`, every `tf_providers`
   constraint must be met by a mirrored provider. Exact three-part pins
   (`= 6.71.0`) from offline labs are added to the mirror automatically;
   ranges must be met by an existing mirror entry.

## Adding a lab

1. Write `lab.toml` in the lab's directory (see the table above).
2. Run `scripts/lab_manifest.py validate`.
3. If it names an unknown tool, add the tool to `[catalog]` in
   `image/floor.toml` with its pin and binaries.
4. If it reports a conflict, either change the lab's constraint or move the
   pin in the floor and re-check every lab that the new pin affects.
