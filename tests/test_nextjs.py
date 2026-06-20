"""Tests de XEK_nextjs (check-skill repo · aplicabilidad + emite xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_next_repo, make_python_repo
from runners.base import RunnerContract


class TestNextjsContract(RunnerContract):
    SCRIPT = "XEK_nextjs/scripts/xek-nextjs.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"

    def test_no_aplica_emite_skipped(self, run_script, tmp_path, validate_finding):
        repo = make_python_repo(tmp_path / "py")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 0, r.stderr
        validate_finding(r.json)
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_aplicable_corre_checks(self, run_script, tmp_path, validate_finding):
        repo = make_next_repo(tmp_path / "next")  # sin next.config → nextjs-001
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        assert "skipped" not in r.json
        assert "nextjs-001" in [f["id"] for f in r.json["findings"]]
