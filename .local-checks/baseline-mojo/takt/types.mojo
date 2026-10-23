"""Local signal and result types for the takt cascade engine."""

from std.collections import List, Dict


struct Wave(Copyable, Movable):
    """Descending or ascending signal between cascade layers."""

    var wave_id: String
    var layer: Int
    var source_id: String
    var target_id: String  # empty string = broadcast / none
    var constraints: Dict[String, Float64]
    var context_node_id: String
    var from_layer: Int
    var interlocked: Bool
    var residual_entropy: Float64

    def __init__(
        out self,
        wave_id: String,
        layer: Int,
        source_id: String,
        target_id: String = "",
        constraints: Dict[String, Float64] = Dict[String, Float64](),
        context_node_id: String = "",
        from_layer: Int = -1,
        interlocked: Bool = False,
        residual_entropy: Float64 = 0.0,
    ):
        self.wave_id = wave_id
        self.layer = layer
        self.source_id = source_id
        self.target_id = target_id
        self.constraints = constraints.copy()
        self.context_node_id = context_node_id
        self.from_layer = from_layer
        self.interlocked = interlocked
        self.residual_entropy = residual_entropy

    def __init__(out self, *, copy: Self):
        self.wave_id = copy.wave_id
        self.layer = copy.layer
        self.source_id = copy.source_id
        self.target_id = copy.target_id
        self.constraints = copy.constraints.copy()
        self.context_node_id = copy.context_node_id
        self.from_layer = copy.from_layer
        self.interlocked = copy.interlocked
        self.residual_entropy = copy.residual_entropy


struct RawSignal(Copyable, Movable):
    """Raw detector signal before fusion."""

    var signal_id: String
    var node_id: String
    var detector: String
    var deviation: Float64
    var confidence: Float64

    def __init__(
        out self,
        signal_id: String,
        node_id: String,
        detector: String,
        deviation: Float64,
        confidence: Float64 = 1.0,
    ):
        self.signal_id = signal_id
        self.node_id = node_id
        self.detector = detector
        self.deviation = deviation
        self.confidence = confidence

    def __init__(out self, *, copy: Self):
        self.signal_id = copy.signal_id
        self.node_id = copy.node_id
        self.detector = copy.detector
        self.deviation = copy.deviation
        self.confidence = copy.confidence


struct ErrorSignal(Copyable, Movable):
    """Consolidated aberration vector after fusion."""

    var vector_id: String
    var node_id: String
    var aberration: Float64
    var confidence: Float64
    var residual_entropy: Float64
    var contributing_signals: List[String]
    var reducer: String
    var raw_count: Int

    def __init__(
        out self,
        vector_id: String,
        node_id: String,
        aberration: Float64,
        confidence: Float64,
        residual_entropy: Float64,
        contributing_signals: List[String] = List[String](),
        reducer: String = "fallback",
        raw_count: Int = 0,
    ):
        self.vector_id = vector_id
        self.node_id = node_id
        self.aberration = aberration
        self.confidence = confidence
        self.residual_entropy = residual_entropy
        self.contributing_signals = contributing_signals.copy()
        self.reducer = reducer
        self.raw_count = raw_count

    def __init__(out self, *, copy: Self):
        self.vector_id = copy.vector_id
        self.node_id = copy.node_id
        self.aberration = copy.aberration
        self.confidence = copy.confidence
        self.residual_entropy = copy.residual_entropy
        self.contributing_signals = copy.contributing_signals.copy()
        self.reducer = copy.reducer
        self.raw_count = copy.raw_count


struct Actuation(Copyable, Movable):
    """Executive impulse when homeostat allows action."""

    var actuation_id: String
    var node_id: String
    var command: String
    var expected_delta: Float64
    var aberration: Float64

    def __init__(
        out self,
        actuation_id: String,
        node_id: String,
        command: String = "correct_aberration",
        expected_delta: Float64 = 0.0,
        aberration: Float64 = 0.0,
    ):
        self.actuation_id = actuation_id
        self.node_id = node_id
        self.command = command
        self.expected_delta = expected_delta
        self.aberration = aberration

    def __init__(out self, *, copy: Self):
        self.actuation_id = copy.actuation_id
        self.node_id = copy.node_id
        self.command = copy.command
        self.expected_delta = copy.expected_delta
        self.aberration = copy.aberration


struct SafetyInterlock(Copyable, Movable):
    """Fail-closed safety block when entropy/confidence is unsafe."""

    var interlock_id: String
    var node_id: String
    var reason: String
    var residual_entropy: Float64
    var blocked_signals: List[String]

    def __init__(
        out self,
        interlock_id: String,
        node_id: String,
        reason: String,
        residual_entropy: Float64,
        blocked_signals: List[String] = List[String](),
    ):
        self.interlock_id = interlock_id
        self.node_id = node_id
        self.reason = reason
        self.residual_entropy = residual_entropy
        self.blocked_signals = blocked_signals.copy()

    def __init__(out self, *, copy: Self):
        self.interlock_id = copy.interlock_id
        self.node_id = copy.node_id
        self.reason = copy.reason
        self.residual_entropy = copy.residual_entropy
        self.blocked_signals = copy.blocked_signals.copy()


struct Telemetry(Copyable, Movable):
    """Diagnostic trace emitted during evaluation."""

    var telemetry_id: String
    var node_id: String
    var layer: Int
    var kind: String

    def __init__(
        out self,
        telemetry_id: String,
        node_id: String,
        layer: Int,
        kind: String,
    ):
        self.telemetry_id = telemetry_id
        self.node_id = node_id
        self.layer = layer
        self.kind = kind

    def __init__(out self, *, copy: Self):
        self.telemetry_id = copy.telemetry_id
        self.node_id = copy.node_id
        self.layer = copy.layer
        self.kind = copy.kind


struct OutgoingSignals(Copyable, Movable):
    """Bundle returned by CascadeRegulator.evaluate."""

    var has_error: Bool
    var error: ErrorSignal
    var has_actuation: Bool
    var actuation: Actuation
    var has_interlock: Bool
    var interlock: SafetyInterlock
    var telemetry: List[Telemetry]
    var has_ascending_wave: Bool
    var ascending_wave: Wave

    def __init__(out self):
        self.has_error = False
        self.error = ErrorSignal("err_empty", "", 0.0, 1.0, 0.0)
        self.has_actuation = False
        self.actuation = Actuation("act_none", "")
        self.has_interlock = False
        self.interlock = SafetyInterlock("il_none", "", "", 0.0)
        self.telemetry = List[Telemetry]()
        self.has_ascending_wave = False
        self.ascending_wave = Wave("wave_none", 0, "")

    def __init__(out self, *, copy: Self):
        self.has_error = copy.has_error
        self.error = copy.error.copy()
        self.has_actuation = copy.has_actuation
        self.actuation = copy.actuation.copy()
        self.has_interlock = copy.has_interlock
        self.interlock = copy.interlock.copy()
        self.telemetry = copy.telemetry.copy()
        self.has_ascending_wave = copy.has_ascending_wave
        self.ascending_wave = copy.ascending_wave.copy()

    def has_actuation_clear(self) -> Bool:
        return self.has_actuation and not self.has_interlock

    def is_interlocked(self) -> Bool:
        return self.has_interlock
