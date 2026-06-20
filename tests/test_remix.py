"""Tests de XEK_remix (check-skill repo · aplicabilidad + emite xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_remix_repo, make_python_repo
from runners.base import RunnerContract


class TestRemixContract(RunnerContract):
    SCRIPT = "XEK_remix/scripts/xek-remix.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"

    def test_no_aplica_emite_skipped(self, run_script, tmp_path, validate_finding):
        repo = make_python_repo(tmp_path / "py")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 0, r.stderr
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_aplicable_corre_checks(self, run_script, tmp_path, validate_finding):
        repo = make_remix_repo(tmp_path / "remix")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        assert "skipped" not in r.json
        assert "remix-001" in [f["id"] for f in r.json["findings"]]
