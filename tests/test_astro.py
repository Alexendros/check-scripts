"""Tests de XEK_astro (check-skill repo · aplicabilidad + emite xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_astro_repo, make_python_repo
from runners.base import RunnerContract


class TestAstroContract(RunnerContract):
    SCRIPT = "XEK_astro/scripts/xek-astro.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"

    def test_no_aplica_emite_skipped(self, run_script, tmp_path, validate_finding):
        repo = make_python_repo(tmp_path / "py")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 0, r.stderr
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_aplicable_detecta_output_sin_adapter(self, run_script, tmp_path, validate_finding):
        repo = make_astro_repo(tmp_path / "astro")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(repo))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        assert "skipped" not in r.json
        assert "astro-004" in [f["id"] for f in r.json["findings"]]
