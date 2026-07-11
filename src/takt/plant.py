"""ControlledPlant i sekwencyjny skan stanu.

sequential_scan() zwraca iterator węzłów w kolejności generującej takt zegara.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Generic, Iterator, Protocol, Sequence, TypeVar

from .types import StateNode

T = TypeVar("T")


class ControlledPlant(Protocol, Generic[T]):
    """Interfejs środowiska kontrolowanego (Plant).

    Udostępnia sekwencyjny skan stanu — każdy kolejny węzeł = jeden takt.
    """

    def sequential_scan(self) -> Iterator[StateNode[T]]: ...

    def get_node(self, node_id: str) -> StateNode[T] | None: ...


@dataclass(frozen=True)
class TreeNode(Generic[T]):
    """Prosta, immutable implementacja StateNode do testów.

    Używana do budowy czysto matematycznych drzew stanu (np. cyfry, ciągi).
    Kolejność dzieci = kolejność taktów.
    """

    _id: str
    _value: T
    _children: tuple[TreeNode[T], ...] = field(default_factory=tuple)

    @property
    def id(self) -> str:
        return self._id

    @property
    def value(self) -> T:
        return self._value

    def get_children(self) -> Sequence[StateNode[T]]:
        return self._children

    def has_children(self) -> bool:
        return bool(self._children)

    def __repr__(self) -> str:
        return f"TreeNode({self._id!r}, value={self._value!r})"


@dataclass
class MathTreePlant(Generic[T]):
    """Kontrolowane środowisko oparte na drzewie matematycznym.

    Używane wyłącznie w testach — zero zewnętrznych API.
    """

    root: TreeNode[T]
    _index: dict[str, TreeNode[T]] = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self._index = {}
        self._build_index(self.root)

    def _build_index(self, node: TreeNode[T]) -> None:
        self._index[node.id] = node
        for ch in node.get_children():
            self._build_index(ch)  # type: ignore[arg-type]

    def sequential_scan(self) -> Iterator[StateNode[T]]:
        """Depth-first, children order as written — generates clock tacts."""

        def dfs(n: TreeNode[T]) -> Iterator[StateNode[T]]:
            yield n
            for c in n.get_children():
                yield from dfs(c)  # type: ignore[arg-type]

        return dfs(self.root)

    def get_node(self, node_id: str) -> TreeNode[T] | None:
        return self._index.get(node_id)


__all__ = ["ControlledPlant", "TreeNode", "MathTreePlant"]
