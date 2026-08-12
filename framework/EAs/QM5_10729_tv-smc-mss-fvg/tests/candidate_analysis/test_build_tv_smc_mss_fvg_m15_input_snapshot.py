from __future__ import annotations

import importlib.util
import io
import sys
from pathlib import Path


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "build_tv_smc_mss_fvg_m15_input_snapshot.py"
)
SPEC = importlib.util.spec_from_file_location("qm10729_snapshot", TOOL)
assert SPEC and SPEC.loader
snapshot = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = snapshot
SPEC.loader.exec_module(snapshot)


class GuardedFutureTail:
    """Raises if code reads any byte after the released future timestamp comma."""

    def __init__(self, payload: bytes, boundary: int):
        self.payload = payload
        self.boundary = boundary
        self.position = 0

    def read(self, size: int = -1) -> bytes:
        if self.position >= self.boundary:
            raise AssertionError("future OHLC tail was read")
        if size < 0:
            end = len(self.payload)
        else:
            end = min(len(self.payload), self.position + size)
        if end > self.boundary:
            raise AssertionError("read crossed into future OHLC tail")
        result = self.payload[self.position : end]
        self.position = end
        return result

    def readline(self) -> bytes:
        if self.position >= self.boundary:
            raise AssertionError("future OHLC tail readline attempted")
        newline = self.payload.find(b"\n", self.position)
        end = len(self.payload) if newline < 0 else newline + 1
        if end > self.boundary:
            raise AssertionError("readline crossed into future OHLC tail")
        result = self.payload[self.position : end]
        self.position = end
        return result


def test_fenced_projection_cannot_read_or_hash_future_tail() -> None:
    future_prefix = b"1672531200,"
    payload = (
        b"time,open,high,low,close,tickvol\r\n"
        b"1514764800,1,2,1,2,3\r\n"
        + future_prefix
        + b"FORBIDDEN_FUTURE_OHLC_MUST_NEVER_BE_READ\r\n"
    )
    boundary = payload.index(future_prefix) + len(future_prefix)
    reader = GuardedFutureTail(payload, boundary)
    writer = io.BytesIO()

    identity = snapshot._copy_fenced_market_stream(reader, writer)

    assert reader.position == boundary
    assert writer.getvalue() == (
        b"time,open,high,low,close,tickvol\r\n"
        b"1514764800,1,2,1,2,3\r\n"
        b"1672531200,\n"
    )
    assert b"FORBIDDEN" not in writer.getvalue()
    assert identity["future_ohlc_tail_read"] is False
    assert identity["exact_in_window_rows"] == 1
    assert identity["first_excluded_timestamp"] == "2023-01-01T00:00:00"
