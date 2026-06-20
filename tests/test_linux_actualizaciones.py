"""Tests de XEK_linux-actualizaciones (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxActualizacionesContract(RunnerContract):
    SCRIPT = "XEK_linux-actualizaciones/scripts/xek-linux-actualizaciones.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
