"""Helpers do budowy kaskady regulatorów."""
from __future__ import annotations

from typing import Sequence

from .fusion import SplotFusionUnit
from .homeostat import ProfilHomeostatyczny
from .regulator import CascadeRegulator


def build_cascade(
    layers: Sequence[tuple[int, ProfilHomeostatyczny]],
    *,
    fusion_factory: type[SplotFusionUnit] | None = None,
) -> CascadeRegulator:
    """Zbuduj łańcuch regulatorów L0 ... L{n-1}.

    layers: lista (layer, homeostat) posortowana rosnąco (L0 pierwszy).
    Zwraca root (najwyższy poziom).
    """
    regs: list[CascadeRegulator] = []
    prev: CascadeRegulator | None = None
    Fusion = fusion_factory or SplotFusionUnit

    for layer, homeo in layers:
        reg = CascadeRegulator(
            layer=layer,
            homeostat=homeo,
            fusion=Fusion(),
            parent_loop=prev,
            name=f"reg_L{layer}",
        )
        if prev is not None:
            # lower's parent already set above; higher's child points down
            reg.child_loop = prev
            prev.parent_loop = reg
        regs.append(reg)
        prev = reg

    return regs[-1]  # root = najwyższy (najwyższy layer)
__all__ = ["build_cascade"]
