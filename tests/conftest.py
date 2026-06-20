"""Fixtures y helpers compartidos de la testera XEK.

Aísla cada ejecución del script bajo un `tmp_path` propio: `XDG_RUNTIME_DIR`
(base del sandbox), `HOME` y `XEK_CUADERNO` (destino del modo real) se redirigen
ahí, de forma que ninguna ejecución toca disco real.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import jsonschema
import pytest

from schemas import finding_schema, manifest_schema

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / "skills"
# Ruta absoluta a bash: permite ejecutar incluso con PATH vacío (test de preflight).
BASH = shutil.which("bash") or "/bin/bash"


@dataclass
class RunResult:
    """Resultado de una invocación de script."""

    returncode: int
    stdout: str
    stderr: str

    @property
    def json(self) -> dict:
        """Parsea stdout como JSON (los runners emiten el documento por stdout)."""
        return json.loads(self.stdout)


@pytest.fixture
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture
def sandbox_env(tmp_path: Path) -> dict:
    """Entorno base aislado: sandbox y modo real escriben solo bajo tmp_path."""
    xdg = tmp_path / "xdg"
    home = tmp_path / "home"
    cuaderno = tmp_path / "cuaderno"
    for d in (xdg, home, cuaderno):
        d.mkdir(parents=True, exist_ok=True)
    return {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "XDG_RUNTIME_DIR": str(xdg),
        "HOME": str(home),
        "XEK_CUADERNO": str(cuaderno),
        # Entorno gráfico vacío → detección de host determinista (tty/none).
        "LC_ALL": "C",
    }


@pytest.fixture
def run_script(sandbox_env: dict):
    """Devuelve un invocador `run(script, *args, env_overrides=None, cwd=None)`."""

    def run(script: Path | str, *args: str, env_overrides: dict | None = None,
            cwd: Path | str | None = None) -> RunResult:
        env = dict(sandbox_env)
        if env_overrides:
            env.update(env_overrides)
        proc = subprocess.run(
            [BASH, str(script), *map(str, args)],
            capture_output=True, text=True, timeout=60, env=env,
            cwd=str(cwd) if cwd else None,
        )
        return RunResult(proc.returncode, proc.stdout, proc.stderr)

    return run


@pytest.fixture
def path_without_jq(tmp_path: Path) -> str:
    """PATH con todos los binarios reales salvo `jq` → fuerza fallo de preflight.

    Mantiene date/mkdir/find/grep/git disponibles (usados antes de preflight),
    de modo que el único faltante sea un binario requerido (jq).
    """
    bindir = tmp_path / "bin_no_jq"
    bindir.mkdir(parents=True, exist_ok=True)
    for d in os.environ.get("PATH", "").split(os.pathsep):
        if not d or not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name == "jq":
                continue
            link = bindir / name
            if not link.exists():
                try:
                    link.symlink_to(os.path.join(d, name))
                except OSError:
                    pass
    return str(bindir)


@pytest.fixture
def validate_manifest():
    def _v(obj: dict) -> None:
        jsonschema.validate(obj, manifest_schema())
    return _v


@pytest.fixture
def validate_finding():
    def _v(obj: dict) -> None:
        jsonschema.validate(obj, finding_schema())
    return _v


@pytest.fixture
def assert_no_disk_writes(tmp_path: Path):
    """Verifica que un bloque no crea ficheros nuevos bajo tmp_path."""
    from contextlib import contextmanager

    @contextmanager
    def _checker():
        before = set(tmp_path.rglob("*"))
        yield
        after = set(tmp_path.rglob("*"))
        new = {p for p in (after - before) if p.is_file()}
        assert not new, f"dry-run escribió ficheros: {sorted(map(str, new))}"

    return _checker
