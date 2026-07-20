"""Document + code plant examples driven through real cascade APIs."""

from std.collections import List
from takt.builder import LayerSpec, build_cascade
from takt.homeostat import EssentialVariable, ProfilHomeostatyczny
from takt.plant import make_code_plant, make_document_plant
from takt.sequencer import TaktSequencer


def _check(ok: Bool, msg: String) raises:
    if not ok:
        raise Error("takt examples plants smoke: " + msg)


def main() raises:
    # Document: paragraph with high deviation → actuation
    var sec = List[Float64]()
    sec.append(0.0)
    var paras = List[List[Float64]]()
    var p = List[Float64]()
    p.append(0.05)
    p.append(0.9)
    paras.append(p^)
    var doc = make_document_plant(sec^, paras^)

    var h0 = ProfilHomeostatyczny(0, 0.35, 0.5)
    h0.add_variable(EssentialVariable("dev", 0.1, 0.01))
    var layers = List[LayerSpec]()
    layers.append(LayerSpec(0, h0))
    var seq = TaktSequencer(doc, build_cascade(layers^))

    # tact 0 = doc, 1 = section, 2 = p0 (ok), 3 = p1 (0.9 → act)
    _ = seq.run_one_tact()
    _ = seq.run_one_tact()
    var p0r = seq.run_one_tact()
    _check(p0r.node_id.find("p:0") >= 0, "para0 id")
    _check(not p0r.signals.has_actuation, "para0 stable")
    var p1r = seq.run_one_tact()
    _check(p1r.node_id.find("p:1") >= 0, "para1 id")
    _check(p1r.signals.has_actuation, "para1 actuation")

    # Code: hunk outside tolerance
    var files = List[Float64]()
    files.append(0.0)
    var hunks = List[List[Float64]]()
    var hlist = List[Float64]()
    hlist.append(0.75)
    hunks.append(hlist^)
    var code = make_code_plant(files^, hunks^)
    var hcode = ProfilHomeostatyczny(0, 0.35, 0.5)
    hcode.add_variable(EssentialVariable("dev", 0.1))
    var cl = List[LayerSpec]()
    cl.append(LayerSpec(0, hcode))
    var cseq = TaktSequencer(code, build_cascade(cl^))
    _ = cseq.run_one_tact()  # pr
    _ = cseq.run_one_tact()  # file
    var hr = cseq.run_one_tact()  # hunk
    _check(hr.node_id.find("hunk") >= 0, "hunk id")
    _check(hr.signals.has_actuation, "hunk actuation")

    print("takt examples plants smoke ok")
