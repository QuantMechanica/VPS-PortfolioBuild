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
import random
import socket
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
from pathlib import Path
from typing import Callable, Iterable, Mapping

import requests

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
LEDGER_SCHEMA = "qm.dukascopy-hourly-download-ledger/v1"
USER_AGENT = "Mozilla/5.0 (compatible; QuantMechanica-Dukascopy-Backfill/1.0)"

FetchResult = tuple[int, Mapping[str, str], bytes]
Fetcher = Callable[[str, float], FetchResult]


def assert_contained_destination(raw_root: Path, destination: Path) -> None:
    """Reject only a resolved destination that is actually outside raw_root.

    Both operands must already be resolved.  Windows may attach the extended
    path prefix during ``Path.resolve()``, so mixing a lexical root with a
    resolved destination creates a false path-escape result.
    """

    if destination != raw_root and raw_root not in destination.parents:
        raise ValueError(f"download destination escaped raw root: {destination}")


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
        self._lock = threading.Lock()

    def wait(self) -> None:
        # All downloader threads share one limiter, so concurrency cannot turn
        # the 5-10 request/s contract into a per-thread rate.
        with self._lock:
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


class SessionFetcher:
    """Thread-local keep-alive sessions with opt-out proxy-env support."""

    def __init__(self, *, proxy_env: bool = True) -> None:
        self.proxy_env = proxy_env
        self._local = threading.local()

    def _session(self) -> requests.Session:
        session = getattr(self._local, "session", None)
        if session is None:
            session = requests.Session()
            session.trust_env = self.proxy_env
            session.headers.update(
                {"User-Agent": USER_AGENT, "Accept": "application/octet-stream"}
            )
            adapter = requests.adapters.HTTPAdapter(
                pool_connections=1, pool_maxsize=1, max_retries=0, pool_block=True
            )
            session.mount("https://", adapter)
            session.mount("http://", adapter)
            self._local.session = session
        return session

    def __call__(self, url: str, timeout_seconds: float) -> FetchResult:
        response = self._session().get(url, timeout=timeout_seconds)
        return (
            int(response.status_code),
            {key.lower(): value for key, value in response.headers.items()},
            response.content,
        )


class ResolvedIPFetcher:
    """Connect to a reviewed IP while preserving the URL host for TLS/HTTP.

    This is an explicit workaround for a stale local resolver. The manifest
    retains the canonical HTTPS URL; certificate validation and SNI remain
    bound to that URL's hostname.
    """

    def __init__(self, resolved_ip: str) -> None:
        self.resolved_ip = str(ipaddress.ip_address(resolved_ip))
        self._local = threading.local()

    def _socket(self) -> ssl.SSLSocket | None:
        return getattr(self._local, "socket", None)

    def _close(self) -> None:
        active = self._socket()
        if active is not None:
            try:
                active.close()
            finally:
                self._local.socket = None

    def _connect(self, host: str, port: int, timeout_seconds: float) -> None:
        raw_socket = socket.create_connection(
            (self.resolved_ip, port), timeout=timeout_seconds
        )
        try:
            self._local.socket = ssl.create_default_context().wrap_socket(
                raw_socket, server_hostname=host
            )
            self._local.socket.settimeout(timeout_seconds)
        except BaseException:
            raw_socket.close()
            raise

    def __call__(self, url: str, timeout_seconds: float) -> FetchResult:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise ValueError("resolved-IP fetch requires an HTTPS URL with a host")
        port = parsed.port or 443
        request_target = urllib.parse.urlunsplit(("", "", parsed.path, parsed.query, ""))
        if self._socket() is None:
            self._connect(parsed.hostname, port, timeout_seconds)
        active = self._socket()
        assert active is not None
        request = (
            f"GET {request_target} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}\r\n"
            f"User-Agent: {USER_AGENT}\r\n"
            "Accept: application/octet-stream\r\n"
            "Connection: keep-alive\r\n\r\n"
        ).encode("ascii")
        try:
            active.sendall(request)
            response = http.client.HTTPResponse(active)
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
    concurrency: int = 6,
    fetcher: Fetcher | None = None,
    limiter: RequestRateLimiter | None = None,
    logger: logging.Logger | None = None,
    resolved_ip: str | None = None,
    proxy_env: bool = True,
    measure_files: int | None = None,
    projection_hours: int | None = None,
    backoff_base_seconds: float = 1.0,
    backoff_cap_seconds: float = 30.0,
    sleeper: Callable[[float], None] = time.sleep,
    randomizer: Callable[[], float] = random.random,
) -> dict[str, object]:
    if retries < 1 or retries > 8:
        raise ValueError("retries must be between 1 and 8")
    if not 5 <= timeout_seconds <= 180:
        raise ValueError("HTTP timeout must be between 5 and 180 seconds")
    if not 1 <= concurrency <= 32:
        raise ValueError("concurrency must be between 1 and 32")
    if measure_files is not None and measure_files < 1:
        raise ValueError("measure_files must be positive")
    if projection_hours is not None and projection_hours < 1:
        raise ValueError("projection_hours must be positive")
    if backoff_base_seconds < 0 or backoff_cap_seconds < backoff_base_seconds:
        raise ValueError("invalid retry backoff bounds")
    if end_utc.astimezone(UTC) > dt.datetime.now(UTC) + dt.timedelta(minutes=5):
        raise ValueError("download end may not be in the future")
    out_dir = out_dir.resolve()
    raw_root = (out_dir / "raw").resolve()
    raw_root.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "download_manifest.jsonl"
    ledger_path = out_dir / "hour_ledger.jsonl"
    progress_path = out_dir / "progress.json"
    log = logger or logging.getLogger("qm.dukascopy.download")
    rate_limiter = limiter or RequestRateLimiter(requests_per_second)
    normalized_symbols = tuple(sorted({str(value).strip().upper() for value in symbols}))
    full_plan = _planned_hours(
        normalized_symbols,
        splice_times=splice_times,
        start_utc=start_utc,
        end_utc=end_utc,
    )
    full_plan_hours = len(full_plan)
    projected_target_hours = projection_hours or full_plan_hours
    plan = full_plan[:measure_files] if measure_files is not None else full_plan
    del full_plan
    active_fetcher: Fetcher
    if fetcher is not None:
        active_fetcher = fetcher
    elif resolved_ip:
        active_fetcher = ResolvedIPFetcher(resolved_ip)
    else:
        active_fetcher = SessionFetcher(proxy_env=proxy_env)

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
                "proxy_env_enabled": proxy_env,
                "concurrency": concurrency,
                "measurement": measure_files is not None,
                "full_plan_hours": full_plan_hours,
                "projected_target_hours": projected_target_hours,
                "symbols": normalized_symbols,
                "current_url": current_url,
                **counters,
            },
        )

    def record(final_row: dict[str, object]) -> None:
        append_json_line(manifest_path, final_row)
        url = str(final_row["url"])
        latest_by_url[url] = final_row
        status = str(final_row["status"])
        append_json_line(
            ledger_path,
            {
                "schema": LEDGER_SCHEMA,
                "url": url,
                "symbol": final_row["symbol"],
                "hour_utc": final_row["hour_utc"],
                "state": "failed" if status == "error" else "done",
                "outcome": status,
                "attempts": final_row.get("attempt", 0),
                "recorded_at_utc": final_row["recorded_at_utc"],
            },
        )
        counters["completed"] += 1
        if status == "downloaded":
            counters["downloaded"] += 1
        elif status == "no_data":
            counters["no_data"] += 1
        else:
            counters["errors"] += 1
        progress(url, "RUNNING")

    def fetch_one(symbol: str, hour: dt.datetime) -> dict[str, object]:
        url = hourly_url(base_url, symbol, hour)
        relative = hourly_relative_path(symbol, hour)
        destination = (raw_root / relative).resolve()
        assert_contained_destination(raw_root, destination)
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
                status, headers, content = active_fetcher(url, timeout_seconds)
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
            except (OSError, RuntimeError, ValueError, requests.RequestException) as exc:
                last_error = f"{type(exc).__name__}: {exc}"
                log.warning("download attempt %d/%d failed: %s %s", attempt, retries, url, last_error)
                if attempt < retries:
                    exponential = min(
                        backoff_cap_seconds,
                        backoff_base_seconds * (2 ** (attempt - 1)),
                    )
                    # Multiplying by [0.5, 1.5) retains exponential growth but
                    # prevents synchronized retries from six workers.
                    sleeper(exponential * (0.5 + randomizer()))
        if final_row is None:
            final_row = {
                **row_base,
                "status": "error",
                "error": last_error,
                "attempt": retries,
                "recorded_at_utc": format_utc(dt.datetime.now(UTC)),
            }
        return final_row

    progress(None, "RUNNING")
    work_plan: list[tuple[str, dt.datetime]] = []
    for symbol, hour in plan:
        url = hourly_url(base_url, symbol, hour)
        existing = latest_by_url.get(url)
        if existing is not None and _valid_resumed_entry(existing, raw_root):
            counters["completed"] += 1
            counters["resumed"] += 1
            progress(url, "RUNNING")
        else:
            work_plan.append((symbol, hour))

    # Keep only a bounded number of futures live. A production plan has more
    # than 300k rows, so submitting the entire plan would itself be a memory bug.
    iterator = iter(work_plan)
    with ThreadPoolExecutor(max_workers=concurrency, thread_name_prefix="duka") as pool:
        active: dict[Future[dict[str, object]], tuple[str, dt.datetime]] = {}
        for _ in range(concurrency):
            try:
                item = next(iterator)
            except StopIteration:
                break
            active[pool.submit(fetch_one, *item)] = item
        while active:
            done, _ = wait(active, return_when=FIRST_COMPLETED)
            for future in done:
                active.pop(future)
                record(future.result())
                try:
                    item = next(iterator)
                except StopIteration:
                    continue
                active[pool.submit(fetch_one, *item)] = item

    elapsed_seconds = max((dt.datetime.now(UTC) - started_at).total_seconds(), 1e-9)
    successful_hours = counters["downloaded"] + counters["no_data"] + counters["resumed"]
    hours_per_minute = successful_hours / elapsed_seconds * 60.0
    projected_seconds = (
        projected_target_hours / hours_per_minute * 60.0
        if hours_per_minute > 0
        else None
    )
    final_status = (
        "MEASURED"
        if measure_files is not None
        else ("PASS" if counters["errors"] == 0 else "FAIL")
    )
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
        "ledger_path": str(ledger_path),
        "symbols": normalized_symbols,
        "resolved_ip_override": resolved_ip,
        "proxy_env_enabled": proxy_env,
        "concurrency": concurrency,
        "measurement": measure_files is not None,
        "sample_files": len(plan) if measure_files is not None else None,
        "full_plan_hours": full_plan_hours,
        "projected_target_hours": projected_target_hours,
        "elapsed_seconds": round(elapsed_seconds, 6),
        "success_rate": successful_hours / len(plan) if plan else 0.0,
        "hours_per_minute": hours_per_minute,
        "projected_wall_seconds": projected_seconds,
        "projected_wall_days": projected_seconds / 86400.0 if projected_seconds else None,
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
    parser.add_argument("--retries", type=int, default=5)
    parser.add_argument("--concurrency", type=int, default=6)
    parser.add_argument(
        "--no-proxy-env",
        action="store_true",
        help="ignore HTTP_PROXY/HTTPS_PROXY/NO_PROXY instead of passing them to sessions",
    )
    parser.add_argument(
        "--measure",
        type=int,
        metavar="N",
        help="download only the first N planned hour-files and emit throughput projection",
    )
    parser.add_argument(
        "--projection-hours",
        type=int,
        help="fixed total hour-file count used for a measurement projection",
    )
    parser.add_argument("--backoff-base", type=float, default=1.0)
    parser.add_argument("--backoff-cap", type=float, default=30.0)
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
            concurrency=args.concurrency,
            logger=logger,
            resolved_ip=args.resolve_ip,
            proxy_env=not args.no_proxy_env,
            measure_files=args.measure,
            projection_hours=args.projection_hours,
            backoff_base_seconds=args.backoff_base,
            backoff_cap_seconds=args.backoff_cap,
        )
    except (OSError, ValueError) as exc:
        logger.exception("download refused")
        print(json.dumps({"status": "REFUSED", "error": str(exc), "log": str(log_path)}))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] in {"PASS", "MEASURED"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
