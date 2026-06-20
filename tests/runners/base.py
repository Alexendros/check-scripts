"""Contrato de tests reutilizable para cualquier runner XEK.

Cada runner nuevo hereda `RunnerContract`, fija `SCRIPT`/`EMITS`/`APPLIES_TO` y
provee un fixture `target` con los argumentos de target. Obtiene gratis los tests
de contrato (exit codes, dry-run sin escritura, preflight, conformidad de esquema).
"""
from __future__ import annotations

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = REPO_ROOT / "skills"


class RunnerContract:
    #: Ruta al script, relativa a skills/ (p.ej. "XEK_detecta-stack/scripts/xek-detecta-stack.sh").
    SCRIPT: str = ""
    #: Esquema que emite en sandbox: "manifest" | "finding".
    EMITS: str = "finding"
    #: Tipo de target que aplica: "repo" | "host".
    APPLIES_TO: str = "repo"

    @property
    def script_path(self) -> Path:
        assert self.SCRIPT, "subclase debe fijar SCRIPT"
        return SKILLS_DIR / self.SCRIPT

    @pytest.fixture
    def target(self) -> list[str]:
        """Argumentos de target para sandbox/dry-run. Override en subclases."""
        if self.APPLIES_TO == "host":
            return ["--target-tipo", "host"]
        return []

    def _validate_emitted(self, obj, validate_manifest, validate_finding):
        if self.EMITS == "manifest":
            validate_manifest(obj)
        else:
            validate_finding(obj)

    # ── Contrato común ────────────────────────────────────────────────
    def test_missing_mode(self, run_script):
        r = run_script(self.script_path)
        assert r.returncode == 3, r.stderr

    def test_bad_mode(self, run_script):
        r = run_script(self.script_path, "--mode", "bogus")
        assert r.returncode == 4, r.stderr

    def test_ill_call(self, run_script):
        r = run_script(self.script_path, "--mode", "dry-run", "--flag-desconocida")
        assert r.returncode == 4, r.stderr

    def test_dry_run_no_writes(self, run_script, target, assert_no_disk_writes):
        with assert_no_disk_writes():
            r = run_script(self.script_path, "--mode", "dry-run", *target)
        assert r.returncode == 0, r.stderr

    def test_preflight_fail(self, run_script, target, path_without_jq):
        # jq ausente (binario requerido) → preflight falla → exit 2.
        r = run_script(self.script_path, "--mode", "dry-run", *target,
                       env_overrides={"PATH": path_without_jq})
        assert r.returncode == 2, r.stderr

    def test_sandbox_emits_valid(self, run_script, target,
                                 validate_manifest, validate_finding):
        r = run_script(self.script_path, "--mode", "sandbox", *target)
        assert r.returncode in (0, 1), r.stderr
        self._validate_emitted(r.json, validate_manifest, validate_finding)

    def test_real_gate_sin_sandbox_previo(self, run_script, target):
        # XDG_RUNTIME_DIR virgen → no hay sandbox previo → gate exit 2.
        r = run_script(self.script_path, "--mode", "real", *target)
        assert r.returncode == 2, r.stderr
        assert "gate" in r.stderr

    def test_real_con_override_emite_valido(self, run_script, target,
                                            validate_manifest, validate_finding):
        r = run_script(self.script_path, "--mode", "real", *target,
                       "--override-gate=AUTO_0")
        assert r.returncode in (0, 1), r.stderr
        self._validate_emitted(r.json, validate_manifest, validate_finding)
