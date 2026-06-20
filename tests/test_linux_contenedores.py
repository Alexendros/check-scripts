"""Tests de XEK_linux-contenedores (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxContenedoresContract(RunnerContract):
    SCRIPT = "XEK_linux-contenedores/scripts/xek-linux-contenedores.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
