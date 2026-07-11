"""Testy kaskady regulatorów na czysto matematycznych drzewach stanu.

Zero zewnętrznych API / domen. Tylko liczby i struktury.
"""
from __future__ import annotations

from takt import (
    Actuation,
    CascadeRegulator,
    EssentialVariable,
    FalaWave,
    ProfilHomeostatyczny,
    MathTreePlant,
    SafetyInterlock,
    TaktSequencer,
    TreeNode,
    build_cascade,
)


def make_numeric_tree(values: list[float]) -> MathTreePlant[float]:
    """Buduje proste drzewo: root z liśćmi w kolejności values (depth-first scan)."""
    nodes = [TreeNode(f"n{i}", v) for i, v in enumerate(values)]
    root = TreeNode("root", 0.0, tuple(nodes))
    return MathTreePlant(root)


def test_plant_sequential_scan_generates_tacts():
    plant = make_numeric_tree([0.1, 0.5, -0.3])
    nodes = list(plant.sequential_scan())
    assert [n.id for n in nodes] == ["root", "n0", "n1", "n2"]
    assert nodes[1].value == 0.1


def test_single_layer_no_actuation_within_tolerance():
    homeo = ProfilHomeostatyczny(layer=0)
    homeo.add_variable(EssentialVariable("dev", tolerance=0.2, cutoff=0.01))
    reg = CascadeRegulator(layer=0, homeostat=homeo)

    plant = make_numeric_tree([0.05])
    seq = TaktSequencer(plant, reg)
    res = seq.run_one_tact()  # root

    assert res.signals.actuation is None
    assert res.signals.interlock is None
    assert res.signals.error is not None
    assert abs(res.signals.error.aberration) < 0.2


def test_single_layer_actuation_outside_tolerance():
    homeo = ProfilHomeostatyczny(layer=0, min_confidence=0.5)
    homeo.add_variable(EssentialVariable("dev", tolerance=0.1, cutoff=0.01))
    reg = CascadeRegulator(layer=0, homeostat=homeo)

    plant = make_numeric_tree([0.8])
    seq = TaktSequencer(plant, reg)
    seq.run_one_tact()  # root (value 0)
    res = seq.run_one_tact()  # n0 = 0.8

    assert res.signals.actuation is not None
    assert isinstance(res.signals.actuation, Actuation)
    assert res.signals.actuation.node_id == "n0"
    assert res.signals.interlock is None


def test_strict_fail_closed_on_high_entropy():
    """Gdy splot nie redukuje entropii poniżej progu — interlock, brak actuacji."""
    homeo = ProfilHomeostatyczny(layer=0, entropy_threshold=0.2, min_confidence=0.1)
    reg = CascadeRegulator(layer=0, homeostat=homeo)

    class ContradictoryDetector:
        def detect(self, node):
            return [
                {"signal_id": "d1", "node_id": node.id, "detector": "d1", "deviation": 10.0, "confidence": 0.9},
                {"signal_id": "d2", "node_id": node.id, "detector": "d2", "deviation": -10.0, "confidence": 0.9},
            ]

    reg.register_detector(ContradictoryDetector())

    plant = make_numeric_tree([1.0])
    seq = TaktSequencer(plant, reg)
    res = seq.run_one_tact()  # root

    assert res.signals.interlock is not None
    assert isinstance(res.signals.interlock, SafetyInterlock)
    assert res.signals.actuation is None
    assert res.signals.interlock.residual_entropy > homeo.entropy_threshold


def test_two_layer_cascade_propagates_constraints():
    """Fala zstępująca z L1 powinna wpłynąć na sygnały L0 (root-first)."""
    h0 = ProfilHomeostatyczny(0)
    h0.add_variable(EssentialVariable("dev", tolerance=10.0))
    h1 = ProfilHomeostatyczny(1)
    h1.add_variable(EssentialVariable("dev", tolerance=0.05))

    reg0 = CascadeRegulator(layer=0, homeostat=h0)
    reg1 = CascadeRegulator(layer=1, homeostat=h1, child_loop=reg0)
    reg0.parent_loop = reg1

    plant = make_numeric_tree([0.3])

    wave_from_above = FalaWave(
        wave_id="w1",
        layer=1,
        source_id="L1",
        constraints={"dev": 0.01},
    )

    seq = TaktSequencer(plant, reg1)
    seq.run_one_tact(incoming_top_wave=wave_from_above)  # root
    res = seq.run_one_tact(incoming_top_wave=wave_from_above)  # n0

    assert res.signals.error is not None
    assert res.signals.actuation is not None or res.signals.interlock is not None


def test_build_cascade_helper():
    layers = [
        (0, ProfilHomeostatyczny(0)),
        (1, ProfilHomeostatyczny(1)),
    ]
    root = build_cascade(layers)
    assert root.layer == 1
    assert root.child_loop is not None
    assert root.child_loop.layer == 0
    assert root.child_loop.parent_loop is root
