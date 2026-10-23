"""ProfilHomeostatyczny — stability profile for essential variables."""

from std.collections import Dict
from std.math import abs


struct EssentialVariable(Copyable, Movable):
    """Critical variable with tolerance and cutoff."""

    var name: String
    var tolerance: Float64
    var cutoff: Float64

    def __init__(out self, name: String, tolerance: Float64, cutoff: Float64 = 0.0):
        self.name = name
        self.tolerance = tolerance
        self.cutoff = cutoff

    def __init__(out self, *, copy: Self):
        self.name = copy.name
        self.tolerance = copy.tolerance
        self.cutoff = copy.cutoff


struct ProfilHomeostatyczny(Copyable, Movable):
    """Homeostatic profile for one cascade layer (strict fail-closed)."""

    var layer: Int
    var variables: Dict[String, EssentialVariable]
    var entropy_threshold: Float64
    var min_confidence: Float64

    def __init__(
        out self,
        layer: Int,
        entropy_threshold: Float64 = 0.35,
        min_confidence: Float64 = 0.6,
    ):
        self.layer = layer
        self.variables = Dict[String, EssentialVariable]()
        self.entropy_threshold = entropy_threshold
        self.min_confidence = min_confidence

    def __init__(out self, *, copy: Self):
        self.layer = copy.layer
        self.variables = copy.variables.copy()
        self.entropy_threshold = copy.entropy_threshold
        self.min_confidence = copy.min_confidence

    def add_variable(mut self, variable: EssentialVariable):
        self.variables[variable.name] = variable.copy()

    def get_variable(self, name: String) raises -> EssentialVariable:
        return self.variables[name].copy()

    def has_variable(self, name: String) -> Bool:
        return name in self.variables

    def variable_count(self) -> Int:
        return len(self.variables)

    def within_tolerance(self, var_name: String, deviation: Float64) -> Bool:
        if var_name not in self.variables:
            return abs(deviation) < 1e-9
        var ev = self.variables[var_name].copy()
        return abs(deviation) <= ev.tolerance

    def is_cutoff(self, value: Float64) -> Bool:
        if len(self.variables) == 0:
            return True
        for entry in self.variables.items():
            var ev = entry.value.copy()
            if abs(value) >= ev.cutoff:
                return False
        return True

    def should_interlock(self, residual_entropy: Float64, confidence: Float64) -> Bool:
        """Strict fail-closed: high residual entropy or low confidence."""
        if residual_entropy > self.entropy_threshold:
            return True
        if confidence < self.min_confidence:
            return True
        return False

    def any_tolerance_exceeded(self, aberration: Float64) -> Bool:
        """True if |aberration| exceeds any essential variable tolerance."""
        if len(self.variables) == 0:
            return abs(aberration) > 1e-9
        for entry in self.variables.items():
            var ev = entry.value.copy()
            if abs(aberration) > ev.tolerance:
                return True
        return False
