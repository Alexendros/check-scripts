"""Tests de XEK_a11y-web (artefacto HTML · aplicabilidad + xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_html_a11y_pobre
from runners.base import RunnerContract


class TestA11yWebContract(RunnerContract):
    SCRIPT = "XEK_a11y-web/scripts/xek-a11y-web.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"  # target=[] por defecto → ejercita la ruta skipped

    def test_sin_html_emite_skipped(self, run_script, validate_finding):
        r = run_script(self.script_path, "--mode", "sandbox")
        assert r.returncode == 0, r.stderr
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_html_pobre_emite_findings(self, run_script, tmp_path, validate_finding):
        html = make_html_a11y_pobre(tmp_path / "page.html")
        r = run_script(self.script_path, "--mode", "sandbox", "--target", str(html))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        assert "skipped" not in r.json
        ids = [f["id"] for f in r.json["findings"]]
        assert "a11y-001" in ids and "a11y-002" in ids
