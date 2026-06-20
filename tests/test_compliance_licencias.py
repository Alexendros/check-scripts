"""Tests de XEK_compliance-licencias (check-skill repo · emite xek/finding@v1)."""
from __future__ import annotations

from runners.base import RunnerContract


class TestComplianceLicenciasContract(RunnerContract):
    SCRIPT = "XEK_compliance-licencias/scripts/xek-compliance-licencias.sh"
    EMITS = "finding"
    APPLIES_TO = "repo"
