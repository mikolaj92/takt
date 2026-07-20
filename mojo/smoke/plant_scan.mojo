"""Plant sequential_scan smoke: depth-first order root then leaves."""

from std.collections import List
from takt.plant import make_code_plant, make_document_plant, make_numeric_tree, make_plant_dfs


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

    # Document-shaped plant: doc → section → paragraphs
    var sec = List[Float64]()
    sec.append(0.05)
    sec.append(0.0)
    var p0 = List[Float64]()
    p0.append(0.02)
    p0.append(0.8)
    var p1 = List[Float64]()
    p1.append(0.01)
    var paras = List[List[Float64]]()
    paras.append(p0^)
    paras.append(p1^)
    var doc = make_document_plant(sec^, paras^)
    var dscan = doc.sequential_scan()
    _check(dscan[0].kind == "document", "doc kind")
    _check(dscan[1].kind == "section", "section kind")
    _check(dscan[2].kind == "paragraph", "para kind")
    _check(dscan[2].parent_id == "section:0", "para parent")
    _check(len(doc.children_of("section:0")) == 2, "section children")

    # Code-shaped plant: pr → file → hunks
    var files = List[Float64]()
    files.append(0.2)
    var h0 = List[Float64]()
    h0.append(0.9)
    var hunks = List[List[Float64]]()
    hunks.append(h0^)
    var code = make_code_plant(files^, hunks^)
    var cscan = code.sequential_scan()
    _check(cscan[0].id == "pr" and cscan[0].kind == "pull_request", "pr root")
    _check(cscan[2].kind == "hunk", "hunk leaf")

    print("takt plant scan smoke ok")
