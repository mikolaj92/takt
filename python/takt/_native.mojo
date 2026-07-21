"""Python extension: thin Mojo surface for Takt cascade.

Same JSON contract as ``cascade_step`` / ``tools/takt_step.sh``.
"""

from std.os import abort
from std.python import PythonObject
from std.python.bindings import PythonModuleBuilder
from takt.adapters_fala import cascade_step


def cascade_step_json(request: PythonObject) raises -> PythonObject:
    var s = String(py=request)
    var out = cascade_step(s)
    return PythonObject(out)


@export
def PyInit__native() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("_native")
        m.def_function[cascade_step_json]("cascade_step_json")
        return m.finalize()
    except e:
        abort(String("takt._native init failed: ", e))
