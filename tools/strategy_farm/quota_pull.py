"""Headless quota/limit pull for Codex + Claude — no browser, survives reboot.

Replaces the Tampermonkey DOM-scraper path (userscripts/*.user.js +
quota_receiver.py), which depended on Chrome tabs staying open and broke on every
reboot. Instead we hit the same authenticated usage JSON endpoints the vendor
pages call, using the OAuth tokens the CLIs already store on disk:

  Codex : GET https://chatgpt.com/backend-api/codex/usage
          Authorization: Bearer <C:/Users/Administrator/.codex/auth.json tokens.access_token>
          chatgpt-account-id: <tokens.account_id>
          -> rate_limit.primary_window.used_percent (5h), secondary_window (weekly)

  Claude: GET https://api.anthropic.com/api/oauth/usage
          Authorization: Bearer <~/.claude/.credentials.json claudeAiOauth.accessToken>
          anthropic-beta: oauth-2025-04-20
          -> five_hour.utilization (5h), seven_day.utilization (weekly)

Writes the SAME file the receiver did so render_cockpit.py / health.py read it
unchanged: D:/QM/strategy_farm/state/quota_snapshot.json. Each source gets a
`data.structured` block (hour_pct/week_pct/resets, USED %) which the cockpit now
prefers over DOM text-parse. `received_at` is bumped only on a SUCCESSFUL pull,
so health's quota_snapshot_fresh correctly goes stale if pulls keep failing.

Tokens are refreshed in-place by the constantly-running factory CLIs, so we just
re-read the files each run. On 401/403 (expired token mid-refresh, or a transient
Cloudflare bot-block on chatgpt.com) we keep the last-good source entry untouched.

Run:
  python tools/strategy_farm/quota_pull.py            # one pull, print summary
  python tools/strategy_farm/quota_pull.py --loop 300 # poll every 300s
  (installed as scheduled task QM_StrategyFarm_QuotaPull, AT STARTUP + 5-min repeat)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STATE = Path(r"D:/QM/strategy_farm/state/quota_snapshot.json")
CODEX_AUTH = Path(r"C:/Users/Administrator/.codex/auth.json")
CLAUDE_CREDS = Path(r"C:/Users/Administrator/.claude/.credentials.json")

CODEX_USAGE_URL = "https://chatgpt.com/backend-api/codex/usage"
CLAUDE_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"

UA = "qm-quota-pull/1.0"


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _http_json(url: str, headers: dict, retries: int = 3) -> dict:
    """GET url -> parsed JSON. Retries transient 403/429/5xx with backoff.

    Raises the last error on permanent failure so the caller can keep last-good.
    """
    last: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers, method="GET")
            with urllib.request.urlopen(req, timeout=25) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as exc:
            last = exc
            # 401 = token expired (don't retry, caller keeps last-good);
            # 403/429/5xx = transient (Cloudflare / rate) -> backoff + retry
            if exc.code in (401,) or attempt == retries - 1:
                raise
            time.sleep(2 * (attempt + 1))
        except Exception as exc:  # noqa: BLE001 - network/json, retry
            last = exc
            if attempt == retries - 1:
                raise
            time.sleep(2 * (attempt + 1))
    raise last if last else RuntimeError("unreachable")


def _fmt_reset_epoch(epoch: float | int | None) -> str | None:
    if not epoch:
        return None
    t = dt.datetime.fromtimestamp(int(epoch), dt.timezone.utc)
    return t.strftime("%d.%m. %H:%M UTC")


def _fmt_reset_iso(iso: str | None) -> str | None:
    if not iso:
        return None
    try:
        t = dt.datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return t.astimezone(dt.timezone.utc).strftime("%d.%m. %H:%M UTC")
    except Exception:
        return iso


def pull_codex() -> dict:
    auth = json.loads(CODEX_AUTH.read_text(encoding="utf-8"))["tokens"]
    headers = {
        "Authorization": "Bearer " + auth["access_token"],
        "chatgpt-account-id": auth.get("account_id", ""),
        "Accept": "application/json",
        "User-Agent": UA,
        "originator": "codex_cli_rs",
    }
    raw = _http_json(CODEX_USAGE_URL, headers)
    rl = raw.get("rate_limit") or {}
    prim = rl.get("primary_window") or {}
    sec = rl.get("secondary_window") or {}
    structured = {
        "hour_pct": prim.get("used_percent"),
        "week_pct": sec.get("used_percent"),
        "hour_reset": _fmt_reset_epoch(prim.get("reset_at")),
        "week_reset": _fmt_reset_epoch(sec.get("reset_at")),
        "plan": raw.get("plan_type"),
        "limit_reached": rl.get("limit_reached"),
    }
    return {"structured": structured, "raw": raw}


def pull_claude() -> dict:
    creds = json.loads(CLAUDE_CREDS.read_text(encoding="utf-8"))["claudeAiOauth"]
    headers = {
        "Authorization": "Bearer " + creds["accessToken"],
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "oauth-2025-04-20",
        "Accept": "application/json",
        "User-Agent": UA,
    }
    raw = _http_json(CLAUDE_USAGE_URL, headers)
    five = raw.get("five_hour") or {}
    week = raw.get("seven_day") or {}
    sonnet = raw.get("seven_day_sonnet") or {}
    structured = {
        "hour_pct": five.get("utilization"),
        "week_pct": week.get("utilization"),
        "sonnet_pct": sonnet.get("utilization"),
        "hour_reset": _fmt_reset_iso(five.get("resets_at")),
        "week_reset": _fmt_reset_iso(week.get("resets_at")),
        "plan": creds.get("subscriptionType"),
        "tier": creds.get("rateLimitTier"),
    }
    return {"structured": structured, "raw": raw}


def load_snapshot() -> dict:
    if not STATE.exists():
        return {}
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_snapshot(d: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(d, indent=2, sort_keys=True), encoding="utf-8")


def pull_once() -> dict:
    snap = load_snapshot()
    results = {}
    for src, fn in (("codex", pull_codex), ("claude", pull_claude)):
        now = _now_iso()
        try:
            payload = fn()
            data = payload["structured"] | {
                "raw": payload["raw"],
                "source_method": "api_pull",
                "matches": {
                    "hour_pct": payload["structured"].get("hour_pct"),
                    "week_pct": payload["structured"].get("week_pct"),
                    "plan_label": payload["structured"].get("plan"),
                },
                "structured": payload["structured"],
            }
            snap[src] = {
                "data": data,
                "scraped_at": now,
                "received_at": now,
                "user_agent": UA,
            }
            results[src] = {"ok": True, **payload["structured"]}
        except Exception as exc:  # noqa: BLE001 - keep last-good on any failure
            # Do NOT bump received_at -> health correctly goes stale if persistent
            prev = snap.get(src) or {}
            prev_data = prev.get("data") or {}
            prev_data["last_pull_error"] = f"{type(exc).__name__}: {exc}"
            prev_data["last_pull_error_at"] = now
            if prev:
                prev["data"] = prev_data
                snap[src] = prev
            results[src] = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
    save_snapshot(snap)
    return results


def _summarize(results: dict) -> str:
    parts = []
    for src in ("codex", "claude"):
        r = results.get(src) or {}
        if r.get("ok"):
            parts.append(
                f"{src}: 5h={r.get('hour_pct')}% week={r.get('week_pct')}% "
                f"(reset {r.get('hour_reset')})"
            )
        else:
            parts.append(f"{src}: FAIL {r.get('error')}")
    return " | ".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description="Headless Codex+Claude quota pull")
    ap.add_argument("--loop", type=int, default=0,
                    help="poll every N seconds (0 = one pull and exit)")
    args = ap.parse_args()
    if args.loop > 0:
        print(f"quota_pull looping every {args.loop}s -> {STATE}", flush=True)
        while True:
            res = pull_once()
            print(f"[{_now_iso()}] {_summarize(res)}", flush=True)
            time.sleep(args.loop)
    res = pull_once()
    print(_summarize(res))
    # exit non-zero only if BOTH sources failed (task-monitoring signal)
    return 0 if any(v.get("ok") for v in res.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
