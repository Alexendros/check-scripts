"""Tests de XEK_cookies (HTML + cabeceras · aplicabilidad + xek/finding@v1)."""
from __future__ import annotations

from fixtures_factory import make_html_cookies, make_headers_inseguras
from runners.base import RunnerContract


class TestCookiesContract(RunnerContract):
    SCRIPT = "XEK_cookies/scripts/xek-cookies.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"

    def test_sin_html_emite_skipped(self, run_script):
        r = run_script(self.script_path, "--mode", "sandbox")
        assert r.returncode == 0, r.stderr
        assert r.json.get("skipped", {}).get("razon") == "not_applicable"

    def test_html_y_cabeceras_inseguras(self, run_script, tmp_path, validate_finding):
        html = make_html_cookies(tmp_path / "page.html")
        hdr = make_headers_inseguras(tmp_path / "resp.headers")
        r = run_script(self.script_path, "--mode", "sandbox",
                       "--target", str(html), "--headers", str(hdr))
        assert r.returncode == 1, r.stderr
        validate_finding(r.json)
        ids = [f["id"] for f in r.json["findings"]]
        # banner + tracking script + Secure/HttpOnly/SameSite + Max-Age + tracking cookie
        assert "cookies-002" in ids and "cookies-008" in ids and "cookies-006" in ids
