"""Tests de XEK_linux-fs (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxFsContract(RunnerContract):
    SCRIPT = "XEK_linux-fs/scripts/xek-linux-fs.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
