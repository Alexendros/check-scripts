"""Tests de XEK_repo-higiene (check-skill · emite xek/finding@v1)."""
from __future__ import annotations

from pathlib import Path

import pytest

import fixtures_factory as ff
from runners.base import RunnerContract

SCRIPT = "XEK_repo-higiene/scripts/xek-repo-higiene.sh"


def script(repo_root: Path) -> Path:
    return repo_root / "skills" / SCRIPT


class TestRepoHigieneContract(RunnerContract):
    SCRIPT = SCRIPT
    EMITS = "finding"
    APPLIES_TO = "repo"

    @pytest.fixture
    def target(self, tmp_path: Path) -> list[str]:
        repo = ff.make_repo_limpio(tmp_path / "clean")
        return ["--target", str(repo)]


# ── Tests específicos ────────────────────────────────────────────────

def test_no_git_repo(run_script, repo_root, tmp_path):
    plano = tmp_path / "plano"
    plano.mkdir()
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(plano))
    assert r.returncode == 2
    assert "not a git repo" in r.stderr


def test_repo_limpio_sin_findings(run_script, repo_root, tmp_path,
                                  validate_finding):
    repo = ff.make_repo_limpio(tmp_path / "clean")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_finding(r.json)
    assert r.json["findings"] == []
    assert r.json["exit_code"] == 0


def test_repo_sucio_detecta_secreto(run_script, repo_root, tmp_path,
                                    validate_finding):
    repo = ff.make_repo_sucio(tmp_path / "dirty")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 1, r.stderr
    validate_finding(r.json)
    by_id = {f["id"]: f for f in r.json["findings"]}
    # .env versionado → repo-007 critical (con remediación).
    assert "repo-007" in by_id
    assert by_id["repo-007"]["severity"] == "critical"
    assert by_id["repo-007"].get("remediation")
    # Sin LICENSE → repo-002 high.
    assert by_id.get("repo-002", {}).get("severity") == "high"


def test_real_con_override_escribe_informe(run_script, repo_root, tmp_path,
                                           sandbox_env, validate_finding):
    repo = ff.make_repo_sucio(tmp_path / "dirty")
    r = run_script(script(repo_root), "--mode", "real", "--target", str(repo),
                   "--override-gate=AUTO_0")
    assert r.returncode == 1, r.stderr
    validate_finding(r.json)
    cuaderno = Path(sandbox_env["XEK_CUADERNO"])
    assert list(cuaderno.rglob("findings.json"))
    assert list(cuaderno.rglob("informe.md"))


def test_real_gate_sin_sandbox_previo(run_script, repo_root, tmp_path):
    repo = ff.make_repo_limpio(tmp_path / "clean")
    r = run_script(script(repo_root), "--mode", "real", "--target", str(repo))
    assert r.returncode == 2
    assert "gate" in r.stderr
