"""Tests de XEK_linux-backup (check-skill host · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestLinuxBackupContract(RunnerContract):
    SCRIPT = "XEK_linux-backup/scripts/xek-linux-backup.sh"
    EMITS = "finding"
    APPLIES_TO = "host"
