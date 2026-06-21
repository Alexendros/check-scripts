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


def make_repo_limpio(path: Path) -> Path:
    """Repo con todos los community standards · git-committed → 0 findings."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "README.md").write_text("# demo\n", encoding="utf-8")
    (path / "LICENSE").write_text("MIT\n", encoding="utf-8")
    (path / "CONTRIBUTING.md").write_text("# contributing\n", encoding="utf-8")
    (path / ".gitignore").write_text("node_modules/\n", encoding="utf-8")
    (path / "CHANGELOG.md").write_text("# changelog\n", encoding="utf-8")
    wf = path / ".github" / "workflows"
    wf.mkdir(parents=True, exist_ok=True)
    (wf / "ci.yml").write_text("on: push\n", encoding="utf-8")
    git_init(path)
    return path


def make_repo_sucio(path: Path) -> Path:
    """Repo sin LICENSE y con .env versionado → findings (incluye critical)."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "README.md").write_text("# demo\n", encoding="utf-8")
    (path / ".env").write_text("SECRET=abc\n", encoding="utf-8")
    git_init(path)
    return path


def make_vite_repo(path: Path) -> Path:
    """Repo Vite mínimo aplicable (sin vite.config/type:module → varios findings)."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(json.dumps({
        "name": "demo-vite",
        "devDependencies": {"vite": "^5.0.0"},
        "scripts": {"build": "vite build"},
    }), encoding="utf-8")
    src = path / "src"
    src.mkdir(exist_ok=True)
    (src / "main.ts").write_text("const x = import.meta.env.SECRET_KEY;\n",
                                 encoding="utf-8")
    return path


def make_astro_repo(path: Path) -> Path:
    """Repo Astro aplicable con output:server sin adapter → astro-004."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(json.dumps({
        "name": "demo-astro",
        "dependencies": {"astro": "^4.0.0"},
        "type": "module",
        "scripts": {"dev": "astro dev", "build": "astro build"},
    }), encoding="utf-8")
    (path / "astro.config.mjs").write_text(
        "export default { output: \"server\" }\n", encoding="utf-8")
    return path


def make_remix_repo(path: Path) -> Path:
    """Repo Remix aplicable sin config ni app/routes → varios findings."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(json.dumps({
        "name": "demo-remix",
        "dependencies": {"@remix-run/react": "^2.0.0"},
        "scripts": {"build": "remix vite:build"},
    }), encoding="utf-8")
    (path / "app").mkdir(exist_ok=True)
    return path


def make_html_a11y_pobre(path: Path) -> Path:
    """HTML con barreras de accesibilidad → a11y-001/002/003/005/006/008."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "<html><head><title>t</title></head><body>\n"
        "<h1>A</h1><h1>B</h1>\n"
        "<img src=\"x.png\">\n"
        "<input type=\"text\">\n"
        "<div role=\"bogus\">x</div>\n"
        "</body></html>\n", encoding="utf-8")
    return path


def make_html_seo_pobre(path: Path) -> Path:
    """HTML pobre en SEO → seo-001/002/003/006/007."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "<html><head></head><body>\n"
        "<script type=\"application/ld+json\">{bad json}</script>\n"
        "</body></html>\n", encoding="utf-8")
    return path


def make_html_perf_pobre(path: Path) -> Path:
    """HTML pobre en performance → perf-001/002/003/004/005."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "<html><head></head><body>\n"
        "<img src=\"a.png\"><img src=\"b.png\">\n"
        "<script src=\"x.js\"></script>\n"
        "</body></html>\n", encoding="utf-8")
    return path


def make_html_cookies(path: Path) -> Path:
    """HTML con tracking embebido y sin banner/enlace → cookies-001/006/007."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "<html><body>\n"
        "<script src=\"https://www.googletagmanager.com/gtag/js?id=X\"></script>\n"
        "</body></html>\n", encoding="utf-8")
    return path


def make_headers_inseguras(path: Path) -> Path:
    """Cabeceras con cookie de tracking insegura y Max-Age > 1 año."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "HTTP/2 200\n"
        "set-cookie: _ga=GA1.2.3; Path=/; Max-Age=63072000\n", encoding="utf-8")
    return path


def make_bun_repo(path: Path) -> Path:
    """Repo con bun.lock de texto (default Bun >=1.2) · regresión P3."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "package.json").write_text(
        json.dumps({"name": "demo-bun", "dependencies": {}}), encoding="utf-8")
    (path / "bun.lock").write_text('{"lockfileVersion": 1}\n', encoding="utf-8")
    return path
