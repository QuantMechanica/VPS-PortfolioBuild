"""Resumable, throttled downloader for Dukascopy hourly tick archives.

This is an I/O-only source stage. It never initializes MetaTrader, touches a
custom-symbol history directory, or submits a factory work item.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import http.client
import ipaddress
import json
import logging
import socket
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable, Iterable, Mapping

try:
    from .common import (
        CANONICAL_SYMBOLS,
        UTC,
        append_json_line,
        atomic_write_bytes,
        atomic_write_json,
        canonical_instrument,
        format_utc,
        hourly_relative_path,
        hourly_url,
        inspect_hourly_bi5,
        iter_hours,
        load_json_lines,
        parse_utc,
        sha256_bytes,
        sha256_file,
        validate_symbol_matrix,
    )
except ImportError:  # direct script execution
    from common import (  # type: ignore
        CANONICAL_SYMBOLS,
        UTC,
        append_json_line,
        atomic_write_bytes,
        atomic_write_json,
        canonical_instrument,
        format_utc,
        hourly_relative_path,
        hourly_url,
        inspect_hourly_bi5,
        iter_hours,
        load_json_lines,
        parse_utc,
        sha256_bytes,
        sha256_file,
        validate_symbol_matrix,
    )


DEFAULT_BASE_URL = "https://datafeed.dukascopy.com/datafeed"
OVERLAP_FLOOR_UTC = dt.datetime(2025, 10, 1, tzinfo=UTC)
MANIFEST_SCHEMA = "qm.dukascopy-hourly-download-file/v1"
PROGRESS_SCHEMA = "qm.dukascopy-hourly-download-progress/v1"
USER_AGENT = "Mozilla/5.0 (compatible; QuantMechanica-Dukascopy-Backfill/1.0)"

FetchResult = tuple[int, Mapping[str, str], bytes]
Fetcher = Callable[[str, float], FetchResult]


class RequestRateLimiter:
    def __init__(
        self,
        requests_per_second: float,
        *,
        clock: Callable[[], float] = time.monotonic,
        sleeper: Callable[[float], None] = time.sleep,
    ) -> None:
        if not 5.0 <= float(requests_per_second) <= 10.0:
            raise ValueError("request rate must be between 5 and 10 requests/second")
        self.interval = 1.0 / float(requests_per_second)
        self.clock = clock
        self.sleeper = sleeper
        self.last_request: float | None = None

    def wait(self) -> None:
        now = self.clock()
        if self.last_request is not None:
            delay = self.interval - (now - self.last_request)
            if delay > 0:
                self.sleeper(delay)
                now = self.clock()
        self.last_request = now


def fetch_http(url: str, timeout_seconds: float) -> FetchResult:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/octet-stream"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            status = int(getattr(response, "status", response.getcode()))
            headers = {key.lower(): value for key, value in response.headers.items()}
            return status, headers, response.read()
    except urllib.error.HTTPError as exc:
        content = exc.read() if exc.fp is not None else b""
        return int(exc.code), {
            key.lower(): value for key, value in exc.headers.items()
        }, content


class ResolvedIPFetcher:
    """Connect to a reviewed IP while preserving the URL host for TLS/HTTP.

    This is an explicit workaround for a stale local resolver. The manifest
    retains the canonical HTTPS URL; certificate validation and SNI remain
    bound to that URL's hostname.
    """

    def __init__(self, resolved_ip: str) -> None:
        self.resolved_ip = str(ipaddress.ip_address(resolved_ip))
        self._socket: ssl.SSLSocket | None = None

    def _close(self) -> None:
        if self._socket is not None:
            try:
                self._socket.close()
            finally:
                self._socket = None

    def _connect(self, host: str, port: int, timeout_seconds: float) -> None:
        raw_socket = socket.create_connection(
            (self.resolved_ip, port), timeout=timeout_seconds
        )
        try:
            self._socket = ssl.create_default_context().wrap_socket(
                raw_socket, server_hostname=host
            )
            self._socket.settimeout(timeout_seconds)
        except BaseException:
            raw_socket.close()
            raise

    def __call__(self, url: str, timeout_seconds: float) -> FetchResult:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise ValueError("resolved-IP fetch requires an HTTPS URL with a host")
        port = parsed.port or 443
        request_target = urllib.parse.urlunsplit(("", "", parsed.path, parsed.query, ""))
        if self._socket is None:
            self._connect(parsed.hostname, port, timeout_seconds)
        assert self._socket is not None
        request = (
            f"GET {request_target} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}\r\n"
            f"User-Agent: {USER_AGENT}\r\n"
            "Accept: application/octet-stream\r\n"
            "Connection: keep-alive\r\n\r\n"
        ).encode("ascii")
        try:
            self._socket.sendall(request)
            response = http.client.HTTPResponse(self._socket)
            response.begin()
            headers = {key.lower(): value for key, value in response.getheaders()}
            content = response.read()
            if response.will_close:
                self._close()
            return int(response.status), headers, content
        except BaseException:
            self._close()
            raise

    def __del__(self) -> None:
        self._close()


def load_splice_times(path: Path) -> dict[str, dt.datetime]:
    """Load the governed tick-tail probe CSV without guessing broker time."""

    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "symbol" not in reader.fieldnames:
            raise ValueError("splice CSV must contain a symbol column")
        utc_field = next(
            (
                candidate
                for candidate in (
                    "last_tick_utc",
                    "splice_timestamp_utc",
                    "last_tick_time_utc",
                )
                if candidate in reader.fieldnames
            ),
            None,
        )
        if utc_field is None:
            raise ValueError(
                "splice CSV must contain last_tick_utc or splice_timestamp_utc; "
                "broker wall time is not guessed"
            )
        result: dict[str, dt.datetime] = {}
        for line_number, row in enumerate(reader, start=2):
            symbol = str(row.get("symbol") or "").strip().upper()
            if symbol not in CANONICAL_SYMBOLS:
                raise ValueError(
                    f"splice CSV line {line_number} has an unknown symbol: {symbol!r}"
                )
            if symbol in result:
                raise ValueError(f"duplicate splice symbol at line {line_number}: {symbol}")
            result[symbol] = parse_utc(str(row.get(utc_field) or ""))
    if not result:
        raise ValueError("splice CSV contains no rows")
    return result


def _planned_hours(
    symbols: Iterable[str],
    *,
    splice_times: Mapping[str, dt.datetime] | None,
    start_utc: dt.datetime | None,
    end_utc: dt.datetime,
) -> list[tuple[str, dt.datetime]]:
    plan: list[tuple[str, dt.datetime]] = []
    for raw_symbol in symbols:
        symbol = str(raw_symbol).strip().upper()
        canonical_instrument(symbol)
        if start_utc is not None:
            symbol_start = start_utc
        else:
            if splice_times is None or symbol not in splice_times:
                raise ValueError(f"no governed splice UTC timestamp for {symbol}")
            # This deliberately includes the full common overlap from 2025-10-01
            # whenever the splice is newer, while never skipping an older splice.
            symbol_start = min(splice_times[symbol], OVERLAP_FLOOR_UTC)
        if symbol_start >= end_utc:
            raise ValueError(
                f"download window is empty for {symbol}: "
                f"{format_utc(symbol_start)} >= {format_utc(end_utc)}"
            )
        plan.extend((symbol, hour) for hour in iter_hours(symbol_start, end_utc))
    return plan


def _valid_resumed_entry(entry: Mapping[str, object], raw_root: Path) -> bool:
    if entry.get("status") == "no_data":
        return True
    if entry.get("status") != "downloaded":
        return False
    relative = Path(str(entry.get("relative_path") or ""))
    path = (raw_root / relative).resolve()
    if raw_root.resolve() not in path.parents:
        return False
    expected_sha = str(entry.get("sha256") or "").lower()
    expected_bytes = int(entry.get("bytes") or -1)
    return (
        path.is_file()
        and path.stat().st_size == expected_bytes
        and len(expected_sha) == 64
        and sha256_file(path).lower() == expected_sha
    )


def run_download(
    *,
    out_dir: Path,
    symbols: Iterable[str],
    end_utc: dt.datetime,
    splice_times: Mapping[str, dt.datetime] | None = None,
    start_utc: dt.datetime | None = None,
    base_url: str = DEFAULT_BASE_URL,
    requests_per_second: float = 5.0,
    timeout_seconds: float = 30.0,
    retries: int = 3,
    fetcher: Fetcher = fetch_http,
    limiter: RequestRateLimiter | None = None,
    logger: logging.Logger | None = None,
    resolved_ip: str | None = None,
) -> dict[str, object]:
    if retries < 1 or retries > 8:
        raise ValueError("retries must be between 1 and 8")
    if not 5 <= timeout_seconds <= 180:
        raise ValueError("HTTP timeout must be between 5 and 180 seconds")
    if end_utc.astimezone(UTC) > dt.datetime.now(UTC) + dt.timedelta(minutes=5):
        raise ValueError("download end may not be in the future")
    out_dir = out_dir.resolve()
    raw_root = out_dir / "raw"
    raw_root.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "download_manifest.jsonl"
    progress_path = out_dir / "progress.json"
    log = logger or logging.getLogger("qm.dukascopy.download")
    rate_limiter = limiter or RequestRateLimiter(requests_per_second)
    normalized_symbols = tuple(sorted({str(value).strip().upper() for value in symbols}))
    plan = _planned_hours(
        normalized_symbols,
        splice_times=splice_times,
        start_utc=start_utc,
        end_utc=end_utc,
    )

    prior_rows = load_json_lines(manifest_path)
    latest_by_url = {
        str(row.get("url") or ""): row
        for row in prior_rows
        if row.get("url")
    }
    counters = {
        "planned": len(plan),
        "completed": 0,
        "downloaded": 0,
        "resumed": 0,
        "no_data": 0,
        "errors": 0,
    }
    started_at = dt.datetime.now(UTC)

    def progress(current_url: str | None, status: str) -> None:
        atomic_write_json(
            progress_path,
            {
                "schema": PROGRESS_SCHEMA,
                "status": status,
                "started_at_utc": format_utc(started_at),
                "updated_at_utc": format_utc(dt.datetime.now(UTC)),
                "base_url": base_url,
                "resolved_ip_override": resolved_ip,
                "symbols": normalized_symbols,
                "current_url": current_url,
                **counters,
            },
        )

    progress(None, "RUNNING")
    for symbol, hour in plan:
        url = hourly_url(base_url, symbol, hour)
        relative = hourly_relative_path(symbol, hour)
        destination = (raw_root / relative).resolve()
        if raw_root not in destination.parents:
            raise ValueError(f"download destination escaped raw root: {destination}")
        existing = latest_by_url.get(url)
        if existing is not None and _valid_resumed_entry(existing, raw_root):
            counters["completed"] += 1
            counters["resumed"] += 1
            progress(url, "RUNNING")
            continue

        row_base: dict[str, object] = {
            "schema": MANIFEST_SCHEMA,
            "symbol": symbol,
            "source_instrument": canonical_instrument(symbol),
            "hour_utc": format_utc(hour),
            "url": url,
            "relative_path": relative.as_posix(),
        }
        final_row: dict[str, object] | None = None
        last_error = "request did not run"
        for attempt in range(1, retries + 1):
            rate_limiter.wait()
            try:
                status, headers, content = fetcher(url, timeout_seconds)
                if status in {204, 404, 410} or (status == 200 and not content):
                    final_row = {
                        **row_base,
                        "status": "no_data",
                        "http_status": status,
                        "attempt": attempt,
                        "recorded_at_utc": format_utc(dt.datetime.now(UTC)),
                    }
                    break
                if status != 200:
                    raise RuntimeError(f"HTTP {status}")
                inspection = inspect_hourly_bi5(content)
                atomic_write_bytes(destination, content)
                final_row = {
                    **row_base,
                    "status": "downloaded",
                    "http_status": status,
                    "content_type": str(headers.get("content-type") or ""),
                    "attempt": attempt,
                    "bytes": len(content),
                    "sha256": sha256_bytes(content),
                    "decoded_records": inspection["records"],
                    "decompressed_bytes": inspection["raw_bytes"],
                    "recorded_at_utc": format_utc(dt.datetime.now(UTC)),
                }
                break
            except (
                OSError,
                RuntimeError,
                ValueError,
                socket.timeout,
                urllib.error.URLError,
            ) as exc:
                last_error = f"{type(exc).__name__}: {exc}"
                log.warning("download attempt %d/%d failed: %s %s", attempt, retries, url, last_error)
                if attempt < retries:
                    time.sleep(min(2 ** (attempt - 1), 8))
        if final_row is None:
            final_row = {
                **row_base,
                "status": "error",
                "error": last_error,
                "attempt": retries,
                "recorded_at_utc": format_utc(dt.datetime.now(UTC)),
            }
        append_json_line(manifest_path, final_row)
        latest_by_url[url] = final_row
        counters["completed"] += 1
        status = str(final_row["status"])
        if status == "downloaded":
            counters["downloaded"] += 1
        elif status == "no_data":
            counters["no_data"] += 1
        else:
            counters["errors"] += 1
        progress(url, "RUNNING")

    final_status = "PASS" if counters["errors"] == 0 else "FAIL"
    progress(None, final_status)
    result: dict[str, object] = {
        "schema": PROGRESS_SCHEMA,
        "status": final_status,
        "production_import": False,
        "started_at_utc": format_utc(started_at),
        "completed_at_utc": format_utc(dt.datetime.now(UTC)),
        "out_dir": str(out_dir),
        "manifest_path": str(manifest_path),
        "progress_path": str(progress_path),
        "symbols": normalized_symbols,
        "resolved_ip_override": resolved_ip,
        **counters,
    }
    atomic_write_json(out_dir / "download_receipt.json", result)
    return result


def _configure_logging(path: Path) -> logging.Logger:
    path.parent.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("qm.dukascopy.download")
    logger.handlers.clear()
    logger.setLevel(logging.INFO)
    handler = logging.FileHandler(path, encoding="utf-8")
    formatter = logging.Formatter("%(asctime)sZ %(levelname)s %(message)s")
    formatter.converter = time.gmtime
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.propagate = False
    return logger


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--splice-csv", type=Path)
    parser.add_argument("--symbol", action="append", dest="symbols")
    parser.add_argument("--start-utc", help="explicit dry-run override; ISO-8601 with offset")
    parser.add_argument("--end-utc", help="exclusive ISO-8601 end; default now")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument(
        "--resolve-ip",
        help="reviewed DNS override; keeps canonical URL host for TLS certificate and SNI",
    )
    parser.add_argument("--rate", type=float, default=5.0)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--log", type=Path)
    parser.add_argument(
        "--symbol-matrix",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "framework/registry/dwx_symbol_matrix.csv",
    )
    args = parser.parse_args(argv)

    validate_symbol_matrix(args.symbol_matrix.resolve())
    splice_times = load_splice_times(args.splice_csv.resolve()) if args.splice_csv else None
    if args.splice_csv and not args.symbols and set(splice_times or {}) != set(CANONICAL_SYMBOLS):
        parser.error("a full splice CSV run must contain exactly the 37-symbol universe")
    symbols = args.symbols or (tuple(splice_times) if splice_times else CANONICAL_SYMBOLS)
    start_utc = parse_utc(args.start_utc) if args.start_utc else None
    if start_utc is None and splice_times is None:
        parser.error("--splice-csv is required unless --start-utc is supplied")
    # A default night run consumes only closed hourly objects. Requesting an
    # in-progress hour could persist a partial file that a later resume would
    # correctly authenticate but incorrectly treat as complete.
    end_utc = (
        parse_utc(args.end_utc)
        if args.end_utc
        else dt.datetime.now(UTC).replace(minute=0, second=0, microsecond=0)
    )
    log_path = (args.log or (args.out / "download.log")).resolve()
    logger = _configure_logging(log_path)
    fetcher: Fetcher = ResolvedIPFetcher(args.resolve_ip) if args.resolve_ip else fetch_http
    try:
        result = run_download(
            out_dir=args.out,
            symbols=symbols,
            splice_times=splice_times,
            start_utc=start_utc,
            end_utc=end_utc,
            base_url=args.base_url,
            requests_per_second=args.rate,
            timeout_seconds=args.timeout,
            retries=args.retries,
            fetcher=fetcher,
            logger=logger,
            resolved_ip=args.resolve_ip,
        )
    except (OSError, ValueError) as exc:
        logger.exception("download refused")
        print(json.dumps({"status": "REFUSED", "error": str(exc), "log": str(log_path)}))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
