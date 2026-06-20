"""Tests de XEK_sca (check-skill repo · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestScaContract(RunnerContract):
    SCRIPT = "XEK_sca/scripts/xek-sca.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"
