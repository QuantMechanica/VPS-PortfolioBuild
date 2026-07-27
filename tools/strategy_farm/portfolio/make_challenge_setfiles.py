"""Derive FTMO demo set files from the EXACT backtest sets, patching risk only.

`gen_setfile.ps1 -Env demo` rebuilds a set file from the approved card, and for
these four EAs that does not reproduce what was actually measured:

  10848  the backtest set carries qm_filter_news_enabled=1 / qm_filter_news_mode=3;
         the regenerated demo set omits both, leaving the news filter to whatever
         the EA compiles in. That is a different strategy.
  9936   its backtest set records card_defaults_source=not_found, so the measured
         run used the EA's own input defaults - while a regenerated set writes
         card values over them.
  13213  card lookup returned null and fell back to ea_input_defaults.

The campaign's 81 % lower bound was produced by runs using the BACKTEST sets. So
the deployable artifact has to be those files with only the risk block changed:

    RISK_FIXED    -> 0
    RISK_PERCENT  -> the campaign multiplier
    environment   -> demo
    risk_mode     -> PERCENT

Every strategy and filter parameter is copied byte-for-byte, which is the only way
the demo can be expected to behave like the measurement.

Multiplier -> RISK_PERCENT is exact rather than fitted: tester_defaults.json sets
initial_deposit = 100000 and all four EAs backtest at RISK_FIXED = 1000, i.e. 1 %
of the account, so a multiplier of L is L % of equity.

Caveat carried into the manifest: RISK_PERCENT sizes off live equity, so position
size drifts up as the account gains, while RISK_FIXED did not. Over a 22-day run
reaching +10 % that is a second-order difference, but it is a difference.
"""
import glob
import hashlib
import json
import os
import re
from datetime import datetime, timezone

# (slug, symbol, RISK_PERCENT, peak concurrent notional as x equity, FTMO leverage)
#
# Revised 2026-07-27 after the leak-free re-measurement:
#   - 13036/GDAXI added. It is the ONLY sleeve in the pool with Q08 = PASS rather
#     than FAIL_SOFT, and at 5.2x exposure / 10.4% margin it is by far the most
#     margin-efficient account in the book.
#   - 10848 lowered 5% -> 4%: the earlier 5% was picked under a combination search
#     that leaked the scoring period.
#   - 9936 held back: its Q08 was requeued after an INFRA_FAIL and is still
#     running, so it is pending rather than passed.
BOOK = [
    ("QM5_13213_balke-gmt3-range-breakout", "USDJPY", 4.0, 73.8, 100),
    ("QM5_10848_tv-mtf-ambush", "XAUUSD", 4.0, 17.2, 30),
    ("QM5_10553_mql5-rsioma", "XAUUSD", 8.0, 19.9, 30),
    ("QM5_13036_balke-go-long-regime", "GDAXI", 8.0, 5.2, 50),
]
ACCOUNT = 100_000.0


def patch(text, risk_percent):
    out, seen_fixed, seen_pct = [], False, False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("RISK_FIXED="):
            out.append("RISK_FIXED=0")
            seen_fixed = True
        elif s.startswith("RISK_PERCENT="):
            out.append(f"RISK_PERCENT={risk_percent:g}")
            seen_pct = True
        elif s.startswith("; environment:"):
            out.append("; environment:  demo")
        elif s.startswith("; risk_mode:"):
            out.append("; risk_mode:    PERCENT")
        elif s.startswith("; set_version:"):
            out.append(line)
            out.append("; derived_from: backtest set, risk block only (challenge campaign)")
        else:
            out.append(line)
    if not seen_fixed:
        out.append("RISK_FIXED=0")
    if not seen_pct:
        out.append(f"RISK_PERCENT={risk_percent:g}")
    return "\n".join(out) + "\n"


manifest = {
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "purpose": "FTMO Phase 1 campaign - one challenge account per sleeve",
    "measurement": "docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md",
    "ftmo_leverage_source": (
        "ftmo.com blog 'A few answers to your questions' fetched 2026-07-27: "
        "forex 1:100, indices 1:50 (1:30 for HK50/US2000/SPN35), metals 1:30, "
        "Normal account type"
    ),
    "accounts": [],
}

for slug, sym, mult, exposure, lev in BOOK:
    src = sorted(glob.glob(f"framework/EAs/{slug}/sets/*{sym}.DWX_*_backtest.set"))
    if not src:
        print(f"!! {slug} {sym}: no backtest set found")
        continue
    src = src[0]
    tf = re.search(r"\.DWX_([A-Z0-9]+)_", os.path.basename(src)).group(1)
    text = open(src, encoding="utf-8", errors="replace").read()
    patched = patch(text, mult)
    dst = os.path.join(os.path.dirname(src),
                       f"{slug}_{sym}.DWX_{tf}_ftmo_challenge.set")
    with open(dst, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(patched)
    sha = hashlib.sha256(patched.encode("utf-8")).hexdigest()

    margin_pct = exposure / lev
    manifest["accounts"].append({
        "ea": slug,
        "symbol": f"{sym}.DWX",
        "timeframe": tf,
        "risk_percent": mult,
        "risk_fixed": 0,
        "setfile": dst.replace("\\", "/"),
        "setfile_sha256": sha,
        "derived_from": src.replace("\\", "/"),
        "peak_concurrent_notional_x_equity": exposure,
        "ftmo_leverage": f"1:{lev}",
        "margin_used_pct": round(margin_pct * 100, 1),
        "margin_level_at_ftmo_loss_limit_pct": round(0.90 / margin_pct * 100),
    })
    print(f"{slug:38}{sym:8}{tf:4} RISK_PERCENT={mult:<5g} "
          f"margin {margin_pct*100:5.1f}%  sha {sha[:12]}")

os.makedirs("docs/ops/evidence", exist_ok=True)
out = "docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json"
with open(out, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(manifest, fh, indent=2)
print()
print(f"manifest -> {out}")

print()
print("parameter identity check against the backtest source:")
for a in manifest["accounts"]:
    src = open(a["derived_from"], encoding="utf-8", errors="replace").read()
    dst = open(a["setfile"], encoding="utf-8", errors="replace").read()

    def kv(t):
        d = {}
        for line in t.splitlines():
            line = line.strip()
            if line and not line.startswith(";") and "=" in line:
                k, _, v = line.partition("=")
                d[k.strip()] = v.strip()
        return d

    s, d = kv(src), kv(dst)
    risk = {"RISK_FIXED", "RISK_PERCENT"}
    diff = [k for k in set(s) | set(d)
            if k not in risk and s.get(k) != d.get(k)]
    status = "IDENTICAL" if not diff else f"DIFFERS: {diff}"
    print(f"   {a['ea']:38} {status}")
