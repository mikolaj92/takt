"""Controlled plant: hierarchical state + sequential scan (one node = one tact).

Tree structure is stored flat (ids/values + has_children flags + optional
parent index) because Mojo cannot embed List[TreeNode] inside TreeNode.
sequential_scan still yields depth-first order matching the Python plant.
"""

from std.collections import List


struct TreeNode(Copyable, Movable):
    """One state node in the plant (value + hierarchy flags)."""

    var id: String
    var value: Float64
    var _has_children: Bool

    def __init__(
        out self,
        id: String,
        value: Float64,
        has_children: Bool = False,
    ):
        self.id = id
        self.value = value
        self._has_children = has_children

    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.value = copy.value
        self._has_children = copy._has_children

    def has_children(self) -> Bool:
        return self._has_children


struct MathTreePlant(Copyable, Movable):
    """Domain-free plant: pre-ordered DFS scan drives the tact clock."""

    var nodes: List[TreeNode]

    def __init__(out self, nodes: List[TreeNode]):
        self.nodes = nodes.copy()

    def __init__(out self, *, copy: Self):
        self.nodes = copy.nodes.copy()

    def sequential_scan(self) -> List[TreeNode]:
        """Depth-first order as stored (clock tacts)."""
        return self.nodes.copy()

    def get_node(self, node_id: String) raises -> TreeNode:
        for i in range(len(self.nodes)):
            if self.nodes[i].id == node_id:
                return self.nodes[i].copy()
        raise Error("node not found: " + node_id)

    def try_get_node(self, node_id: String) -> List[TreeNode]:
        var found = List[TreeNode]()
        for i in range(len(self.nodes)):
            if self.nodes[i].id == node_id:
                found.append(self.nodes[i].copy())
                return found^
        return found^


def make_numeric_tree(values: List[Float64]) -> MathTreePlant:
    """Root with leaves in `values` order (scan: root, n0, n1, ...)."""
    var nodes = List[TreeNode]()
    var has_kids = len(values) > 0
    nodes.append(TreeNode("root", 0.0, has_kids))
    for i in range(len(values)):
        nodes.append(TreeNode("n" + String(i), values[i], False))
    return MathTreePlant(nodes^)


def make_plant_dfs(
    ids: List[String], values: List[Float64], has_children: List[Bool]
) raises -> MathTreePlant:
    """Build plant from explicit DFS arrays (for nested hierarchy tests)."""
    if len(ids) != len(values) or len(ids) != len(has_children):
        raise Error("make_plant_dfs: length mismatch")
    var nodes = List[TreeNode]()
    for i in range(len(ids)):
        nodes.append(TreeNode(ids[i], values[i], has_children[i]))
    return MathTreePlant(nodes^)
