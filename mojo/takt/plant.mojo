"""Controlled plant: hierarchical state + sequential scan (one node = one tact).

Nodes are stored flat in DFS order (Mojo cannot embed List[TreeNode] recursively).
Each node may carry parent_id, layer, and kind so hosts can model documents,
code trees, and multi-layer cascades without domain parsers inside takt.
"""

from std.collections import List


struct TreeNode(Copyable, Movable):
    """One state node: numeric value + hierarchy metadata."""

    var id: String
    var value: Float64
    var _has_children: Bool
    var parent_id: String
    var layer: Int
    var kind: String

    def __init__(
        out self,
        id: String,
        value: Float64,
        has_children: Bool = False,
        parent_id: String = "",
        layer: Int = 0,
        kind: String = "node",
    ):
        self.id = id
        self.value = value
        self._has_children = has_children
        self.parent_id = parent_id
        self.layer = layer
        self.kind = kind

    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.value = copy.value
        self._has_children = copy._has_children
        self.parent_id = copy.parent_id
        self.layer = copy.layer
        self.kind = copy.kind

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

    def node_count(self) -> Int:
        return len(self.nodes)

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

    def children_of(self, parent_id: String) -> List[TreeNode]:
        var out = List[TreeNode]()
        for i in range(len(self.nodes)):
            if self.nodes[i].parent_id == parent_id:
                out.append(self.nodes[i].copy())
        return out^


def make_numeric_tree(values: List[Float64]) -> MathTreePlant:
    """Root with leaves in `values` order (scan: root, n0, n1, ...)."""
    var nodes = List[TreeNode]()
    var has_kids = len(values) > 0
    nodes.append(TreeNode("root", 0.0, has_kids, "", 1, "root"))
    for i in range(len(values)):
        nodes.append(TreeNode("n" + String(i), values[i], False, "root", 0, "leaf"))
    return MathTreePlant(nodes^)


def make_plant_dfs(
    ids: List[String], values: List[Float64], has_children: List[Bool]
) raises -> MathTreePlant:
    """Build plant from explicit DFS arrays (minimal nested hierarchy)."""
    if len(ids) != len(values) or len(ids) != len(has_children):
        raise Error("make_plant_dfs: length mismatch")
    var nodes = List[TreeNode]()
    for i in range(len(ids)):
        nodes.append(TreeNode(ids[i], values[i], has_children[i], "", 0, "node"))
    return MathTreePlant(nodes^)


def make_layered_plant(nodes: List[TreeNode]) -> MathTreePlant:
    """Host-built plant: caller supplies full DFS list with parent/layer/kind."""
    return MathTreePlant(nodes.copy())


def make_document_plant(
    section_devs: List[Float64], para_devs: List[List[Float64]]
) raises -> MathTreePlant:
    """Document-shaped cascade: document → sections → paragraphs (DFS).

    section_devs[i] is section-level aberration proxy; para_devs[i] are paragraphs.
    """
    if len(section_devs) != len(para_devs):
        raise Error("make_document_plant: section/para length mismatch")
    var nodes = List[TreeNode]()
    var has_sections = len(section_devs) > 0
    nodes.append(TreeNode("doc", 0.0, has_sections, "", 2, "document"))
    for s in range(len(section_devs)):
        var sid = "section:" + String(s)
        var paras = para_devs[s].copy()
        var has_p = len(paras) > 0
        nodes.append(TreeNode(sid, section_devs[s], has_p, "doc", 1, "section"))
        for p in range(len(paras)):
            var pid = sid + "/p:" + String(p)
            nodes.append(TreeNode(pid, paras[p], False, sid, 0, "paragraph"))
    return MathTreePlant(nodes^)


def make_code_plant(
    file_devs: List[Float64], hunk_devs: List[List[Float64]]
) raises -> MathTreePlant:
    """Code/PR-shaped cascade: pr → files → hunks (DFS)."""
    if len(file_devs) != len(hunk_devs):
        raise Error("make_code_plant: file/hunk length mismatch")
    var nodes = List[TreeNode]()
    var has_files = len(file_devs) > 0
    nodes.append(TreeNode("pr", 0.0, has_files, "", 2, "pull_request"))
    for f in range(len(file_devs)):
        var fid = "file:" + String(f)
        var hunks = hunk_devs[f].copy()
        var has_h = len(hunks) > 0
        nodes.append(TreeNode(fid, file_devs[f], has_h, "pr", 1, "file"))
        for h in range(len(hunks)):
            var hid = fid + "/hunk:" + String(h)
            nodes.append(TreeNode(hid, hunks[h], False, fid, 0, "hunk"))
    return MathTreePlant(nodes^)
