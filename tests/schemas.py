"""Carga y cachea los esquemas JSON del cluster XEK.

Fuente de verdad: skills/XEK_orquesta/schemas/{manifest,finding}.schema.json
"""
from __future__ import annotations

import functools
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = REPO_ROOT / "skills" / "XEK_orquesta" / "schemas"


@functools.lru_cache(maxsize=None)
def _load(name: str) -> dict:
    return json.loads((SCHEMA_DIR / name).read_text(encoding="utf-8"))


def manifest_schema() -> dict:
    """Esquema xek/manifest@v2 (emitido por XEK_detecta-stack)."""
    return _load("manifest.schema.json")


def finding_schema() -> dict:
    """Esquema xek/finding@v1 (emitido por los check-skills)."""
    return _load("finding.schema.json")
