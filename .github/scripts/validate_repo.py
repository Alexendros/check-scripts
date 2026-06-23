#!/usr/bin/env python3
"""Validador de estructura del repo check-scripts."""

import glob
import os
import sys

import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def fail(msg: str) -> None:
    print(f"❌ {msg}")
    sys.exit(1)


def require_file(path: str) -> None:
    if not os.path.isfile(os.path.join(ROOT, path)):
        fail(f"Falta archivo requerido: {path}")


def main() -> None:
    require_file("METHODOLOGY.md")
    require_file("ROSTER.example.yaml")
    require_file("skills/_template/SKILL.md")

    skills = glob.glob(os.path.join(ROOT, "skills", "*", "SKILL.md"))
    if not skills:
        fail("No se encontraron skills/*/SKILL.md")

    for skill in sorted(skills):
        with open(skill, encoding="utf-8") as f:
            src = f.read()
        if not src.startswith("---"):
            fail(f"{skill}: falta frontmatter YAML")
        try:
            _, fm, body = src.split("---", 2)
            data = yaml.safe_load(fm)
        except Exception as exc:  # noqa: BLE001
            fail(f"{skill}: frontmatter inválido: {exc}")

        if not isinstance(data, dict):
            fail(f"{skill}: frontmatter no es un diccionario")

        estado = data.get("estado", "stub")
        if estado in ("beta", "prod"):
            refs = data.get("referencias_canonicas") or []
            if "TODO" in str(refs):
                fail(f"{skill}: referencias_canonicas contiene TODO en skill {estado}")
            if not refs:
                fail(f"{skill}: referencias_canonicas vacío en skill {estado}")

    roster = os.path.join(ROOT, "ROSTER.example.yaml")
    with open(roster, encoding="utf-8") as f:
        try:
            yaml.safe_load(f)
        except yaml.YAMLError as exc:
            fail(f"ROSTER.example.yaml no es YAML válido: {exc}")

    print(f"✅ Estructura validada: {len(skills)} skills, ROSTER y METHODOLOGY OK")


if __name__ == "__main__":
    main()
