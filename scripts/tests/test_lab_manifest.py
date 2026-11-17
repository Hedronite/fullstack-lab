"""Tests for scripts/lab_manifest.py. Run: python3 -m unittest discover -s scripts/tests"""
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import lab_manifest as lm  # noqa: E402

REPO = HERE.parent.parent

LAB = '''schema = "hedronite.lab/v1"
[lab]
id = "{id}"
title = "t"
kind = "build"
family = "bun"
[grade]
backend = "manual"
network = "{network}"
[tools]
{tools}
'''


class Fixture(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / "image").mkdir()
        shutil.copy(REPO / "image" / "floor.toml", self.root / "image" / "floor.toml")
        self.n = 0

    def tearDown(self):
        shutil.rmtree(self.root)

    def lab(self, tools, lab_id=None, network="egress", extra=""):
        self.n += 1
        d = self.root / "labs-examples" / f"l{self.n}"
        d.mkdir(parents=True)
        (d / "lab.toml").write_text(LAB.format(id=lab_id or f"lab-{self.n}",
                                               network=network, tools=tools) + extra)

    def run_lm(self, env=None):
        e = lm.Errors()
        with mock.patch.dict(os.environ, env or {}, clear=False):
            union = lm.run(self.root, [], e)
        return union, e


class Constraints(unittest.TestCase):
    def test_satisfies(self):
        p = lm.parse_constraint
        self.assertTrue(lm.satisfies("1.10.5", p(">= 1.7, < 2.0")))
        self.assertFalse(lm.satisfies("1.6.0", p(">= 1.7, < 2.0")))
        self.assertTrue(lm.satisfies("6.71.0", p("~> 6.0")))
        self.assertFalse(lm.satisfies("7.0.0", p("~> 6.0")))
        self.assertTrue(lm.satisfies("1.3.14", p("~> 1.3.2")))
        self.assertFalse(lm.satisfies("1.4.0", p("~> 1.3.2")))
        self.assertTrue(lm.satisfies("1.98", p("= 1.98")))
        self.assertTrue(lm.satisfies("1.98.1", p("= 1.98")))
        self.assertFalse(lm.satisfies("1.98", p("= 1.98.1")))
        self.assertEqual(p("*"), [])
        self.assertIsNone(p("latest"))
        self.assertIsNone(p("^1.2"))


class Validation(Fixture):
    def test_repository_manifests_pass(self):
        e = lm.Errors()
        union = lm.run(REPO, [], e)
        self.assertEqual(e.errors, [])
        for gone in ("ruby", "rails", "r"):
            self.assertNotIn(gone, union["tools"])
        for need in ("gleam", "bun", "nickel", "nushell", "nix", "rust", "uv",
                     "python", "go", "terraform", "kubectl", "helm", "jq"):
            self.assertIn(need, union["tools"])

    def test_retired_tool_fails(self):
        self.lab('ruby = "*"')
        _, e = self.run_lm()
        self.assertTrue(any("retired" in m for m in e.errors), e.errors)

    def test_unknown_tool_fails(self):
        self.lab('cobol = "*"')
        _, e = self.run_lm()
        self.assertTrue(any("unknown tool" in m for m in e.errors), e.errors)

    def test_conflict_fails_and_names_the_lab(self):
        self.lab('bun = "= 1.4.4"', lab_id="bun-new")
        _, e = self.run_lm()
        self.assertTrue(any("bun-new" in m and "does not satisfy" in m for m in e.errors), e.errors)

    def test_bun_pin_is_a_variable(self):
        self.lab('bun = "= 1.4.4"')
        _, e = self.run_lm({"LAB_VAR_BUN_VERSION": "1.4.4"})
        self.assertEqual(e.errors, [])
        self.lab('bun = "= 1.3.14"', lab_id="bun-old")
        _, e = self.run_lm({"LAB_VAR_BUN_VERSION": "1.4.4"})
        self.assertTrue(any("bun-old" in m for m in e.errors), e.errors)

    def test_optional_tools_default_off(self):
        union, e = self.run_lm()
        for name in ("opentofu", "fish", "lua"):
            self.assertNotIn(name, union["tools"])
        union, e = self.run_lm({"LAB_TOGGLE_OPENTOFU": "1"})
        self.assertIn("opentofu", union["tools"])

    def test_catalog_tool_enters_through_a_lab(self):
        union, _ = self.run_lm()
        self.assertNotIn("bend", union["tools"])
        self.lab('bend = "= 2.0.36"')
        union, e = self.run_lm()
        self.assertEqual(e.errors, [])
        self.assertIn("bend", union["tools"])

    def test_duplicate_id_fails(self):
        self.lab('jq = "*"', lab_id="same")
        self.lab('jq = "*"', lab_id="same")
        _, e = self.run_lm()
        self.assertTrue(any("already used" in m for m in e.errors), e.errors)

    def test_offline_provider_must_be_mirrored(self):
        self.lab('terraform = "*"', network="none",
                 extra='[[tf_providers]]\nsource = "hashicorp/google"\nversion = "~> 6.0"\n')
        _, e = self.run_lm()
        self.assertTrue(any("no mirrored hashicorp/google" in m for m in e.errors), e.errors)

    def test_missing_manifest_fails_coverage(self):
        (self.root / "labs-examples" / "bare").mkdir(parents=True)
        _, e = self.run_lm()
        self.assertTrue(any("has no lab.toml" in m for m in e.errors), e.errors)


if __name__ == "__main__":
    unittest.main()
