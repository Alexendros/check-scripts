"""Tests de XEK_perf-web (artefacto HTML · aplicabilidad + xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_html_perf_pobre
from runners.base import RunnerContract


class TestPerfWebContract(RunnerContract):
    SCRIPT = "XEK_perf-web/scripts/xek-perf-web.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"

    def test_sin_html_emite_skipped(self, run_script):
        r = run_script(self.script_path, "--mode", "sandbox")
        assert r.returncode == 0, r.stderr
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_html_pobre_emite_findings(self, run_script, tmp_path, validate_finding):
        html = make_html_perf_pobre(tmp_path / "page.html")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(html))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        ids = [f["id"] for f in r.json["findings"]]
        assert "perf-002" in ids and "perf-003" in ids
