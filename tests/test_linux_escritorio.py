"""Tests de XEK_linux-escritorio (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxEscritorioContract(RunnerContract):
    SCRIPT = "XEK_linux-escritorio/scripts/xek-linux-escritorio.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
