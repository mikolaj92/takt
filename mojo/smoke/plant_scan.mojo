"""Plant sequential_scan smoke: depth-first order root then leaves."""

from std.collections import List
from takt.plant import make_numeric_tree, make_plant_dfs


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt plant scan smoke: " + msg)


def main() raises:
    var values = List[Float64]()
    values.append(0.1)
    values.append(0.5)
    values.append(-0.3)
    var plant = make_numeric_tree(values^)
    var nodes = plant.sequential_scan()

    _check(len(nodes) == 4, "expected 4 nodes")
    _check(nodes[0].id == "root", "scan[0]=root")
    _check(nodes[1].id == "n0", "scan[1]=n0")
    _check(nodes[2].id == "n1", "scan[2]=n1")
    _check(nodes[3].id == "n2", "scan[3]=n2")
    _check(nodes[1].value == 0.1, "n0 value")
    _check(nodes[0].has_children(), "root has children")

    # Nested tree DFS: root -> mid -> leaf
    var ids = List[String]()
    ids.append("root")
    ids.append("mid")
    ids.append("leaf")
    var vals = List[Float64]()
    vals.append(0.0)
    vals.append(0.0)
    vals.append(1.0)
    var kids = List[Bool]()
    kids.append(True)
    kids.append(True)
    kids.append(False)
    var nested = make_plant_dfs(ids^, vals^, kids^)
    var deep = nested.sequential_scan()
    _check(len(deep) == 3, "nested scan length")
    _check(
        deep[0].id == "root" and deep[1].id == "mid" and deep[2].id == "leaf",
        "dfs order",
    )

    print("takt plant scan smoke ok")
