"""Tests de XEK_integridad (check-skill repo · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestIntegridadContract(RunnerContract):
    SCRIPT = "XEK_integridad/scripts/xek-integridad.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"
