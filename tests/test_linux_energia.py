"""Tests de XEK_linux-energia (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxEnergiaContract(RunnerContract):
    SCRIPT = "XEK_linux-energia/scripts/xek-linux-energia.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
