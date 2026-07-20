"""CLI entry: one cascade step for Fala process host / local fixtures.

Usage:
  TAKT_REQUEST_PATH=examples/fixtures/cascade_evaluate.request.json \\
    ./tools/takt_step.sh

Fala effector contract:
  FALA_EFFECTOR_INPUT_DIR/request.json → FALA_EFFECTOR_OUTPUT_DIR/result.json
"""

from std.pathlib import Path
from std.os import getenv
from takt.adapters_fala import cascade_step


def _write_result(text: String) raises:
    var out_dir = getenv("FALA_EFFECTOR_OUTPUT_DIR")
    if out_dir.byte_length() == 0:
        print(text)
        return
    var result_path = out_dir + "/result.json"
    Path(result_path).write_text(text)


def main() raises:
    var path = String("")
    var env_path = getenv("TAKT_REQUEST_PATH")
    if env_path.byte_length() > 0:
        path = env_path
    else:
        var input_dir = getenv("FALA_EFFECTOR_INPUT_DIR")
        if input_dir.byte_length() > 0:
            var request_file = input_dir + "/request.json"
            if Path(request_file).exists():
                path = request_file
        if path.byte_length() == 0:
            var manifest = getenv("FALA_EFFECTOR_MANIFEST")
            if manifest.byte_length() > 0 and Path(manifest).exists():
                # Prefer sibling request.json next to manifest layout
                var req = "examples/fixtures/cascade_evaluate.request.json"
                if Path(req).exists():
                    path = req

    if path.byte_length() == 0:
        path = "examples/fixtures/cascade_evaluate.request.json"

    if not Path(path).exists():
        raise Error("takt step: request not found: " + path)

    var text = Path(path).read_text()
    var out = cascade_step(text)
    _write_result(out)
