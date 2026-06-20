"""Builders de repositorios sintéticos para los tests.

Cada builder materializa un árbol mínimo bajo un directorio temporal y devuelve
su `Path`. Los builders que dependen del índice git inicializan un repo aislado.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

_GIT_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
}


def git_init(path: Path) -> None:
    """Inicializa un repo git aislado con un commit, sin depender de config global."""
    import os
    env = {**os.environ, **_GIT_ENV}
    subprocess.run(["git", "init", "-q", str(path)], check=True, env=env)
    subprocess.run(["git", "-C", str(path), "add", "-A"], check=True, env=env)
    subprocess.run(["git", "-C", str(path), "commit", "-q", "-m", "init"],
                   check=True, env=env)


def make_next_repo(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(json.dumps({
        "name": "demo-next",
        "dependencies": {"next": "^14.0.0", "react": "^18.0.0"},
        "devDependencies": {"eslint": "^8.0.0", "prettier": "^3.0.0",
                            "vitest": "^1.0.0"},
    }), encoding="utf-8")
    (path / "package-lock.json").write_text("{}", encoding="utf-8")
    app = path / "app"
    app.mkdir(exist_ok=True)
    (app / "page.tsx").write_text("export default function P(){return null}\n",
                                  encoding="utf-8")
    return path


def make_python_repo(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    (path / "pyproject.toml").write_text(
        "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n", encoding="utf-8")
    src = path / "src"
    src.mkdir(exist_ok=True)
    (src / "main.py").write_text("print('hi')\n", encoding="utf-8")
    return path


def make_monorepo(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    # Un monorepo pnpm real tiene package.json raíz (marker de target_tipo=repo).
    (path / "package.json").write_text(
        json.dumps({"name": "mono-root", "private": True}), encoding="utf-8")
    (path / "pnpm-workspace.yaml").write_text(
        "packages:\n  - 'apps/*'\n", encoding="utf-8")
    (path / "pnpm-lock.yaml").write_text("lockfileVersion: '9.0'\n",
                                         encoding="utf-8")
    web = path / "apps" / "web"
    web.mkdir(parents=True, exist_ok=True)
    (web / "package.json").write_text(
        json.dumps({"name": "web", "dependencies": {"react": "^18.0.0"}}),
        encoding="utf-8")
    return path


def make_bun_repo(path: Path) -> Path:
    """Repo con bun.lock de texto (default Bun >=1.2) · regresión P3."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(
        json.dumps({"name": "demo-bun", "dependencies": {}}), encoding="utf-8")
    (path / "bun.lock").write_text('{"lockfileVersion": 1}\n', encoding="utf-8")
    return path
