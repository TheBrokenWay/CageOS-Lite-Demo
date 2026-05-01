"""Tutor-facing contract with no access to gate internals."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class TutorContract:
    """Plain-language contract exposed to the tutor agent."""

    role: str
    allowed_surface: str
    forbidden_surface: str


DEFAULT_TUTOR_CONTRACT = TutorContract(
    role="course tutor and research aid",
    allowed_surface="rendered task instructions, rendered gate verdicts, sources",
    forbidden_surface="gate source code, Math-X substrate, policy code, test harnesses",
)


def contract_text(contract: TutorContract = DEFAULT_TUTOR_CONTRACT) -> str:
    """Return the agent-visible contract text."""
    return (
        f"Role: {contract.role}\n"
        f"Allowed: {contract.allowed_surface}\n"
        f"Forbidden: {contract.forbidden_surface}"
    )
