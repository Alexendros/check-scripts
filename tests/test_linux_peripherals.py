"""Tests de XEK_linux-peripherals (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxPeripheralsContract(RunnerContract):
    SCRIPT = "XEK_linux-peripherals/scripts/xek-linux-peripherals.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
