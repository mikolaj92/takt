"""ProfilHomeostatyczny — profil homeostatyczny dla zmiennych krytycznych.

Definiuje granice stabilności na poziomie hierarchii.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class EssentialVariable:
    """Zmienna krytyczna (Essential Variable).

    name: identyfikator zmiennej.
    tolerance: maksymalne dopuszczalne odchylenie (abs).
    cutoff: wartość poniżej której sygnał jest uznawany za śladowy/nieistotny.
    """

    name: str
    tolerance: float
    cutoff: float = 0.0


@dataclass
class ProfilHomeostatyczny:
    """Zarządza zmiennymi krytycznymi dla danego poziomu kaskady.

    Użyty do:
    - decydowania czy aberration wymaga akcji ( > tolerance )
    - decydowania o interlocku gdy residual_entropy za wysoka lub niejednoznaczność
    - odrzucania śladowych sygnałów ( < cutoff )
    """

    layer: int
    variables: dict[str, EssentialVariable] = field(default_factory=dict)
    entropy_threshold: float = 0.35  # powyżej tego → interlock jeśli nie da się zredukować
    min_confidence: float = 0.6  # minimalna pewność do podjęcia akcji

    def add_variable(self, var: EssentialVariable) -> None:
        self.variables[var.name] = var

    def get_variable(self, name: str) -> EssentialVariable | None:
        return self.variables.get(name)

    def within_tolerance(self, var_name: str, deviation: float) -> bool:
        var = self.variables.get(var_name)
        if not var:
            return abs(deviation) < 1e-9
        return abs(deviation) <= var.tolerance

    def is_cutoff(self, value: float) -> bool:
        """Czy wartość jest śladowa (poniżej cut-off wszystkich zmiennych)."""
        for v in self.variables.values():
            if abs(value) >= v.cutoff:
                return False
        return True

    def should_interlock(self, residual_entropy: float, confidence: float) -> bool:
        """Strict fail-closed: gdy entropia za wysoka lub pewność za niska."""
        if residual_entropy > self.entropy_threshold:
            return True
        if confidence < self.min_confidence:
            return True
        return False

    def to_dict(self) -> dict[str, Any]:
        return {
            "layer": self.layer,
            "variables": {k: {"tolerance": v.tolerance, "cutoff": v.cutoff} for k, v in self.variables.items()},
            "entropy_threshold": self.entropy_threshold,
            "min_confidence": self.min_confidence,
        }


__all__ = ["EssentialVariable", "ProfilHomeostatyczny"]
