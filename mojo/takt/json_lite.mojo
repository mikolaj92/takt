"""Minimal JSON helpers for takt host/effector boundary (no EmberJson).

Supports reading string/number/bool fields and walking simple arrays of objects
in host-controlled fixtures. Not a general JSON library.
"""

from std.collections import List


def quote(value: String) -> String:
    var result = "\""
    for i in range(value.byte_length()):
        var ch = String(value[byte=i])
        if ch == "\\":
            result += "\\\\"
        elif ch == "\"":
            result += "\\\""
        elif ch == "\n":
            result += "\\n"
        elif ch == "\r":
            result += "\\r"
        elif ch == "\t":
            result += "\\t"
        else:
            result += ch
    result += "\""
    return result


def _at(text: String, i: Int) -> String:
    return String(text[byte=i])


def _skip_ws(text: String, start: Int) -> Int:
    var i = start
    var n = text.byte_length()
    while i < n:
        var ch = _at(text, i)
        if ch == " " or ch == "\n" or ch == "\r" or ch == "\t":
            i += 1
            continue
        break
    return i


def _find_from(text: String, needle: String, from_pos: Int = 0) -> Int:
    if from_pos <= 0:
        return text.find(needle)
    if from_pos >= text.byte_length():
        return -1
    var tail = String(text[byte=from_pos:])
    var pos = tail.find(needle)
    if pos < 0:
        return -1
    return from_pos + pos


def _find_key(text: String, key: String, from_pos: Int = 0) -> Int:
    """Return index of value start after \"key\":  or -1."""
    var needle = "\"" + key + "\""
    var pos = _find_from(text, needle, from_pos)
    if pos < 0:
        return -1
    var i = pos + needle.byte_length()
    i = _skip_ws(text, i)
    if i >= text.byte_length() or _at(text, i) != ":":
        return -1
    return _skip_ws(text, i + 1)


def _hex_digit(ch: String) -> Int:
    if ch == "0":
        return 0
    if ch == "1":
        return 1
    if ch == "2":
        return 2
    if ch == "3":
        return 3
    if ch == "4":
        return 4
    if ch == "5":
        return 5
    if ch == "6":
        return 6
    if ch == "7":
        return 7
    if ch == "8":
        return 8
    if ch == "9":
        return 9
    return -1


def read_string_field(text: String, key: String, default: String = "") -> String:
    var i = _find_key(text, key)
    if i < 0:
        return default
    if i >= text.byte_length() or _at(text, i) != "\"":
        return default
    i += 1
    var start = i
    var n = text.byte_length()
    var esc = False
    while i < n:
        var ch = _at(text, i)
        if esc:
            esc = False
            i += 1
            continue
        if ch == "\\":
            esc = True
            i += 1
            continue
        if ch == "\"":
            return String(text[byte=start:i])
        i += 1
    return default


def read_float_field(text: String, key: String, default: Float64 = 0.0) -> Float64:
    var i = _find_key(text, key)
    if i < 0:
        return default
    return _parse_number_at(text, i, default)


def read_int_field(text: String, key: String, default: Int = 0) -> Int:
    var f = read_float_field(text, key, Float64(default))
    return Int(f)


def read_bool_field(text: String, key: String, default: Bool = False) -> Bool:
    var i = _find_key(text, key)
    if i < 0:
        return default
    if _find_from(text, "true", i) == i:
        return True
    if _find_from(text, "false", i) == i:
        return False
    return default


def _parse_number_at(text: String, start: Int, default: Float64) -> Float64:
    var i = start
    var n = text.byte_length()
    if i >= n:
        return default
    var sign: Float64 = 1.0
    if _at(text, i) == "-":
        sign = -1.0
        i += 1
    elif _at(text, i) == "+":
        i += 1
    var int_part: Float64 = 0.0
    var saw_digit = False
    while i < n:
        var d = _hex_digit(_at(text, i))
        if d < 0:
            break
        int_part = int_part * 10.0 + Float64(d)
        saw_digit = True
        i += 1
    var frac: Float64 = 0.0
    var scale: Float64 = 1.0
    if i < n and _at(text, i) == ".":
        i += 1
        while i < n:
            var d2 = _hex_digit(_at(text, i))
            if d2 < 0:
                break
            scale *= 0.1
            frac += Float64(d2) * scale
            saw_digit = True
            i += 1
    if not saw_digit:
        return default
    return sign * (int_part + frac)


def _object_slice_at(text: String, start: Int) raises -> String:
    """Extract {...} starting at start (must be '{')."""
    if start >= text.byte_length() or _at(text, start) != "{":
        raise Error("json_lite: expected object")
    var depth = 0
    var i = start
    var n = text.byte_length()
    var in_str = False
    var esc = False
    while i < n:
        var ch = _at(text, i)
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == "\"":
                in_str = False
            i += 1
            continue
        if ch == "\"":
            in_str = True
            i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return String(text[byte=start : i + 1])
        i += 1
    raise Error("json_lite: unclosed object")


def extract_object_array(text: String, key: String) raises -> List[String]:
    """Return list of object substrings under array field `key`."""
    var out = List[String]()
    var i = _find_key(text, key)
    if i < 0:
        return out^
    if i >= text.byte_length() or _at(text, i) != "[":
        return out^
    i += 1
    var n = text.byte_length()
    while i < n:
        i = _skip_ws(text, i)
        if i < n and _at(text, i) == "]":
            break
        if i < n and _at(text, i) == ",":
            i += 1
            continue
        if i < n and _at(text, i) == "{":
            var obj = _object_slice_at(text, i)
            out.append(obj)
            i += obj.byte_length()
            continue
        i += 1
    return out^


def extract_number_array(text: String, key: String) -> List[Float64]:
    var out = List[Float64]()
    var i = _find_key(text, key)
    if i < 0:
        return out^
    if i >= text.byte_length() or _at(text, i) != "[":
        return out^
    i += 1
    var n = text.byte_length()
    while i < n:
        i = _skip_ws(text, i)
        if i < n and _at(text, i) == "]":
            break
        if i < n and _at(text, i) == ",":
            i += 1
            continue
        var ch = _at(text, i)
        if ch == "-" or ch == "+" or _hex_digit(ch) >= 0:
            var val = _parse_number_at(text, i, 0.0)
            out.append(val)
            if _at(text, i) == "-" or _at(text, i) == "+":
                i += 1
            while i < n:
                var c = _at(text, i)
                if c == "." or _hex_digit(c) >= 0:
                    i += 1
                    continue
                break
            continue
        i += 1
    return out^


def has_key(text: String, key: String) -> Bool:
    return _find_key(text, key) >= 0
