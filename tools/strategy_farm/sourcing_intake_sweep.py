"""Weekly sourcing-intake sweep — OWNER's forwarded research links -> leads.csv.

OWNER forwards research links (reddit/YouTube/GitHub/articles) from his iPhone to
info@quantmechanica.com — this is his de-facto sourcing intake. A one-off manual sweep
(2026-07-19, session scratchpad `mailbox/reddit_urls.csv`) already extracted 128 historical
reddit URLs going back to March 2026. This script turns that into a standing, incremental,
read-only weekly process (task #30, OWNER go 2026-07-19).

WHAT IT DOES
  1. Connects IMAP4_SSL to Gmail read-only (readonly=True select + BODY.PEEK fetches —
     never sets \\Seen, never writes to the mailbox). Credentials:
     C:/QM/repo/.private/secrets/imap_info_quantmechanica.json ({host, port, user, password}).
     The password is never printed or logged anywhere in this module.
  2. Tracks a UID watermark per folder in intake_state.json so each run only looks at mail
     that arrived since the previous run (no full-history rescans — the one-off already
     covered history). On the very first run (no state file yet), there is no prior
     watermark to diff against, so the search window is bounded to "today" (IMAP SINCE,
     day granularity) instead of the full mailbox — this is the "watermark = now" behavior:
     it will not re-walk March-July history, but if OWNER forwarded something in the last
     few hours before this first run, it is still swept in. Every run (including the first)
     advances the persisted watermark to the mailbox's UIDNEXT-1 at run start, so the next
     run has an exact, gap-free UID lower bound.
  3. For mail found in the search window, filters (client-side, on the parsed From address)
     to self-sent mail only: fabian.grabner@gmail.com, or any address @quantmechanica.com,
     or any address @greiner-gpi.com. Non-matching mail is skipped (but still advances the
     watermark — it was considered, just not a sourcing forward).
  4. Extracts every http(s) URL from each matching mail's body (text/plain preferred, HTML
     stripped-to-text fallback — same approach as the one-off), classifies by domain:
       - reddit.com          -> not fetched (Reddit blocks generic scraping); queued for the
                                 reddit URL miner list.
       - youtube.com/youtu.be -> not fetched here; queued for the transcript-proxy miner
                                 (agy has no video tool — see MEMORY reference_agy_no_video_tool).
       - github.com          -> resolved via the public GitHub REST API
                                 (api.github.com/repos/{owner}/{repo}, unauthenticated,
                                 60 req/hr — comfortably above weekly volume) to get
                                 full_name + description, which stands in for a
                                 README-derived title without HTML scraping fragility. Falls
                                 back to generic <title> scraping if the URL isn't a plain
                                 owner/repo path (gists, issues, users, ...).
       - other               -> generic HTTPS GET (plain urllib, explicit User-Agent,
                                 10s timeout, capped read) for <title> + meta description.
     All external fetches are honestly-failed: on any error (timeout, DNS, 4xx/5xx, no
     title tag) the row is still recorded with resolved_title="" — never fabricated.
  5. Appends new rows to leads.csv (deduped against every URL already in the file, across
     all runs) and writes a full per-run markdown summary (title/description detail,
     failures with reasons, counts by domain, watermark before/after, runtime) plus a
     compact JSONL line to run_log.txt for fast "did it run" checks.

DESIGN NOTES
  - CSV schema is exactly the 6 columns specified in the task (date, source_mail_uid, url,
    domain_class, resolved_title, status) — status is literally "NEW" on append; downstream
    processes (a future miner / OWNER) may edit that column later to track triage. Fetched
    meta descriptions and failure reasons are richer than 6 columns can hold cleanly, so
    they live in the per-run summary .md instead of widening the CSV.
  - UIDVALIDITY is checked against the persisted state; if the server ever reassigns it
    (rare on Gmail, but would silently invalidate every stored UID), the run logs a warning
    and resets to "first run" behavior (bounded SINCE-today search) rather than either
    silently corrupting comparisons or replaying full history.
  - Robustness: connection/login failure is the only fatal condition (exit 1, nothing
    written except the summary noting the failure). Everything past a successful login is
    per-item try/except — a single unparseable mail or unreachable URL never aborts the
    run. Total external-fetch time is budgeted (~90s) so a week with many slow/dead links
    still finishes near the <2min runtime target; anything past budget is recorded
    unresolved with an explicit "time budget exceeded" reason rather than fetched.
  - Pure stdlib, no subprocess/console spawning — the CREATE_NO_WINDOW convention used
    elsewhere in this repo for wrapped subprocesses doesn't apply here.
  - Scheduled task registration is NOT performed by this script or by whoever writes it —
    see the prepared (unregistered) command in the task handoff. Weekly Monday 05:10,
    SYSTEM principal, pythonw.exe direct (no cmd/powershell stdout+stderr merge — avoids
    the known PS5.1 stderr-trap task-killer class), mirroring
    install_gmail_alarm_scheduled_task.ps1's pattern.

Run manually:  python tools/strategy_farm/sourcing_intake_sweep.py [--dry-run]
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import email
import email.utils
import gzip
import html as _html
import imaplib
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib
from email.header import decode_header, make_header
from pathlib import Path

# ── Paths / constants ──────────────────────────────────────────────────────
REPO_ROOT = Path(r"C:\QM\repo")
SECRETS_PATH = REPO_ROOT / ".private" / "secrets" / "imap_info_quantmechanica.json"

OUTPUT_DIR = Path(r"D:\QM\reports\sourcing_intake")
STATE_FILE = OUTPUT_DIR / "intake_state.json"
LEADS_CSV = OUTPUT_DIR / "leads.csv"
RUN_LOG = OUTPUT_DIR / "run_log.txt"
LEADS_CSV_FIELDS = ["date", "source_mail_uid", "url", "domain_class", "resolved_title", "status"]

IMAP_FOLDER = '"[Gmail]/Alle Nachrichten"'  # German Gmail "All Mail" — matches the proven
                                             # one-off sweep (scratchpad/mailbox/fetch.py).

SELF_SENDER_EXACT = {"fabian.grabner@gmail.com"}
SELF_SENDER_DOMAINS = {"quantmechanica.com", "greiner-gpi.com"}

USER_AGENT = "Mozilla/5.0 (compatible; QuantMechanicaIntakeBot/1.0; +https://quantmechanica.com)"
FETCH_TIMEOUT_SEC = 10
FETCH_MAX_BYTES = 200_000
TOTAL_FETCH_BUDGET_SEC = 90.0  # keeps overall runtime near the <2min target even in a
                                # week with many slow/dead "other" links.

MONTHS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

URL_RE = re.compile(r"https?://[^\s<>\"'\)\]]+")
TRAILING_PUNCT = ".,;:!?)]}'\""


# ── Small helpers ───────────────────────────────────────────────────────────

def _now_utc_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _imap_date_today() -> str:
    d = dt.date.today()
    return f"{d.day:02d}-{MONTHS_EN[d.month - 1]}-{d.year}"


def _decode_header_value(v: str | None) -> str:
    if not v:
        return ""
    try:
        return str(make_header(decode_header(v)))
    except Exception:
        return v


def _self_sender_email(from_header: str | None) -> str | None:
    """Return the sender address if it matches the self-forward allowlist, else None."""
    if not from_header:
        return None
    _, addr = email.utils.parseaddr(from_header)
    addr = (addr or "").strip().lower()
    if not addr:
        return None
    if addr in SELF_SENDER_EXACT:
        return addr
    domain = addr.rsplit("@", 1)[-1] if "@" in addr else ""
    if domain in SELF_SENDER_DOMAINS:
        return addr
    return None


def _html_to_text(body_html: str) -> str:
    h = re.sub(r"(?is)<(script|style).*?</\1>", " ", body_html)
    h = re.sub(r"(?is)<br\s*/?>", "\n", h)
    h = re.sub(r"(?is)</p>", "\n", h)
    h = re.sub(r"(?is)<[^>]+>", " ", h)
    h = _html.unescape(h)
    h = re.sub(r"[ \t]+", " ", h)
    h = re.sub(r"\n\s*\n+", "\n\n", h)
    return h


def _extract_body_text(msg: email.message.Message) -> str:
    body_txt = None
    body_html = None
    for part in msg.walk():
        ctype = part.get_content_type()
        if part.get_filename():
            continue
        if ctype == "text/plain" and body_txt is None:
            try:
                body_txt = part.get_payload(decode=True).decode(
                    part.get_content_charset() or "utf-8", "replace"
                )
            except Exception:
                body_txt = body_txt or ""
        elif ctype == "text/html" and body_html is None:
            try:
                body_html = part.get_payload(decode=True).decode(
                    part.get_content_charset() or "utf-8", "replace"
                )
            except Exception:
                body_html = body_html or ""
    if body_txt and body_txt.strip():
        return body_txt
    if body_html:
        return _html_to_text(body_html)
    return ""


def _extract_urls(text: str) -> list[str]:
    out: list[str] = []
    seen = set()
    for m in URL_RE.findall(text or ""):
        u = m
        while u and u[-1] in TRAILING_PUNCT:
            u = u[:-1]
        if not u or u in seen:
            continue
        seen.add(u)
        out.append(u)
    return out


def _classify_domain(url: str) -> str:
    try:
        host = urllib.parse.urlparse(url).netloc.lower()
    except Exception:
        return "other"
    if host.startswith("www."):
        host = host[4:]
    if host.endswith("reddit.com"):
        return "reddit"
    if host.endswith("youtube.com") or host.endswith("youtu.be"):
        return "youtube"
    if host.endswith("github.com"):
        return "github"
    return "other"


def _http_get(url: str, timeout: float, accept: str = "text/html,application/xhtml+xml") -> tuple[bytes | None, dict | None, str | None]:
    # Some CDNs (varnish/nginx in front of e.g. python.org) gzip the response even
    # without an Accept-Encoding request header, so decompress defensively regardless
    # of whether we asked for it.
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read(FETCH_MAX_BYTES)
            headers = dict(resp.headers.items())
    except urllib.error.HTTPError as exc:
        return None, None, f"HTTP {exc.code}"
    except urllib.error.URLError as exc:
        return None, None, f"URLError: {exc.reason}"
    except Exception as exc:  # noqa: BLE001 — external fetch, be maximally defensive
        return None, None, f"{type(exc).__name__}: {exc}"

    encoding = (headers.get("content-encoding") or headers.get("Content-Encoding") or "").lower()
    if "gzip" in encoding:
        try:
            raw = gzip.decompress(raw)
        except Exception:
            pass  # truncated by FETCH_MAX_BYTES cap — best effort, leave as-is
    elif "deflate" in encoding:
        try:
            raw = zlib.decompress(raw)
        except Exception:
            try:
                raw = zlib.decompress(raw, -zlib.MAX_WBITS)
            except Exception:
                pass
    elif "br" in encoding:
        return None, headers, "brotli-encoded response not supported (stdlib has no brotli decoder)"
    return raw, headers, None


def _extract_title(html_text: str) -> str:
    m = re.search(r"(?is)<title[^>]*>(.*?)</title>", html_text)
    if not m:
        return ""
    t = _html.unescape(re.sub(r"\s+", " ", m.group(1))).strip()
    return t[:300]


def _extract_meta_description(html_text: str) -> str:
    for tag_m in re.finditer(r"(?is)<meta\b([^>]*)>", html_text):
        attrs = tag_m.group(1)
        name_m = re.search(r'(?is)\bname\s*=\s*["\']?description["\']?', attrs)
        if not name_m:
            continue
        content_m = re.search(r'(?is)\bcontent\s*=\s*"([^"]*)"|\bcontent\s*=\s*\'([^\']*)\'', attrs)
        if content_m:
            val = content_m.group(1) or content_m.group(2) or ""
            return _html.unescape(re.sub(r"\s+", " ", val)).strip()[:400]
    return ""


def _fetch_generic_title(url: str) -> tuple[str, str, str | None]:
    raw, headers, err = _http_get(url, FETCH_TIMEOUT_SEC)
    if err is not None:
        return "", "", err
    charset = "utf-8"
    if headers:
        ctype = headers.get("Content-Type", "")
        cm = re.search(r"charset=([\w-]+)", ctype, re.I)
        if cm:
            charset = cm.group(1)
    try:
        text = raw.decode(charset, errors="replace")
    except Exception:
        text = raw.decode("utf-8", errors="replace")
    title = _extract_title(text)
    desc = _extract_meta_description(text)
    if not title:
        return "", desc, "no <title> tag found"
    return title, desc, None


def _fetch_github_meta(url: str) -> tuple[str, str, str | None]:
    try:
        parts = [p for p in urllib.parse.urlparse(url).path.split("/") if p]
    except Exception:
        parts = []
    if len(parts) >= 2:
        owner, repo = parts[0], parts[1]
        if repo.endswith(".git"):
            repo = repo[:-4]
        api_url = f"https://api.github.com/repos/{owner}/{repo}"
        raw, _headers, err = _http_get(
            api_url, FETCH_TIMEOUT_SEC, accept="application/vnd.github+json"
        )
        if err is None:
            try:
                data = json.loads(raw.decode("utf-8", "replace"))
                full_name = data.get("full_name") or f"{owner}/{repo}"
                desc = data.get("description") or ""
                title = f"{full_name}: {desc}" if desc else full_name
                return title, desc, None
            except Exception as exc:  # noqa: BLE001
                err = f"github API JSON parse failed: {exc}"
        # Fall through to generic HTML title scrape on API failure (private repo,
        # rate limit, 404, malformed JSON, ...) — still "if reachable".
        title, desc, gerr = _fetch_generic_title(url)
        if title:
            return title, desc, None
        return "", "", f"github API failed ({err}); html fallback failed ({gerr})"
    # Not a plain owner/repo path (gist, issue, user profile, github.com root, ...)
    return _fetch_generic_title(url)


# ── State ────────────────────────────────────────────────────────────────

def _load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _save_state(state: dict, dry_run: bool) -> None:
    if dry_run:
        return
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")


def _load_existing_urls() -> set[str]:
    if not LEADS_CSV.exists():
        return set()
    urls: set[str] = set()
    try:
        with LEADS_CSV.open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                u = (row.get("url") or "").strip()
                if u:
                    urls.add(u)
    except Exception:
        pass
    return urls


def _append_leads(rows: list[dict], dry_run: bool) -> None:
    if not rows or dry_run:
        return
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_header = not LEADS_CSV.exists()
    with LEADS_CSV.open("a", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=LEADS_CSV_FIELDS)
        if write_header:
            w.writeheader()
        for row in rows:
            w.writerow(row)


def _append_run_log(entry: dict, dry_run: bool) -> None:
    if dry_run:
        return
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with RUN_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, sort_keys=True) + "\n")


def _write_summary(lines: list[str], run_ts: str, dry_run: bool) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    prefix = "DRYRUN_summary_" if dry_run else "summary_"
    path = OUTPUT_DIR / f"{prefix}{run_ts}.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


# ── Main sweep ───────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true",
                     help="Do not write leads.csv / intake_state.json / summary / run_log; print only.")
    args = ap.parse_args()

    run_start = time.monotonic()
    run_start_utc = _now_utc_iso()
    run_ts = run_start_utc.replace(":", "").replace("-", "")

    summary: list[str] = [
        f"# Sourcing Intake Sweep — run {run_start_utc}",
        "",
        f"Dry run: {args.dry_run}",
        "",
    ]

    # ── Credentials ──
    try:
        cfg = json.loads(SECRETS_PATH.read_text(encoding="utf-8-sig"))
        host = cfg["host"]
        port = int(cfg.get("port", 993))
        user = cfg["user"]
        password = cfg["password"].replace(" ", "")
    except Exception as exc:
        summary.append(f"FATAL: could not load IMAP credentials from {SECRETS_PATH}: {type(exc).__name__}: {exc}")
        _write_summary(summary, run_ts, args.dry_run)
        print("FATAL: credential load failed (see summary; password never printed)")
        return 1

    # ── Connect (read-only) ──
    M = None
    try:
        M = imaplib.IMAP4_SSL(host, port)
        M.login(user, password)
        del password  # never touched again
        typ, _ = M.select(IMAP_FOLDER, readonly=True)
        if typ != "OK":
            raise RuntimeError(f"SELECT {IMAP_FOLDER} failed: {typ}")
        typ, status_data = M.status(IMAP_FOLDER, "(UIDVALIDITY UIDNEXT)")
        if typ != "OK" or not status_data or status_data[0] is None:
            raise RuntimeError(f"STATUS {IMAP_FOLDER} failed: {typ}")
        raw_status = status_data[0].decode("utf-8", "replace")
        uv_m = re.search(r"UIDVALIDITY (\d+)", raw_status)
        un_m = re.search(r"UIDNEXT (\d+)", raw_status)
        if not uv_m or not un_m:
            raise RuntimeError(f"could not parse STATUS response: {raw_status!r}")
        uidvalidity = int(uv_m.group(1))
        uidnext_at_start = int(un_m.group(1))
    except Exception as exc:
        summary.append(f"FATAL: IMAP connect/login/select failed: {type(exc).__name__}: {exc}")
        _write_summary(summary, run_ts, args.dry_run)
        print("FATAL: IMAP connection failed (see summary; password never printed)")
        try:
            if M is not None:
                M.logout()
        except Exception:
            pass
        return 1

    try:
        # ── Watermark ──
        state = _load_state()
        prior_uidvalidity = state.get("uidvalidity")
        last_uid = state.get("last_uid")
        first_run = last_uid is None
        uidvalidity_reset = (prior_uidvalidity is not None and prior_uidvalidity != uidvalidity)
        if uidvalidity_reset:
            summary.append(
                f"WARNING: UIDVALIDITY changed ({prior_uidvalidity} -> {uidvalidity}) — "
                "stored UIDs are no longer comparable. Resetting to first-run behavior "
                "(bounded SINCE-today search) rather than replaying full history."
            )
            first_run = True

        if first_run:
            search_criteria = f'(SINCE "{_imap_date_today()}")'
            summary.append(
                f"Mode: FIRST RUN — watermark not yet established. Searching {IMAP_FOLDER} "
                f"{search_criteria} (today only) rather than full history — the one-off "
                f"2026-07-19 sweep already covered March-July history. Watermark will be set "
                f"to UIDNEXT-1={uidnext_at_start - 1} at the end of this run."
            )
        else:
            search_criteria = f"UID {last_uid + 1}:*"
            summary.append(f"Mode: incremental — watermark last_uid={last_uid}, search: {search_criteria}")

        typ, search_data = M.uid("search", None, search_criteria)
        candidate_uids: list[int] = []
        if typ == "OK" and search_data and search_data[0]:
            for tok in search_data[0].split():
                try:
                    u = int(tok)
                except ValueError:
                    continue
                if not first_run and u <= last_uid:
                    continue  # defensive: some IMAP servers can be sloppy with "N:*" ranges
                candidate_uids.append(u)
        candidate_uids.sort()
        summary.append(f"Candidate mail count in window: {len(candidate_uids)}")
        summary.append("")

        existing_urls = _load_existing_urls()
        new_rows: list[dict] = []
        detail_lines: list[str] = []
        counts_by_domain: dict[str, int] = {}
        matched_count = 0
        unresolved_count = 0
        fetch_budget_start = time.monotonic()
        budget_exhausted_logged = False

        for uid in candidate_uids:
            try:
                typ, hdata = M.uid(
                    "fetch", str(uid), "(BODY.PEEK[HEADER.FIELDS (FROM DATE SUBJECT)])"
                )
                if typ != "OK" or not hdata or hdata[0] is None:
                    detail_lines.append(f"- UID {uid}: header fetch failed ({typ})")
                    continue
                hmsg = email.message_from_bytes(hdata[0][1])
                from_raw = hmsg.get("From", "")
                sender = _self_sender_email(from_raw)
                if sender is None:
                    continue  # not a self-forward; skip but watermark still advances

                matched_count += 1
                date_raw = hmsg.get("Date", "")
                subject = _decode_header_value(hmsg.get("Subject", ""))
                try:
                    parsed_dt = email.utils.parsedate_to_datetime(date_raw)
                    date_str = parsed_dt.date().isoformat() if parsed_dt else ""
                except Exception:
                    date_str = ""

                typ2, bdata = M.uid("fetch", str(uid), "(BODY.PEEK[])")
                if typ2 != "OK" or not bdata or bdata[0] is None:
                    detail_lines.append(f"- UID {uid} ({sender}, {subject!r}): body fetch failed ({typ2})")
                    continue
                full_msg = email.message_from_bytes(bdata[0][1])
                body_text = _extract_body_text(full_msg)
                urls = _extract_urls(body_text)
                if not urls:
                    detail_lines.append(f"- UID {uid} ({sender}, {subject!r}): no URLs found")
                    continue

                detail_lines.append(f"- UID {uid} ({sender}, {date_str}, {subject!r}): {len(urls)} URL(s)")
                for u in urls:
                    if u in existing_urls:
                        detail_lines.append(f"    - SKIP (dup): {u}")
                        continue
                    dclass = _classify_domain(u)
                    counts_by_domain[dclass] = counts_by_domain.get(dclass, 0) + 1
                    resolved_title = ""
                    note = ""
                    if dclass == "reddit":
                        note = "queued: reddit URL miner (not fetched — Reddit blocks scraping)"
                    elif dclass == "youtube":
                        note = "queued: transcript-proxy miner (not fetched here)"
                    elif dclass in ("github", "other"):
                        elapsed = time.monotonic() - fetch_budget_start
                        if elapsed > TOTAL_FETCH_BUDGET_SEC:
                            note = "UNRESOLVED: time budget exceeded, not attempted"
                            unresolved_count += 1
                            if not budget_exhausted_logged:
                                detail_lines.append(
                                    f"    - fetch time budget ({TOTAL_FETCH_BUDGET_SEC:.0f}s) exhausted; "
                                    "remaining URLs recorded unresolved"
                                )
                                budget_exhausted_logged = True
                        else:
                            if dclass == "github":
                                title, desc, err = _fetch_github_meta(u)
                            else:
                                title, desc, err = _fetch_generic_title(u)
                            if err:
                                note = f"UNRESOLVED: {err}"
                                unresolved_count += 1
                            else:
                                resolved_title = title
                                note = f"desc: {desc}" if desc else "(no meta description)"
                    detail_lines.append(f"    - [{dclass}] {u}")
                    detail_lines.append(f"        title: {resolved_title or '(none)'}  |  {note}")
                    existing_urls.add(u)
                    new_rows.append({
                        "date": date_str,
                        "source_mail_uid": uid,
                        "url": u,
                        "domain_class": dclass,
                        "resolved_title": resolved_title,
                        "status": "NEW",
                    })
            except Exception as exc:  # noqa: BLE001 — one bad mail must never abort the run
                detail_lines.append(f"- UID {uid}: unexpected error {type(exc).__name__}: {exc}")
                continue

        # Advance watermark to what existed in the mailbox at run start, regardless of
        # how much of the window we actually got through (forward progress guarantee).
        new_last_uid = max(uidnext_at_start - 1, candidate_uids[-1] if candidate_uids else 0,
                            last_uid or 0)
        new_state = {
            "folder": IMAP_FOLDER,
            "uidvalidity": uidvalidity,
            "last_uid": new_last_uid,
            "last_run_utc": run_start_utc,
            "runs": int(state.get("runs", 0)) + (0 if args.dry_run else 1),
        }
        _save_state(new_state, args.dry_run)
        _append_leads(new_rows, args.dry_run)

        runtime_sec = time.monotonic() - run_start
        summary.append(f"Self-sent mails matched: {matched_count}")
        summary.append(f"New leads appended: {len(new_rows)}")
        summary.append(f"By domain: {json.dumps(counts_by_domain, sort_keys=True)}")
        summary.append(f"Unresolved fetches: {unresolved_count}")
        summary.append(f"Watermark: last_uid {last_uid} -> {new_last_uid} (uidvalidity={uidvalidity})")
        summary.append(f"Runtime: {runtime_sec:.1f}s")
        summary.append("")
        summary.append("## Per-mail detail")
        summary.extend(detail_lines if detail_lines else ["(no self-sent mail with URLs in window)"])

        summary_path = _write_summary(summary, run_ts, args.dry_run)
        _append_run_log({
            "run_utc": run_start_utc,
            "dry_run": args.dry_run,
            "matched_mails": matched_count,
            "new_leads": len(new_rows),
            "by_domain": counts_by_domain,
            "unresolved": unresolved_count,
            "last_uid_before": last_uid,
            "last_uid_after": new_last_uid,
            "runtime_sec": round(runtime_sec, 1),
        }, args.dry_run)

        print(f"Sourcing intake sweep done. matched={matched_count} new_leads={len(new_rows)} "
              f"by_domain={counts_by_domain} unresolved={unresolved_count} "
              f"runtime={runtime_sec:.1f}s watermark={last_uid}->{new_last_uid}")
        print(f"Summary: {summary_path}")
        if not args.dry_run:
            print(f"Leads CSV: {LEADS_CSV}")
            print(f"State: {STATE_FILE}")
        return 0
    finally:
        try:
            M.logout()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
