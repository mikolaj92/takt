"""Testy opcjonalnej ścieżki integracji z runtime'em Splot."""

from __future__ import annotations

import importlib.util

import pytest

from takt import CascadeRegulator, EssentialVariable, ProfilHomeostatyczny, RawSignal, TreeNode
from takt.fusion import SplotFusionUnit


pytestmark = pytest.mark.skipif(
    importlib.util.find_spec("splot") is None,
    reason="splot-runtime nie jest zainstalowany",
)


def test_splot_fusion_maps_round_result_report_values():
    fusion = SplotFusionUnit()
    result = fusion.fuse(
        [
            RawSignal(signal_id="s0", node_id="node", detector="d0", deviation=0.8, confidence=0.9),
            RawSignal(signal_id="s1", node_id="node", detector="d1", deviation=0.4, confidence=0.9),
        ],
        node_id="node",
        now="2026-01-01T00:00:00Z",
    )

    assert result.metadata["reducer"] == "splot"
    assert result.aberration == pytest.approx(0.6)
    assert result.confidence == pytest.approx(0.225)
    assert result.residual_entropy == pytest.approx(0.775)


def test_splot_single_signal_preserves_confidence_and_actuates():
    homeo = ProfilHomeostatyczny(layer=0)
    homeo.add_variable(EssentialVariable("dev", tolerance=0.1, cutoff=0.01))
    fusion = SplotFusionUnit()
    reg = CascadeRegulator(layer=0, homeostat=homeo, fusion=fusion)

    result = reg.evaluate(TreeNode("node", 0.8))

    assert result.error is not None
    assert result.error.metadata["reducer"] == "splot"
    assert result.error.aberration == pytest.approx(0.8)
    assert result.error.confidence == pytest.approx(0.8)
    assert result.error.residual_entropy == pytest.approx(0.2)
    assert result.actuation is not None
    assert result.interlock is None


def test_splot_conflicting_signals_interlock():
    homeo = ProfilHomeostatyczny(layer=0, entropy_threshold=0.2, min_confidence=0.1)
    reg = CascadeRegulator(layer=0, homeostat=homeo, fusion=SplotFusionUnit())

    class ContradictoryDetector:
        def detect(self, node):
            return [
                RawSignal(
                    signal_id="d1", node_id=node.id, detector="d1", deviation=10.0, confidence=0.9
                ),
                RawSignal(
                    signal_id="d2", node_id=node.id, detector="d2", deviation=-10.0, confidence=0.9
                ),
            ]

    reg.register_detector(ContradictoryDetector())
    result = reg.evaluate(TreeNode("node", 0.0))

    assert result.error is not None
    assert result.error.metadata["reducer"] == "splot"
    assert result.error.confidence < 0.1
    assert result.error.residual_entropy > 0.9
    assert result.interlock is not None
    assert result.actuation is None
