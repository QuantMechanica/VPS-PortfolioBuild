"""Authenticate governed setfile build-hash transitions.

``gen_setfile.ps1`` writes UTF-8/no-BOM LF bytes with one canonical
``; build_hash:   pending`` header. ``build_check.ps1`` then reads those lines,
normalizes them to CRLF, hashes that normalized *pending* representation, and
replaces only the header value with the resulting lower-case SHA-256.

Historical COMPILE_EA evidence sealed the generator bytes before build_check
performed that deterministic rewrite.  A later governed publish step may
restamp only that header to the exact COMPILE_OK EX5 hash.  This module proves
either exact reversible transition; it never treats arbitrary current bytes as
an acceptable successor.
"""

from __future__ import annotations

import hashlib
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


SETFILE_BUILD_HASH_TRANSITION_SCHEMA = "qm.setfile-build-hash-transition/v1"
GEN_SETFILE_CONTRACT = "framework/scripts/gen_setfile.ps1:utf8-no-bom-lf-pending/v1"
BUILD_CHECK_STAMP_CONTRACT = (
    "framework/scripts/build_check.ps1:Update-SetFileBuildHash/v1"
)
AUTHENTICATED_EX5_RESTAMP_CONTRACT = (
    "qm.authenticated-compile-ex5-build-hash-restamp/v1"
)
PENDING_BUILD_HASH_LINE = "; build_hash:   pending"

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_BUILD_HASH_HEADER_RE = re.compile(r"^\s*;\s*build_hash\s*:", re.IGNORECASE)
_FINAL_BUILD_HASH_LINE_RE = re.compile(r"^; build_hash:   ([0-9a-f]{64})$")
_HEADER_RE = re.compile(
    r"^\s*;\s*(?P<key>[A-Za-z0-9_]+)\s*:\s*(?P<value>.*)$"
)
_ASSIGNMENT_RE = re.compile(r"^(?P<key>[A-Za-z_][A-Za-z0-9_]*)=(?P<value>.*)$")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _refusal(reason: str, detail: Any = None, **values: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema": SETFILE_BUILD_HASH_TRANSITION_SCHEMA,
        "ok": False,
        "reason": reason,
    }
    if detail is not None:
        result["detail"] = detail
    result.update(values)
    return result


def _single_value(
    values: dict[str, list[str]], key: str
) -> tuple[str | None, str | None]:
    found = values.get(key.casefold(), [])
    if len(found) != 1:
        return None, f"{key} occurrence count={len(found)}; require exactly one"
    return found[0], None


def authenticate_setfile_build_hash_transition(
    generated_setfile_sha256: str,
    final_bytes: bytes,
    *,
    expected_ex5_sha256: str | None = None,
) -> dict[str, Any]:
    """Prove an exact generator-to-governed-final setfile transition.

    The pre-build bytes are reconstructed from the final file only by replacing
    the one canonical build_hash header with ``pending`` and restoring the
    generator's LF/no-BOM representation.  The reconstruction must hash to
    ``generated_setfile_sha256``.  The final representation must then be either
    build_check's exact CRLF/self-stamped output or the exact LF representation
    whose stamp equals ``expected_ex5_sha256``.  This proves all executable
    assignments (including risk settings) are unchanged.
    """

    generated_sha = str(generated_setfile_sha256 or "").strip().lower()
    if not _SHA256_RE.fullmatch(generated_sha):
        return _refusal(
            "generated_setfile_sha256_invalid", generated_setfile_sha256
        )
    if not isinstance(final_bytes, bytes) or not final_bytes:
        return _refusal("final_setfile_bytes_missing")
    expected_ex5 = str(expected_ex5_sha256 or "").strip().lower()
    if expected_ex5 and not _SHA256_RE.fullmatch(expected_ex5):
        return _refusal("expected_ex5_sha256_invalid", expected_ex5_sha256)

    has_utf8_bom = final_bytes.startswith(b"\xef\xbb\xbf")
    body = final_bytes[3:] if has_utf8_bom else final_bytes
    try:
        text = body.decode("utf-8")
    except UnicodeDecodeError as exc:
        return _refusal("final_setfile_not_utf8", str(exc))

    lines = text.splitlines()
    header_indexes = [
        index for index, line in enumerate(lines) if _BUILD_HASH_HEADER_RE.match(line)
    ]
    if len(header_indexes) != 1:
        return _refusal(
            "build_hash_header_count_invalid",
            f"count={len(header_indexes)}; require exactly one",
        )
    header_index = header_indexes[0]
    stamp_match = _FINAL_BUILD_HASH_LINE_RE.fullmatch(lines[header_index])
    if stamp_match is None:
        return _refusal(
            "final_build_hash_line_not_canonical", lines[header_index]
        )

    canonical_ex5_restamp_bytes = ("\n".join(lines) + "\n").encode("utf-8")

    pending_lines = list(lines)
    pending_lines[header_index] = PENDING_BUILD_HASH_LINE
    normalized_pending_text = "\r\n".join(pending_lines) + "\r\n"
    expected_stamp = _sha256(normalized_pending_text.encode("utf-8"))
    observed_stamp = stamp_match.group(1)
    build_check_lines = list(lines)
    build_check_lines[header_index] = f"; build_hash:   {expected_stamp}"
    canonical_build_check_text = "\r\n".join(build_check_lines) + "\r\n"
    canonical_build_check_bytes = canonical_build_check_text.encode("utf-8")
    reconstructed_build_check_final_sha = _sha256(canonical_build_check_bytes)

    # gen_setfile.ps1's byte contract is LF, no BOM, and one trailing newline.
    # A BOM-bearing final file therefore cannot be the successor of that
    # generator contract even though build_check itself knows how to preserve
    # BOMs for other callers.
    generated_bytes = ("\n".join(pending_lines) + "\n").encode("utf-8")
    reconstructed_generated_sha = _sha256(generated_bytes)
    if has_utf8_bom or reconstructed_generated_sha != generated_sha:
        return _refusal(
            "generated_setfile_bytes_not_exact_preimage",
            {
                "sealed_generated_sha256": generated_sha,
                "reconstructed_generated_sha256": reconstructed_generated_sha,
                "final_has_utf8_bom": has_utf8_bom,
            },
        )

    if (
        canonical_build_check_bytes == final_bytes
        and observed_stamp == expected_stamp
    ):
        transition_mode = "build_check_normalized_pending_stamp"
        stamper_contract = BUILD_CHECK_STAMP_CONTRACT
        source_artifact = {
            "kind": "normalized_pending_setfile",
            "sha256": expected_stamp,
        }
        recognized_changes = [
            "line_endings:LF->CRLF",
            "header.build_hash:pending->normalized_pending_sha256",
        ]
    elif (
        expected_ex5
        and canonical_ex5_restamp_bytes == final_bytes
        and observed_stamp == expected_ex5
        and not has_utf8_bom
    ):
        transition_mode = "authenticated_ex5_hash_restamp"
        stamper_contract = AUTHENTICATED_EX5_RESTAMP_CONTRACT
        source_artifact = {"kind": "COMPILE_OK.ex5", "sha256": expected_ex5}
        recognized_changes = [
            "header.build_hash:pending->authenticated_COMPILE_OK_ex5_sha256",
        ]
    else:
        return _refusal(
            "final_setfile_transition_not_recognized",
            {
                "observed_build_hash": observed_stamp,
                "expected_build_check_hash": expected_stamp,
                "expected_ex5_sha256": expected_ex5 or None,
                "is_build_check_canonical_bytes": (
                    canonical_build_check_bytes == final_bytes
                ),
                "is_ex5_restamp_canonical_bytes": (
                    canonical_ex5_restamp_bytes == final_bytes and not has_utf8_bom
                ),
            },
        )

    headers: dict[str, list[str]] = {}
    assignments: dict[str, list[str]] = {}
    for line in pending_lines:
        header = _HEADER_RE.match(line)
        if header:
            headers.setdefault(header.group("key").casefold(), []).append(
                header.group("value").strip()
            )
            continue
        assignment = _ASSIGNMENT_RE.match(line)
        if assignment:
            assignments.setdefault(assignment.group("key").casefold(), []).append(
                assignment.group("value").strip()
            )

    risk_fixed, risk_fixed_error = _single_value(assignments, "RISK_FIXED")
    risk_percent, risk_percent_error = _single_value(assignments, "RISK_PERCENT")
    if risk_fixed_error or risk_percent_error:
        return _refusal(
            "risk_binding_missing_or_ambiguous",
            [value for value in (risk_fixed_error, risk_percent_error) if value],
        )
    try:
        fixed_value = Decimal(str(risk_fixed))
        percent_value = Decimal(str(risk_percent))
    except InvalidOperation:
        return _refusal(
            "risk_binding_not_numeric",
            {"RISK_FIXED": risk_fixed, "RISK_PERCENT": risk_percent},
        )
    if fixed_value <= 0 or percent_value != 0:
        return _refusal(
            "backtest_risk_binding_invalid",
            {"RISK_FIXED": risk_fixed, "RISK_PERCENT": risk_percent},
        )

    symbol, symbol_error = _single_value(headers, "symbol")
    environment, environment_error = _single_value(headers, "environment")
    if symbol_error or environment_error:
        return _refusal(
            "execution_header_missing_or_ambiguous",
            [value for value in (symbol_error, environment_error) if value],
        )
    if str(environment).casefold() != "backtest":
        return _refusal("setfile_environment_not_backtest", environment)

    assignment_lines = [
        line for line in pending_lines if _ASSIGNMENT_RE.match(line)
    ]
    assignment_bytes = ("\n".join(assignment_lines) + "\n").encode("utf-8")
    return {
        "schema": SETFILE_BUILD_HASH_TRANSITION_SCHEMA,
        "ok": True,
        "generator_contract": GEN_SETFILE_CONTRACT,
        "stamper_contract": stamper_contract,
        "transition_mode": transition_mode,
        "stamp_source_artifact": source_artifact,
        "generated_setfile_sha256": generated_sha,
        "reconstructed_generated_setfile_sha256": reconstructed_generated_sha,
        "normalized_pending_sha256": expected_stamp,
        "reconstructed_build_check_final_setfile_sha256": (
            reconstructed_build_check_final_sha
        ),
        "build_hash": observed_stamp,
        "final_setfile_sha256": _sha256(final_bytes),
        "input_assignments_sha256": _sha256(assignment_bytes),
        "input_assignments_unchanged": True,
        "only_recognized_changes": recognized_changes,
        "risk_fixed": str(risk_fixed),
        "risk_percent": str(risk_percent),
        "symbol": str(symbol),
        "environment": str(environment),
        "utf8_bom": False,
    }


def authenticate_setfile_build_hash_transition_path(
    generated_setfile_sha256: str,
    path: Path,
    *,
    expected_ex5_sha256: str | None = None,
) -> dict[str, Any]:
    """Path wrapper with a stable fail-closed read error."""

    try:
        final_bytes = path.read_bytes()
    except OSError as exc:
        return _refusal(
            "final_setfile_unreadable", {"path": str(path), "error": str(exc)}
        )
    return authenticate_setfile_build_hash_transition(
        generated_setfile_sha256,
        final_bytes,
        expected_ex5_sha256=expected_ex5_sha256,
    )
