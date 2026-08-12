"""Weekly OWNER mail for sources that automation could not open.

The report has two canonical inputs:

* unchecked links inside the marked "Priorität A" block in the OWNER's
  ``Strategie Links.md`` Vault note; and
* access-related ``DEFERRED:*`` rows in the mailbox source-intake CSV.

Discovery-only and already EA-mapped fidelity links are intentionally excluded:
they are not proven access failures.  The scheduled task runs every Friday
morning.  A durable ISO-week state prevents scheduler retries from sending the
same weekly report twice; an atomic pre-SMTP week claim also closes the
send-success/state-write-failure window.  Even an empty backlog produces one
short weekly confirmation mail.

No network fetch is performed here.  SMTP is delegated to the existing
``gmail_alarm._send_mail`` helper so credentials and recipient handling stay
centralized.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable
from urllib.parse import SplitResult, urlsplit, urlunsplit


sys.path.insert(0, str(Path(__file__).resolve().parent))
import gmail_alarm as ga  # noqa: E402


EXPECTED_RECIPIENT = "fabian.grabner@gmail.com"
VAULT_NOTE = Path(
    r"G:\My Drive\QuantMechanica - Company Reference\Strategie Links.md"
)
LEADS_CSV = Path(r"D:\QM\reports\sourcing_intake\leads.csv")
STATE_FILE = Path(
    r"D:\QM\strategy_farm\state\weekly_unreadable_links_mail_state.json"
)
CLAIMS_DIR = (
    STATE_FILE.parent / "weekly_unreadable_links_mail_claims"
)
REPORTS_STATE = Path(r"D:\QM\reports\state")
RUN_LOG = REPORTS_STATE / "weekly_unreadable_links_mail.jsonl"
DASHBOARDS_DIR = Path(r"D:\QM\strategy_farm\dashboards")
LATEST_TEXT = DASHBOARDS_DIR / "weekly_unreadable_links_mail.txt"
LATEST_HTML = DASHBOARDS_DIR / "weekly_unreadable_links_mail.html"
LATEST_JSON = REPORTS_STATE / "weekly_unreadable_links_mail_latest.json"

MARKER_START = "<!-- qm-weekly-unreadable-links:start -->"
MARKER_END = "<!-- qm-weekly-unreadable-links:end -->"
UNCHECKED_LINK_RE = re.compile(
    r"^\s*-\s*\[\s\]\s+"
    r"\[(?P<title>[^\]]+)\]"
    r"\((?P<url>https?://[^\s)]+)\)"
    r"(?:\s+[—-]\s*(?P<detail>.*))?\s*$",
    re.IGNORECASE,
)
UNCHECKED_TASK_RE = re.compile(r"^\s*-\s*\[\s\]\s+")

# The intake contract uses DEFERRED for unreadable/policy-blocked/dead sources.
# HANDOFF_FAILED is the one known downstream-only status: the page may already
# have been read, while add-source/card handoff failed.
NON_ACCESS_DEFERRED_PREFIXES = (
    "DEFERRED:HANDOFF_FAILED",
)

Sender = Callable[[str, str, str, str], dict]


class SourceDataError(RuntimeError):
    """A canonical report input is missing, corrupt, or structurally unsafe."""


@dataclass(frozen=True)
class LinkItem:
    title: str
    url: str
    detail: str
    source: str
    status: str


def _now_local() -> dt.datetime:
    return dt.datetime.now().astimezone()


def _now_utc_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _validate_and_normalize_url(raw: str) -> str:
    raw = (raw or "").strip()
    parsed = urlsplit(raw)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.hostname:
        raise SourceDataError(f"unsafe or invalid source URL: {raw!r}")
    if parsed.username or parsed.password:
        raise SourceDataError(f"credentials are forbidden in source URL: {raw!r}")
    normalized = SplitResult(
        scheme=parsed.scheme.lower(),
        netloc=parsed.netloc.lower(),
        path=parsed.path or "/",
        query=parsed.query,
        fragment="",
    )
    return urlunsplit(normalized)


def _canonical_url(raw: str) -> str:
    normalized = _validate_and_normalize_url(raw)
    parsed = urlsplit(normalized)
    path = parsed.path.rstrip("/") or "/"
    return urlunsplit(
        # HTTP/HTTPS variants are one manual-review target.  Preserve the
        # original scheme in LinkItem.url, but make the dedupe key scheme-free.
        SplitResult("https", parsed.netloc, path, parsed.query, "")
    )


def load_vault_links(path: Path = VAULT_NOTE) -> list[LinkItem]:
    """Load unchecked links from the explicitly marked weekly-mail block."""
    if not path.exists():
        raise SourceDataError(f"Vault source note missing: {path}")
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise SourceDataError(f"Vault source note unreadable: {exc}") from exc

    if text.count(MARKER_START) != 1 or text.count(MARKER_END) != 1:
        raise SourceDataError(
            "Vault weekly-mail markers must each occur exactly once"
        )
    before, remainder = text.split(MARKER_START, 1)
    block, _after = remainder.split(MARKER_END, 1)
    if before.endswith(MARKER_END):
        raise SourceDataError("Vault weekly-mail markers are reversed")

    items: list[LinkItem] = []
    seen: set[str] = set()
    for line_number, line in enumerate(block.splitlines(), 1):
        match = UNCHECKED_LINK_RE.match(line)
        if match:
            url = _validate_and_normalize_url(match.group("url"))
            key = _canonical_url(url)
            if key in seen:
                continue
            seen.add(key)
            items.append(
                LinkItem(
                    title=match.group("title").strip(),
                    url=url,
                    detail=(match.group("detail") or "").strip(),
                    source="Vault · Strategie Links",
                    status="MANUAL_REVIEW",
                )
            )
            continue
        if UNCHECKED_TASK_RE.match(line):
            raise SourceDataError(
                "Malformed unchecked task in Vault weekly-mail block "
                f"(block line {line_number}): {line.strip()!r}"
            )
    return items


def _is_access_deferred(status: str) -> bool:
    normalized = (status or "").strip().upper()
    return (
        normalized.startswith("DEFERRED:")
        and not any(
            normalized.startswith(prefix)
            for prefix in NON_ACCESS_DEFERRED_PREFIXES
        )
    )


def load_mailbox_deferred(path: Path = LEADS_CSV) -> list[LinkItem]:
    """Load only source-access failures from the canonical intake CSV."""
    if not path.exists():
        raise SourceDataError(f"Mailbox intake source missing: {path}")
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            required = {"url", "status"}
            if not reader.fieldnames or not required.issubset(reader.fieldnames):
                raise SourceDataError(
                    "Mailbox intake CSV is missing required columns: url, status"
                )
            items: list[LinkItem] = []
            seen: set[str] = set()
            for row_number, row in enumerate(reader, 2):
                status = (row.get("status") or "").strip()
                if not _is_access_deferred(status):
                    continue
                try:
                    url = _validate_and_normalize_url(row.get("url") or "")
                except SourceDataError as exc:
                    raise SourceDataError(
                        f"Mailbox intake CSV row {row_number}: {exc}"
                    ) from exc
                key = _canonical_url(url)
                if key in seen:
                    continue
                seen.add(key)
                title = (row.get("resolved_title") or "").strip()
                items.append(
                    LinkItem(
                        title=title or url,
                        url=url,
                        detail=status,
                        source="Mailbox Source Intake",
                        status=status,
                    )
                )
    except SourceDataError:
        raise
    except (OSError, csv.Error) as exc:
        raise SourceDataError(f"Mailbox intake CSV unreadable: {exc}") from exc
    return items


def collect_links(
    vault_note: Path = VAULT_NOTE,
    leads_csv: Path = LEADS_CSV,
) -> list[LinkItem]:
    """Merge sources by canonical URL; an access status overrides manual detail."""
    merged: dict[str, LinkItem] = {}
    for item in load_vault_links(vault_note):
        merged[_canonical_url(item.url)] = item
    for item in load_mailbox_deferred(leads_csv):
        key = _canonical_url(item.url)
        previous = merged.get(key)
        if previous:
            merged[key] = LinkItem(
                title=(
                    item.title
                    if item.title != item.url
                    else previous.title
                ),
                url=item.url,
                detail=item.detail,
                source="Vault + Mailbox Source Intake",
                status=item.status,
            )
        else:
            merged[key] = item
    return list(merged.values())


def _report_date_label(when: dt.datetime) -> str:
    return when.strftime("%d.%m.%Y")


def build_mail(
    items: list[LinkItem],
    when: dt.datetime | None = None,
) -> tuple[str, str, str]:
    """Build subject, plain-text fallback, and branded HTML."""
    when = when or _now_local()
    date_label = _report_date_label(when)
    count = len(items)
    subject = (
        f"[QuantMechanica] Offene Quellenlinks · {count} · {date_label}"
    )

    text_lines = [
        "QuantMechanica · Manuelle Quellenprüfung",
        f"Freitagsbericht vom {date_label}",
        "",
    ]
    if items:
        text_lines.append(
            f"{count} Link{'s' if count != 1 else ''} konnte die Automation "
            "nicht verlässlich öffnen oder auswerten:"
        )
        text_lines.append("")
        for index, item in enumerate(items, 1):
            text_lines.extend(
                [
                    f"{index}. {item.title}",
                    f"   {item.url}",
                    f"   Quelle: {item.source}",
                    f"   Status: {item.detail or item.status}",
                    "",
                ]
            )
        text_lines.extend(
            [
                "Nach manueller Bearbeitung bitte die zugehörige Checkbox in "
                "„Strategie Links“ abhaken beziehungsweise den Intake-Status "
                "aktualisieren.",
                "",
            ]
        )
    else:
        text_lines.extend(
            [
                "Keine offenen, technisch oder durch Source-Policy "
                "unzugänglichen Quellenlinks.",
                "",
            ]
        )
    text_lines.append(
        "Automatischer Wochenbericht · Freitag 06:30 · "
        "QM_StrategyFarm_UnreadableLinks_Friday"
    )
    text_body = "\n".join(text_lines)

    p = ga.PALETTE
    cards = ""
    for index, item in enumerate(items, 1):
        title = html.escape(item.title)
        url = html.escape(item.url, quote=True)
        visible_url = html.escape(item.url)
        detail = html.escape(item.detail or item.status)
        source = html.escape(item.source)
        cards += f"""
        <tr><td style="padding:0 26px 12px;">
          <table cellpadding="0" cellspacing="0" border="0" width="100%"
                 style="border:1px solid {p['border']};background:{p['surface_1']};">
            <tr>
              <td valign="top" width="36" style="padding:15px 0 15px 15px;
                  color:{p['text_subtle']};font-family:{ga.MONO_STACK};
                  font-size:12px;">{index:02d}</td>
              <td style="padding:14px 16px;">
                <a href="{url}" style="font-size:14px;font-weight:650;
                   color:{p['accent']};text-decoration:none;">{title}</a>
                <div style="margin-top:6px;font-family:{ga.MONO_STACK};
                     font-size:11px;line-height:1.45;color:{p['text_muted']};
                     word-break:break-all;">{visible_url}</div>
                <div style="margin-top:8px;font-size:12px;line-height:1.45;
                     color:{p['text_dim']};">{detail}</div>
                <div style="margin-top:6px;font-size:10px;letter-spacing:.7px;
                     text-transform:uppercase;color:{p['text_subtle']};">{source}</div>
              </td>
            </tr>
          </table>
        </td></tr>"""

    if not items:
        cards = f"""
        <tr><td style="padding:0 26px 24px;">
          <div style="padding:24px;border:1px solid {p['border']};
               background:{p['surface_2']};text-align:center;
               color:{p['emerald']};font-size:15px;font-weight:650;">
            Keine offenen unzugänglichen Quellenlinks
          </div>
        </td></tr>"""

    html_body = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:{p['bg']};
             font-family:{ga.FONT_STACK};color:{p['text']};">
<table cellpadding="0" cellspacing="0" border="0" width="100%"
       style="background:{p['bg']};">
  <tr><td align="center" style="padding:24px 12px;">
    <table cellpadding="0" cellspacing="0" border="0" width="640"
           style="max-width:640px;background:{p['surface_1']};
                  border:1px solid {p['border']};">
      <tr><td style="padding:24px 26px 18px;border-bottom:1px solid {p['border']};">
        <div style="font-size:10px;letter-spacing:2px;color:{p['accent']};
             text-transform:uppercase;font-weight:700;">
          QuantMechanica · Research Intake
        </div>
        <div style="font-size:24px;font-weight:650;margin-top:5px;">
          Manuelle Quellenprüfung
        </div>
        <div style="font-size:12px;color:{p['text_muted']};margin-top:8px;">
          Freitag, {html.escape(date_label)} · {count} offen
        </div>
      </td></tr>
      <tr><td style="padding:18px 26px 14px;font-size:13px;line-height:1.55;
                     color:{p['text_dim']};">
        Diese Links konnte die Automation nicht verlässlich öffnen oder
        auswerten. Discovery-only- und bereits EA-zugeordnete Fidelity-Links
        sind bewusst nicht enthalten.
      </td></tr>
      {cards}
      <tr><td style="padding:16px 26px;border-top:1px solid {p['border']};
                     background:{p['surface_0']};font-size:11px;
                     line-height:1.55;color:{p['text_muted']};">
        Nach manueller Bearbeitung die Checkbox in <b>Strategie Links</b>
        abhaken bzw. den Intake-Status aktualisieren.<br>
        Automatischer Wochenbericht · Freitag 06:30
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>"""
    return subject, text_body, html_body


def _iso_week_key(when: dt.datetime) -> str:
    iso = when.isocalendar()
    return f"{iso.year}-W{iso.week:02d}"


def _content_fingerprint(items: list[LinkItem]) -> str:
    payload = [
        {
            "url": _canonical_url(item.url),
            "status": item.status,
            "detail": item.detail,
        }
        for item in items
    ]
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _atomic_write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def _atomic_write_json(path: Path, payload: dict, *, keep_backup: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if keep_backup and path.exists():
        backup = path.with_name(f"{path.name}.bak")
        try:
            backup.write_bytes(path.read_bytes())
        except OSError:
            pass
    _atomic_write_text(
        path,
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    )


def _load_state(path: Path) -> dict:
    backup = path.with_name(f"{path.name}.bak")
    # A present-but-corrupt primary is ambiguous: it might have contained this
    # week's successful send.  Never fall back to an older backup and risk a
    # duplicate.  The backup is used only when the primary is wholly absent.
    candidate = path if path.exists() else backup
    if not candidate.exists():
        return {}
    try:
        value = json.loads(candidate.read_text(encoding="utf-8"))
        if isinstance(value, dict):
            return value
        error = "root is not an object"
    except (OSError, json.JSONDecodeError) as exc:
        error = str(exc)
    raise SourceDataError(
        "weekly mail state is corrupt; refusing a possible duplicate send: "
        f"{candidate}: {error}"
    )


def _claim_path(claims_dir: Path, week_key: str) -> Path:
    if not re.fullmatch(r"\d{4}-W\d{2}", week_key):
        raise SourceDataError(f"invalid ISO-week claim key: {week_key!r}")
    return claims_dir / f"{week_key}.json"


def _read_claim(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SourceDataError(
            f"weekly mail claim is unreadable; refusing duplicate send: {path}: {exc}"
        ) from exc
    if not isinstance(value, dict):
        raise SourceDataError(
            f"weekly mail claim root is not an object: {path}"
        )
    return value


def _create_week_claim(
    claims_dir: Path,
    week_key: str,
    *,
    fingerprint: str,
    message_id: str,
) -> tuple[bool, Path, dict]:
    """Atomically claim an ISO week before SMTP.

    The claim is the at-most-once fence.  It remains after accepted or
    ambiguous SMTP delivery, including if the later state write fails.
    """
    path = _claim_path(claims_dir, week_key)
    path.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "schema": 1,
        "week": week_key,
        "stage": "in_progress",
        "claimed_at_utc": _now_utc_iso(),
        "fingerprint": fingerprint,
        "message_id": message_id,
    }
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(
                json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True)
                + "\n"
            )
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError:
        return False, path, _read_claim(path)
    except OSError as exc:
        raise SourceDataError(f"could not create weekly mail claim: {exc}") from exc
    return True, path, record


def _update_claim(path: Path, record: dict, stage: str, **fields: object) -> dict:
    updated = {
        **record,
        **fields,
        "stage": stage,
        "updated_at_utc": _now_utc_iso(),
    }
    _atomic_write_json(path, updated)
    return updated


def _release_retryable_claim(path: Path) -> None:
    """Release only the exact current-week claim after a definite pre-send failure."""
    try:
        path.unlink()
    except FileNotFoundError:
        return
    except OSError as exc:
        raise SourceDataError(
            f"could not release retryable weekly mail claim: {exc}"
        ) from exc


def _append_log(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")


def _default_sender(
    subject: str,
    text_body: str,
    html_body: str,
    message_id: str,
) -> dict:
    return ga._send_mail(
        subject,
        text_body,
        html_body,
        message_id=message_id,
    )


def _send_with_retries(
    sender: Sender,
    subject: str,
    text_body: str,
    html_body: str,
    message_id: str,
    *,
    attempts: int = 3,
    sleep: Callable[[float], None] = time.sleep,
) -> dict:
    last: dict = {"sent": False, "reason": "not attempted"}
    for attempt in range(1, attempts + 1):
        last = sender(subject, text_body, html_body, message_id)
        last = dict(last or {})
        last["attempt"] = attempt
        if last.get("sent"):
            return last
        if last.get("failure_stage") != "pre_send":
            break
        if attempt < attempts:
            sleep(float(2 ** (attempt - 1)))
    return last


def run_report(
    *,
    vault_note: Path = VAULT_NOTE,
    leads_csv: Path = LEADS_CSV,
    state_file: Path = STATE_FILE,
    run_log: Path = RUN_LOG,
    latest_text: Path = LATEST_TEXT,
    latest_html: Path = LATEST_HTML,
    latest_json: Path = LATEST_JSON,
    failure_dir: Path = DASHBOARDS_DIR,
    claims_dir: Path = CLAIMS_DIR,
    when: dt.datetime | None = None,
    dry_run: bool = False,
    sender: Sender = _default_sender,
    sleep: Callable[[float], None] = time.sleep,
) -> dict:
    """Render and optionally send one ISO-week report."""
    when = when or _now_local()
    if ga.RECIPIENT.lower() != EXPECTED_RECIPIENT.lower():
        raise SourceDataError(
            f"SMTP helper recipient drifted: {ga.RECIPIENT!r}"
        )

    items = collect_links(vault_note, leads_csv)
    subject, text_body, html_body = build_mail(items, when)
    week_key = _iso_week_key(when)
    fingerprint = _content_fingerprint(items)
    summary = {
        "schema": 1,
        "generated_at_utc": _now_utc_iso(),
        "week": week_key,
        "recipient": EXPECTED_RECIPIENT,
        "count": len(items),
        "fingerprint": fingerprint,
        "items": [asdict(item) for item in items],
    }

    _atomic_write_text(latest_text, text_body + "\n")
    _atomic_write_text(latest_html, html_body)
    _atomic_write_json(latest_json, summary)

    if dry_run:
        result = {
            "action": "dry_run",
            "sent": False,
            "week": week_key,
            "count": len(items),
            "subject": subject,
            "fingerprint": fingerprint,
        }
        return result

    message_id = f"<qm-unreadable-links-{week_key.lower()}@quantmechanica.com>"
    claim_path = _claim_path(claims_dir, week_key)
    if claim_path.exists():
        claim = _read_claim(claim_path)
        stage = str(claim.get("stage") or "unknown")
        safely_accepted = stage in {"smtp_accepted", "sent"}
        result = {
            "action": "already_sent" if safely_accepted else "already_claimed",
            "sent": False,
            "week": week_key,
            "count": len(items),
            "fingerprint": fingerprint,
            "claim_stage": stage,
            "terminal_failure": not safely_accepted,
        }
        _append_log(
            run_log,
            {**result, "recorded_at_utc": _now_utc_iso()},
        )
        return result

    state = _load_state(state_file)
    if state.get("last_sent_week") == week_key:
        result = {
            "action": "already_sent",
            "sent": False,
            "week": week_key,
            "count": len(items),
            "fingerprint": fingerprint,
            "claim_stage": "legacy_state",
            "terminal_failure": False,
        }
        _append_log(
            run_log,
            {**result, "recorded_at_utc": _now_utc_iso()},
        )
        return result

    created, claim_path, claim = _create_week_claim(
        claims_dir,
        week_key,
        fingerprint=fingerprint,
        message_id=message_id,
    )
    if not created:
        stage = str(claim.get("stage") or "unknown")
        safely_accepted = stage in {"smtp_accepted", "sent"}
        result = {
            "action": "already_sent" if safely_accepted else "already_claimed",
            "sent": False,
            "week": week_key,
            "count": len(items),
            "fingerprint": fingerprint,
            "claim_stage": stage,
            "terminal_failure": not safely_accepted,
        }
        _append_log(
            run_log,
            {**result, "recorded_at_utc": _now_utc_iso()},
        )
        return result

    # Persist the at-most-once fence before SMTP.  If this write fails, the
    # already-created claim remains and no mail is attempted.
    attempt_state = {
        **state,
        "schema": 1,
        "last_attempt_week": week_key,
        "last_attempt_at_utc": _now_utc_iso(),
        "last_attempt_stage": "in_progress",
        "last_attempt_fingerprint": fingerprint,
        "last_message_id": message_id,
        "recipient": EXPECTED_RECIPIENT,
    }
    _atomic_write_json(state_file, attempt_state, keep_backup=True)

    mail_result = _send_with_retries(
        sender,
        subject,
        text_body,
        html_body,
        message_id,
        sleep=sleep,
    )
    if mail_result.get("sent"):
        # Mark SMTP acceptance in the pre-existing claim before the secondary
        # human-readable state write.  A crash after Gmail acceptance therefore
        # cannot trigger a duplicate scheduler retry.
        claim = _update_claim(
            claim_path,
            claim,
            "smtp_accepted",
            smtp_accepted_at_utc=_now_utc_iso(),
            mail_result=mail_result,
        )
        _atomic_write_json(
            state_file,
            {
                **attempt_state,
                "schema": 1,
                "last_sent_week": week_key,
                "last_sent_at_utc": _now_utc_iso(),
                "last_count": len(items),
                "last_fingerprint": fingerprint,
                "last_subject": subject,
                "recipient": EXPECTED_RECIPIENT,
            },
            keep_backup=True,
        )
        claim = _update_claim(claim_path, claim, "sent")
        result = {
            "action": "sent",
            "sent": True,
            "week": week_key,
            "count": len(items),
            "fingerprint": fingerprint,
            "claim_stage": claim["stage"],
            "terminal_failure": False,
            "mail_result": mail_result,
        }
        _append_log(run_log, {**result, "recorded_at_utc": _now_utc_iso()})
        return result

    failure_stage = str(mail_result.get("failure_stage") or "send_ambiguous")
    retryable = failure_stage == "pre_send"
    claim_stage = "pre_send_failed" if retryable else "ambiguous"
    claim = _update_claim(
        claim_path,
        claim,
        claim_stage,
        mail_result=mail_result,
    )
    _atomic_write_json(
        state_file,
        {
            **attempt_state,
            "last_attempt_stage": claim_stage,
            "last_attempt_result": mail_result,
        },
        keep_backup=True,
    )
    if retryable:
        # The helper explicitly proved Gmail delivery was never attempted.
        # Releasing only this exact claim lets Scheduler retry safely.
        _release_retryable_claim(claim_path)

    result = {
        "action": "send_failed_retryable" if retryable else "send_ambiguous",
        "sent": False,
        "week": week_key,
        "count": len(items),
        "fingerprint": fingerprint,
        "claim_stage": claim_stage,
        "terminal_failure": True,
        "mail_result": mail_result,
    }
    failure = failure_dir / (
        "WEEKLY_UNREADABLE_LINKS_MAIL_FAILED_"
        + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        + ".md"
    )
    _atomic_write_text(
        failure,
        "# Weekly Unreadable Links Mail Failed\n\n"
        f"Week: `{week_key}`\n\n"
        f"Count: `{len(items)}`\n\n"
        f"Claim stage: `{claim_stage}`\n\n"
        f"Result: `{json.dumps(mail_result, sort_keys=True)}`\n",
    )
    result["failure_flag"] = str(failure)
    _append_log(run_log, {**result, "recorded_at_utc": _now_utc_iso()})
    return result


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="render artifacts but never send mail or update weekly send state",
    )
    parser.add_argument("--vault-note", type=Path, default=VAULT_NOTE)
    parser.add_argument("--leads-csv", type=Path, default=LEADS_CSV)
    parser.add_argument("--state-file", type=Path, default=STATE_FILE)
    parser.add_argument("--claims-dir", type=Path, default=CLAIMS_DIR)
    parser.add_argument("--run-log", type=Path, default=RUN_LOG)
    parser.add_argument("--text-out", type=Path, default=LATEST_TEXT)
    parser.add_argument("--html-out", type=Path, default=LATEST_HTML)
    parser.add_argument("--json-out", type=Path, default=LATEST_JSON)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        result = run_report(
            vault_note=args.vault_note,
            leads_csv=args.leads_csv,
            state_file=args.state_file,
            run_log=args.run_log,
            latest_text=args.text_out,
            latest_html=args.html_out,
            latest_json=args.json_out,
            claims_dir=args.claims_dir,
            dry_run=args.dry_run,
        )
    except Exception as exc:
        error = {
            "action": "failed",
            "sent": False,
            "recorded_at_utc": _now_utc_iso(),
            "error": repr(exc),
        }
        try:
            _append_log(args.run_log, error)
        except Exception:
            pass
        print(json.dumps(error, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result.get("terminal_failure") else 0


if __name__ == "__main__":
    raise SystemExit(main())
