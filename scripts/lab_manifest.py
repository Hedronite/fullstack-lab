#!/usr/bin/env python3
"""Validate lab.toml manifests and resolve the lab image toolchain union.

    scripts/lab_manifest.py validate [--root DIR] [MANIFEST ...]
    scripts/lab_manifest.py union    [--root DIR] [--format json|args]

validate  checks image/floor.toml and every lab.toml (or only the ones given),
          checks that every lab in the repository has exactly one manifest,
          and resolves the union. Any error, including a version conflict,
          exits 1.
union     prints the resolved union: the floor plus every tool any lab
          declares, with the version that will be installed. Exits 1 on a
          conflict; it never picks a version on its own.

Open pins live in image/floor.toml [vars] and [toggles]. Override them for a
trial resolve with LAB_VAR_<NAME>=value and LAB_TOGGLE_<NAME>=1|0.

Python 3.11+ standard library only. Exit codes: 0 ok, 1 invalid, 2 usage.
See docs/lab-toml.md for the format.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tomllib
from pathlib import Path

FLOOR_SCHEMA = "hedronite.lab.floor/v1"
LAB_SCHEMA = "hedronite.lab/v1"
FLOOR_PATH = Path("image/floor.toml")
MANIFEST_NAME = "lab.toml"

KINDS = {"fix", "explain", "build", "example"}
FAMILIES = {"terraform", "kubernetes", "observability", "rust", "ops", "bun",
            "gleam", "python", "go", "nix", "polyglot"}
BACKENDS = {"terraform-test", "check-sh", "manual", "none"}
NETWORK = {"none", "egress"}
VENDORED = {"cargo", "go", "npm", "nix", "uv"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9.-]{0,63}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
VERSION_RE = re.compile(r"^\d+(\.\d+){0,3}$")
VAR_RE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)\}")
CLAUSE_RE = re.compile(r"^(=|!=|>=|<=|>|<|~>)?\s*(\d+(?:\.\d+){0,3})$")
PROVIDER_RE = re.compile(r"^[a-z0-9-]+/[a-z0-9-]+$")
# Directories never scanned for manifests (third-party sources, build output).
SKIP_DIRS = {".git", "upstream", "node_modules", "target", ".terraform"}


class Errors:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, where: str, msg: str) -> None:
        self.errors.append(f"ERROR {where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"WARN  {where}: {msg}")


# ------------------------------------------------------------------ versions
def vtuple(v: str) -> tuple[int, ...]:
    parts = [int(p) for p in v.split(".")]
    return tuple(parts + [0] * (4 - len(parts)))


def parse_constraint(text: str) -> list[tuple[str, str]] | None:
    """'>= 1.6, < 2.0' -> [('>=','1.6'), ('<','2.0')]; '*' -> []; None if invalid."""
    text = text.strip()
    if text == "*":
        return []
    clauses = []
    for raw in text.split(","):
        m = CLAUSE_RE.match(raw.strip())
        if not m:
            return None
        clauses.append((m.group(1) or "=", m.group(2)))
    return clauses or None


def satisfies(version: str, clauses: list[tuple[str, str]]) -> bool:
    v = vtuple(version)
    for op, ref in clauses:
        r = vtuple(ref)
        if op == "=":
            # "=1.98" matches 1.98 and 1.98.x; "=1.98.1" matches only 1.98.1.
            n = len(ref.split("."))
            if v[:n] != r[:n]:
                return False
        elif op == "!=" and v == r:
            return False
        elif op == ">=" and not v >= r:
            return False
        elif op == "<=" and not v <= r:
            return False
        elif op == ">" and not v > r:
            return False
        elif op == "<" and not v < r:
            return False
        elif op == "~>":
            n = len(ref.split("."))
            if n < 2:
                upper = (r[0] + 1, 0, 0, 0)
            else:
                head = list(r[: n - 1])
                head[-1] += 1
                upper = tuple(head + [0] * (4 - len(head)))
            if not (r <= v < upper):
                return False
    return True


# --------------------------------------------------------------------- floor
def load_toml(path: Path, e: Errors) -> dict | None:
    try:
        with path.open("rb") as fh:
            return tomllib.load(fh)
    except FileNotFoundError:
        e.err(str(path), "file not found")
    except tomllib.TOMLDecodeError as exc:
        e.err(str(path), f"not valid TOML: {exc}")
    return None


def env_bool(name: str, default: bool, e: Errors) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    if raw in {"1", "true", "on", "yes"}:
        return True
    if raw in {"0", "false", "off", "no"}:
        return False
    e.err(name, f"expected 1 or 0, got {raw!r}")
    return default


def load_floor(root: Path, e: Errors) -> dict | None:
    where = str(FLOOR_PATH)
    data = load_toml(root / FLOOR_PATH, e)
    if data is None:
        return None
    if data.get("schema") != FLOOR_SCHEMA:
        e.err(where, f"schema must be {FLOOR_SCHEMA!r}")
    known_top = {"schema", "vars", "toggles", "tools", "optional", "catalog",
                 "retired", "tf_mirror"}
    for key in data:
        if key not in known_top:
            e.err(where, f"unknown top-level key {key!r}")

    variables = {}
    for name, value in data.get("vars", {}).items():
        if not re.match(r"^[A-Z][A-Z0-9_]*$", name) or not isinstance(value, str):
            e.err(where, f"[vars] {name}: names are UPPER_SNAKE, values are strings")
            continue
        variables[name] = os.environ.get(f"LAB_VAR_{name}", value)

    toggles = {}
    for name, value in data.get("toggles", {}).items():
        if not isinstance(value, bool):
            e.err(where, f"[toggles] {name}: must be true or false")
            continue
        toggles[name] = env_bool(f"LAB_TOGGLE_{name.upper()}", value, e)

    registry: dict[str, dict] = {}
    for section in ("tools", "optional", "catalog"):
        for name, spec in data.get(section, {}).items():
            w = f"{where} [{section}.{name}]"
            if name in registry:
                e.err(w, f"tool also defined in [{registry[name]['section']}]")
                continue
            if not isinstance(spec, dict):
                e.err(w, "must be a table")
                continue
            allowed = {"version", "status", "source", "bins", "note", "toggle"}
            for k in spec:
                if k not in allowed:
                    e.err(w, f"unknown key {k!r}")
            bins = spec.get("bins")
            if not (isinstance(bins, list) and bins and all(isinstance(b, str) for b in bins)):
                e.err(w, "bins must be a non-empty list of command names")
            version = resolve_vars(spec.get("version"), variables, w, e)
            status = spec.get("status")
            source = spec.get("source")
            if status not in (None, "pending-pin"):
                e.err(w, "status may only be 'pending-pin'")
            if version is None and status is None and source != "apt":
                e.err(w, "needs a version, status = 'pending-pin', or source = 'apt'")
            if version is not None and version != "" and not VERSION_RE.match(version):
                e.err(w, f"version {version!r} is not a dotted numeric version")
            toggle = spec.get("toggle")
            if section == "optional":
                if toggle not in toggles:
                    e.err(w, f"toggle {toggle!r} is not defined in [toggles]")
            elif toggle is not None:
                e.err(w, "only [optional] tools take a toggle")
            registry[name] = {
                "section": section,
                "version": version or None,
                "source": source,
                "pending": status == "pending-pin" or version == "",
                "bins": bins or [],
                "toggle": toggle,
            }

    retired = {}
    for name, spec in data.get("retired", {}).items():
        if name in registry:
            e.err(where, f"{name!r} is both retired and in [{registry[name]['section']}]")
        if not (isinstance(spec, dict) and isinstance(spec.get("reason"), str)):
            e.err(where, f"[retired.{name}] needs a reason")
            continue
        retired[name] = spec["reason"]

    mirror = []
    for i, entry in enumerate(data.get("tf_mirror", [])):
        src, ver = entry.get("source"), entry.get("version")
        if not (isinstance(src, str) and PROVIDER_RE.match(src)):
            e.err(where, f"tf_mirror[{i}].source must look like namespace/name")
            continue
        if not (isinstance(ver, str) and VERSION_RE.match(ver)):
            e.err(where, f"tf_mirror[{i}].version must be an exact version")
            continue
        mirror.append((src, ver))

    return {"vars": variables, "toggles": toggles, "registry": registry,
            "retired": retired, "mirror": mirror}


def resolve_vars(value, variables: dict, where: str, e: Errors):
    if value is None:
        return None
    if not isinstance(value, str):
        e.err(where, "version must be a string")
        return None

    def sub(m: re.Match) -> str:
        name = m.group(1)
        if name not in variables:
            e.err(where, f"undefined variable ${{{name}}}")
            return ""
        return variables[name]

    return VAR_RE.sub(sub, value)


# ----------------------------------------------------------------- manifests
def load_manifest(path: Path, root: Path, floor: dict, e: Errors) -> dict | None:
    where = rel(path, root)
    data = load_toml(path, e)
    if data is None:
        return None
    if data.get("schema") != LAB_SCHEMA:
        e.err(where, f"schema must be {LAB_SCHEMA!r}")
    for key in data:
        if key not in {"schema", "lab", "grade", "tools", "tf_providers", "needs"}:
            e.err(where, f"unknown top-level key {key!r}")

    lab = data.get("lab")
    if not isinstance(lab, dict):
        e.err(where, "missing [lab] table")
        return None
    for k in lab:
        if k not in {"id", "title", "kind", "family", "date", "aliases", "source"}:
            e.err(where, f"[lab] unknown key {k!r}")
    lab_id = lab.get("id")
    if not (isinstance(lab_id, str) and ID_RE.match(lab_id)):
        e.err(where, "[lab] id must match ^[a-z0-9][a-z0-9.-]{0,63}$")
        lab_id = None
    if not (isinstance(lab.get("title"), str) and lab["title"].strip()):
        e.err(where, "[lab] title is required")
    if lab.get("kind") not in KINDS:
        e.err(where, f"[lab] kind must be one of {sorted(KINDS)}")
    if lab.get("family") not in FAMILIES:
        e.err(where, f"[lab] family must be one of {sorted(FAMILIES)}")
    if "date" in lab and not (isinstance(lab["date"], str) and DATE_RE.match(lab["date"])):
        e.err(where, "[lab] date must be YYYY-MM-DD (a string)")
    aliases = lab.get("aliases", [])
    if not (isinstance(aliases, list) and all(isinstance(a, str) and ID_RE.match(a) for a in aliases)):
        e.err(where, "[lab] aliases must be a list of ids")
        aliases = []
    if "source" in lab:
        src = lab["source"]
        if not isinstance(src, str) or src.startswith("/") or ".." in Path(src).parts:
            e.err(where, "[lab] source must be a repo-relative path")
        elif not (root / src).exists():
            e.err(where, f"[lab] source {src!r} does not exist (submodule not initialised?)")

    grade = data.get("grade")
    network = None
    if not isinstance(grade, dict):
        e.err(where, "missing [grade] table")
    else:
        for k in grade:
            if k not in {"backend", "entry", "network"}:
                e.err(where, f"[grade] unknown key {k!r}")
        if grade.get("backend") not in BACKENDS:
            e.err(where, f"[grade] backend must be one of {sorted(BACKENDS)}")
        network = grade.get("network")
        if network not in NETWORK:
            e.err(where, f"[grade] network must be one of {sorted(NETWORK)}")
        entry = grade.get("entry")
        if grade.get("backend") in {"terraform-test", "check-sh"}:
            if not isinstance(entry, str):
                e.err(where, "[grade] entry is required for this backend")
            elif not (root / entry).is_file():
                e.err(where, f"[grade] entry {entry!r} is not a file")

    tools = data.get("tools")
    declared: dict[str, list[tuple[str, str]]] = {}
    if not isinstance(tools, dict) or not tools:
        e.err(where, "[tools] must declare at least one tool")
        tools = {}
    for name, constraint in tools.items():
        if name in floor["retired"]:
            e.err(where, f"tool {name!r} is retired ({floor['retired'][name]}); "
                         "reinstating it is a human decision recorded in image/floor.toml")
            continue
        if name not in floor["registry"]:
            e.err(where, f"unknown tool {name!r}; add it to image/floor.toml [catalog] first")
            continue
        if not isinstance(constraint, str):
            e.err(where, f"tool {name!r}: constraint must be a string")
            continue
        clauses = parse_constraint(constraint)
        if clauses is None:
            e.err(where, f"tool {name!r}: cannot parse constraint {constraint!r}")
            continue
        declared[name] = clauses

    providers = []
    for i, p in enumerate(data.get("tf_providers", [])):
        src, ver = p.get("source"), p.get("version")
        if not (isinstance(src, str) and PROVIDER_RE.match(src)):
            e.err(where, f"tf_providers[{i}].source must look like namespace/name")
            continue
        clauses = parse_constraint(ver) if isinstance(ver, str) else None
        if clauses is None:
            e.err(where, f"tf_providers[{i}].version cannot be parsed")
            continue
        providers.append((src, ver, clauses))
    if providers and "terraform" not in declared:
        e.err(where, "tf_providers given but terraform is not in [tools]")

    needs = data.get("needs", {})
    vendored = needs.get("vendored", []) if isinstance(needs, dict) else []
    if not isinstance(needs, dict) or any(k != "vendored" for k in needs):
        e.err(where, "[needs] only takes 'vendored'")
    if not (isinstance(vendored, list) and all(v in VENDORED for v in vendored)):
        e.err(where, f"[needs] vendored must be a list drawn from {sorted(VENDORED)}")

    return {"path": where, "id": lab_id, "aliases": aliases, "network": network,
            "tools": declared, "raw_tools": tools, "providers": providers}


# --------------------------------------------------------------- discovery
def rel(path: Path, root: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path)


def find_manifests(root: Path) -> list[Path]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        if MANIFEST_NAME in filenames:
            found.append(Path(dirpath) / MANIFEST_NAME)
    return sorted(found)


def check_coverage(root: Path, e: Errors) -> None:
    """Every lab in the repository has exactly one manifest."""
    reported: set[Path] = set()  # lab dirs already flagged through labs.txt
    # Labs listed in a labs.txt: manifest in graders/<name>/ or in the local lab dir.
    for labs_txt in sorted(root.glob("curriculum/*/*/labs.txt")):
        base = labs_txt.parent
        for line in labs_txt.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = line.split()
            name, src = fields[0], (fields[1] if len(fields) > 1 else "")
            spots = [base / "graders" / name / MANIFEST_NAME]
            if src.startswith("local:"):
                local = (base / src[len("local:"):]).parent  # local:<lab>/starter
                spots.append(local / MANIFEST_NAME)
            have = [s for s in spots if s.is_file()]
            where = f"{rel(labs_txt, root)} {name}"
            if not have:
                reported.add((base / "labs" / name).resolve())
                e.err(where, "no lab.toml (expected in " +
                      " or ".join(rel(s, root) for s in spots) + ")")
            elif len(have) > 1:
                e.err(where, "more than one lab.toml: " + ", ".join(rel(s, root) for s in have))
    # Hedronite-authored lab directories.
    for d in sorted(root.glob("curriculum/*/*/labs/*/")):
        if (d / "check.sh").is_file() or (d / "starter").is_dir():
            grader = d.parent.parent / "graders" / d.name / MANIFEST_NAME
            if d.resolve() in reported:
                continue
            if not (d / MANIFEST_NAME).is_file() and not grader.is_file():
                e.err(rel(d, root), "lab directory has no lab.toml")
    # Examples.
    for d in sorted(root.glob("labs-examples/*/")):
        if d.is_dir() and not (d / MANIFEST_NAME).is_file():
            e.err(rel(d, root), "example directory has no lab.toml")


# -------------------------------------------------------------------- union
def resolve_union(floor: dict, labs: list[dict], e: Errors) -> dict:
    reg = floor["registry"]
    wanted: dict[str, list[tuple[str, str, str]]] = {}  # tool -> [(lab, text, clauses)]
    for lab in labs:
        for name, clauses in lab["tools"].items():
            wanted.setdefault(name, []).append((lab["id"] or lab["path"], lab["raw_tools"][name], clauses))

    tools = {}
    for name, spec in reg.items():
        section = spec["section"]
        reasons = []
        if section == "tools":
            reasons.append("floor")
        elif section == "optional" and floor["toggles"].get(spec["toggle"]):
            reasons.append(f"toggle:{spec['toggle']}")
        users = wanted.get(name, [])
        if users:
            reasons.append("labs")
        if not reasons:
            continue
        version = spec["version"]
        if spec["pending"] or (version is None and spec["source"] != "apt"):
            e.warn(f"union {name}", "version not pinned yet (pending-pin); "
                   "it must be pinned before the image is built")
            version = None
        if version is not None:
            for lab_id, text, clauses in users:
                if not satisfies(version, clauses):
                    e.err(f"union {name}", f"{version} does not satisfy {lab_id} "
                          f"({text!r}); change the pin or the lab, CI does not choose")
        tools[name] = {
            "version": version,
            "source": spec["source"] or "upstream",
            "bins": spec["bins"],
            "why": reasons,
            "labs": sorted(u[0] for u in users),
        }

    mirror = set(floor["mirror"])
    for lab in labs:
        if lab["network"] != "none":
            continue
        for src, text, clauses in lab["providers"]:
            if len(clauses) == 1 and clauses[0][0] == "=" and len(clauses[0][1].split(".")) == 3:
                mirror.add((src, clauses[0][1]))
    for lab in labs:
        if lab["network"] != "none":
            continue
        for src, text, clauses in lab["providers"]:
            if not any(s == src and satisfies(v, clauses) for s, v in mirror):
                e.err(lab["path"], f"network = 'none' but no mirrored {src} satisfies {text!r}")

    return {
        "schema": "hedronite.lab.union/v1",
        "vars": floor["vars"],
        "toggles": floor["toggles"],
        "tools": dict(sorted(tools.items())),
        "tf_mirror": [{"source": s, "version": v} for s, v in sorted(mirror)],
        "labs": sorted(l["id"] for l in labs if l["id"]),
    }


def run(root: Path, paths: list[str], e: Errors) -> dict | None:
    floor = load_floor(root, e)
    if floor is None:
        return None
    manifests = [Path(p) for p in paths] if paths else find_manifests(root)
    if not paths:
        check_coverage(root, e)
    labs = [m for m in (load_manifest(p, root, floor, e) for p in manifests) if m]
    seen: dict[str, str] = {}
    for lab in labs:
        for ident in ([lab["id"]] if lab["id"] else []) + lab["aliases"]:
            if ident in seen:
                e.err(lab["path"], f"id or alias {ident!r} already used by {seen[ident]}")
            seen[ident] = lab["path"]
    union = resolve_union(floor, labs, e)
    union["_manifests"] = len(labs)
    return union


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate")
    v.add_argument("--root", default=".")
    v.add_argument("manifests", nargs="*")
    u = sub.add_parser("union")
    u.add_argument("--root", default=".")
    u.add_argument("--format", choices=["json", "args"], default="json")
    args = ap.parse_args(argv)

    root = Path(args.root)
    e = Errors()
    union = run(root, getattr(args, "manifests", []), e)
    for w in e.warnings:
        print(w, file=sys.stderr)
    for msg in e.errors:
        print(msg, file=sys.stderr)
    if union is None or e.errors:
        print(f"FAIL {len(e.errors)} error(s)", file=sys.stderr)
        return 1
    count = union.pop("_manifests")
    if args.cmd == "validate":
        print(f"OK {count} manifest(s), {len(union['tools'])} tool(s) in the union, "
              f"{len(e.warnings)} warning(s)")
    elif args.format == "json":
        print(json.dumps(union, indent=2))
    else:
        for name, t in union["tools"].items():
            if t["version"]:
                print(f"{name.upper().replace('-', '_')}_VERSION={t['version']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
