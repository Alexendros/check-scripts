"""Tests de XEK_detecta-stack (runner real · emite xek/manifest@v2)."""
from __future__ import annotations

from pathlib import Path

import pytest

import fixtures_factory as ff
from runners.base import RunnerContract

SCRIPT = "XEK_detecta-stack/scripts/xek-detecta-stack.sh"


class TestDetectaStackContract(RunnerContract):
    SCRIPT = SCRIPT
    EMITS = "manifest"
    APPLIES_TO = "repo"

    @pytest.fixture
    def target(self, tmp_path: Path) -> list[str]:
        repo = ff.make_next_repo(tmp_path / "next")
        return ["--target", str(repo)]


# ── Tests específicos ────────────────────────────────────────────────

def script(repo_root: Path) -> Path:
    return repo_root / "skills" / SCRIPT


def test_target_inexistente(run_script, repo_root, tmp_path):
    r = run_script(script(repo_root), "--mode", "sandbox",
                   "--target", str(tmp_path / "no-existe"))
    assert r.returncode == 2
    assert "inexistente" in r.stderr


def test_dry_run_emite_target_tipo(run_script, repo_root, tmp_path):
    repo = ff.make_next_repo(tmp_path / "next")
    r = run_script(script(repo_root), "--mode", "dry-run", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    assert r.json["target_tipo"] == "repo"
    assert r.json["_meta"]["mode"] == "dry-run"


def test_sandbox_next_frameworks(run_script, repo_root, tmp_path, validate_manifest):
    repo = ff.make_next_repo(tmp_path / "next")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    nombres = {f["nombre"] for f in r.json["repo"]["frameworks"]}
    assert {"next", "react"} <= nombres
    assert r.json["repo"]["gestor_paquetes"] == "npm"
    assert "typescript" in r.json["repo"]["lenguajes"]
    assert r.json["repo"]["tooling"]["tester"] == ["vitest"]


def test_sandbox_python(run_script, repo_root, tmp_path, validate_manifest):
    repo = ff.make_python_repo(tmp_path / "py")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    assert r.json["target_tipo"] == "repo"
    assert "python" in r.json["repo"]["lenguajes"]
    assert r.json["repo"]["gestor_paquetes"] == "pip"


def test_sandbox_monorepo(run_script, repo_root, tmp_path, validate_manifest):
    repo = ff.make_monorepo(tmp_path / "mono")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    assert r.json["repo"]["tipo"] == "monorepo"
    assert r.json["repo"]["gestor_paquetes"] == "pnpm"


def test_sandbox_host(run_script, repo_root, validate_manifest):
    r = run_script(script(repo_root), "--mode", "sandbox", "--target-tipo", "host")
    assert r.returncode in (0, 1), r.stderr
    validate_manifest(r.json)
    assert r.json["target_tipo"] == "host"
    hh = r.json["host_huellas"]
    assert "distro_familia" in hh
    if r.returncode == 1:
        assert hh.get("_skipped"), "exit 1 debe traer _skipped poblado"


def test_real_gate_sin_sandbox_previo(run_script, repo_root, tmp_path):
    repo = ff.make_next_repo(tmp_path / "next")
    # XDG_RUNTIME_DIR virgen (sandbox_env) → no hay sandbox previo → gate exit 2.
    r = run_script(script(repo_root), "--mode", "real", "--target", str(repo))
    assert r.returncode == 2
    assert "gate" in r.stderr


def test_real_con_override(run_script, repo_root, tmp_path, sandbox_env,
                           validate_manifest):
    repo = ff.make_next_repo(tmp_path / "next")
    r = run_script(script(repo_root), "--mode", "real", "--target", str(repo),
                   "--override-gate=AUTO_0")
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    # manifest.json + informe.md escritos bajo XEK_CUADERNO (aislado en tmp_path).
    cuaderno = Path(sandbox_env["XEK_CUADERNO"])
    manifests = list(cuaderno.rglob("manifest.json"))
    informes = list(cuaderno.rglob("informe.md"))
    assert manifests and informes


# ── Regresión de heurísticas (validadas contra herramientas profesionales) ──

def test_p2_distro_id_presente(run_script, repo_root):
    """P2: host_huellas expone distro_id (ID crudo) además de distro_familia."""
    r = run_script(script(repo_root), "--mode", "sandbox", "--target-tipo", "host")
    hh = r.json["host_huellas"]
    assert isinstance(hh.get("distro_id"), str)
    assert hh["distro_familia"] in {
        "arch", "debian", "fedora", "nixos", "alpine", "gentoo", "unknown"}


def test_p3_bun_lock(run_script, repo_root, tmp_path, validate_manifest):
    """P3: bun.lock (texto, default Bun >=1.2) detecta gestor bun."""
    repo = ff.make_bun_repo(tmp_path / "bun")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    assert r.json["repo"]["gestor_paquetes"] == "bun"


def test_frameworks_sveltekit(run_script, repo_root, tmp_path, validate_manifest):
    """El metaframework @sveltejs/kit se detecta (no solo la librería svelte)."""
    repo = tmp_path / "svk"
    repo.mkdir()
    (repo / "package.json").write_text(
        '{"name":"svk","devDependencies":{"@sveltejs/kit":"^2.0.0",'
        '"svelte":"^4.0.0"}}', encoding="utf-8")
    r = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
    nombres = {f["nombre"] for f in r.json["repo"]["frameworks"]}
    assert "@sveltejs/kit" in nombres


def test_workspace_root_es_repo(run_script, repo_root, tmp_path):
    """Un workspace-root con solo pnpm-workspace.yaml clasifica como repo, no host."""
    repo = tmp_path / "ws"
    repo.mkdir()
    (repo / "pnpm-workspace.yaml").write_text("packages:\n  - 'pkgs/*'\n",
                                              encoding="utf-8")
    r = run_script(script(repo_root), "--mode", "dry-run", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    assert r.json["target_tipo"] == "repo"


def test_real_tras_sandbox_pasa_gate(run_script, repo_root, tmp_path,
                                     validate_manifest):
    repo = ff.make_next_repo(tmp_path / "next")
    # Primero sandbox (crea el dir reciente) → luego real sin override pasa el gate.
    s = run_script(script(repo_root), "--mode", "sandbox", "--target", str(repo))
    assert s.returncode == 0, s.stderr
    r = run_script(script(repo_root), "--mode", "real", "--target", str(repo))
    assert r.returncode == 0, r.stderr
    validate_manifest(r.json)
