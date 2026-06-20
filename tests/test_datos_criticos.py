"""Tests de XEK_datos-criticos (check-skill repo · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestDatosCriticosContract(RunnerContract):
    SCRIPT = "XEK_datos-criticos/scripts/xek-datos-criticos.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"
