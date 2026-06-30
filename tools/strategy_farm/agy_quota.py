"""Headless Antigravity (agy / Gemini) quota puller.

QuantMechanica blind spot: agy's quota is NOT in quota_pull.py (that covers only
Codex + Claude). We had been GUESSING agy's 5h window. This replicates the
mechanism of the `vscode-antigravity-cockpit` extension's "Authorization
Monitoring" mode (OWNER 2026-06-30), adapted for THIS headless VPS:

  * The extension reads the OAuth token from Antigravity's IDE state.vscdb — but
    the IDE was never installed here (only the agy CLI), so state.vscdb is absent.
  * On this box the token lives in the Windows Credential Manager target
    `gemini:antigravity` as JSON: {"token":{"access_token","token_type",
    "refresh_token","expiry"},"auth_method":"consumer"}.
  * Quota = Google Gemini Code Assist internal API:
      POST <base>/v1internal:loadCodeAssist      -> cloudaicompanionProject + tier
      POST <base>/v1internal:fetchAvailableModels -> models{}.quotaInfo
        .remainingFraction (0..1) + .resetTime  == the agy quota.

  python agy_quota.py            # human summary
  python agy_quota.py --json     # machine JSON (+ writes state file)

State file (for /update + governors): D:/QM/reports/state/agy_quota.json
"""
from __future__ import annotations
import argparse, ctypes, ctypes.wintypes as wt, datetime as dt, json, sys, urllib.request, urllib.error
from pathlib import Path

CRED_TARGET = "gemini:antigravity"
STATE = Path(r"D:\QM\reports\state\agy_quota.json")
# resolveCloudCodeBaseUrl: default route = DAILY; isGcpTos => PROD. Consumer auth
# (agy) -> try PROD first, then DAILY, then autopush sandbox.
BASES = (
    "https://cloudcode-pa.googleapis.com",
    "https://daily-cloudcode-pa.googleapis.com",
)
META = {
    "ideName": "antigravity",
    "ideType": "ANTIGRAVITY",
    "ideVersion": "0.1.0",
    "pluginVersion": "1.0.0",
    "platform": "WINDOWS_AMD64",
    "updateChannel": "stable",
    "pluginType": "GEMINI",
}
UA = "antigravity/0.1.0 windows/x64"


class CREDENTIAL(ctypes.Structure):
    _fields_ = [("Flags", wt.DWORD), ("Type", wt.DWORD), ("TargetName", wt.LPWSTR),
                ("Comment", wt.LPWSTR), ("LastWritten", wt.FILETIME),
                ("CredentialBlobSize", wt.DWORD), ("CredentialBlob", ctypes.POINTER(ctypes.c_byte)),
                ("Persist", wt.DWORD), ("AttributeCount", wt.DWORD), ("Attributes", ctypes.c_void_p),
                ("TargetAlias", wt.LPWSTR), ("UserName", wt.LPWSTR)]


def read_credential(target: str = CRED_TARGET) -> dict:
    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    advapi.CredReadW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ctypes.POINTER(ctypes.POINTER(CREDENTIAL))]
    advapi.CredReadW.restype = wt.BOOL
    p = ctypes.POINTER(CREDENTIAL)()
    if not advapi.CredReadW(target, 1, 0, ctypes.byref(p)):  # 1 = GENERIC
        raise RuntimeError(f"CredRead failed for {target} (err {ctypes.get_last_error()}) — has agy ever logged in?")
    try:
        blob = ctypes.string_at(p.contents.CredentialBlob, p.contents.CredentialBlobSize)
    finally:
        advapi.CredFree(p)
    return json.loads(blob.decode("utf-8"))


def _post(base: str, path: str, token: str, body: dict) -> dict:
    req = urllib.request.Request(
        base + path, data=json.dumps(body).encode("utf-8"), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json", "User-Agent": UA},
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        raw = r.read().decode("utf-8")
    return json.loads(raw) if raw else {}


def pull() -> dict:
    cred = read_credential()
    tok = cred.get("token", {})
    access = tok.get("access_token")
    expiry = tok.get("expiry")
    if not access:
        raise RuntimeError("no access_token in credential blob")
    expired = False
    if expiry:
        try:
            exp = dt.datetime.fromisoformat(expiry)
            now = dt.datetime.now(exp.tzinfo)
            expired = now >= exp
        except ValueError:
            pass

    last_err = None
    for base in BASES:
        try:
            la = _post(base, "/v1internal:loadCodeAssist", access,
                       {"metadata": META, "mode": "FULL_ELIGIBILITY_CHECK"})
            proj = la.get("cloudaicompanionProject")
            tier = (la.get("currentTier") or {}).get("id") or (la.get("paidTier") or {}).get("id")
            fam = _post(base, "/v1internal:fetchAvailableModels", access,
                        {"project": proj} if proj else {})
            models = fam.get("models") or {}
            quotas = []
            for key, m in models.items():
                qi = (m or {}).get("quotaInfo") or {}
                rf = qi.get("remainingFraction")
                if rf is None:
                    continue
                quotas.append({
                    "model": m.get("model") or key,
                    "name": m.get("displayName") or key,
                    "remaining_pct": round(float(rf) * 100, 1),
                    "reset": qi.get("resetTime"),
                })
            quotas.sort(key=lambda q: q["remaining_pct"])
            return {
                "ok": True, "base": base, "tier": tier, "project": proj,
                "token_expiry": expiry, "token_expired": expired,
                "models": quotas,
                "binding_remaining_pct": quotas[0]["remaining_pct"] if quotas else None,
                "binding_reset": quotas[0]["reset"] if quotas else None,
                "checked_at": dt.datetime.now(dt.UTC).isoformat(),
            }
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:400]
            except Exception:
                pass
            last_err = f"{base}: HTTP {e.code} {body}"
        except Exception as e:  # noqa: BLE001
            last_err = f"{base}: {e!r}"
    return {"ok": False, "error": last_err, "token_expiry": expiry, "token_expired": expired}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="emit JSON and write the state file")
    args = ap.parse_args(argv)
    res = pull()
    if args.json:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(res, indent=2), encoding="utf-8")
        print(json.dumps(res, indent=2))
        return 0 if res.get("ok") else 1
    if not res.get("ok"):
        print(f"agy quota: ERROR — {res.get('error')}")
        if res.get("token_expired"):
            print("  (token EXPIRED — run any agy command to refresh the credential)")
        return 1
    print(f"agy quota  (tier={res.get('tier')}, via {res['base'].split('//')[1].split('.')[0]})")
    exp = " EXPIRED" if res.get("token_expired") else ""
    print(f"  token expiry: {res.get('token_expiry')}{exp}")
    if res.get("binding_remaining_pct") is not None:
        print(f"  >> binding: {res['binding_remaining_pct']}% remaining, reset {res.get('binding_reset')}")
    for m in res.get("models", []):
        print(f"    {m['name']:30} {m['remaining_pct']:5}%  reset {m['reset']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
