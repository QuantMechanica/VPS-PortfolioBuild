"""Derive FTMO Phase 1 / Phase 2 set files for QM5_9936 from the EXACT backtest set.

Target sleeve (single-account measurement, reproduced and confirmed in
docs/ops/evidence/2026-07-27_single_account_adversarial_review.md §1):
`9936:USDJPY @ 3x` — OOS 35.7%, breach 44%, median 33d. 3x means three times the
1% base the framework enforces: tester_defaults.json sets initial_deposit=100000
and the backtest set carries RISK_FIXED=1000 (= 1% of the account), so a 3x sleeve
is RISK_PERCENT=3.

Method — identical in spirit to make_challenge_setfiles.py: DO NOT regenerate from
the card (`gen_setfile.ps1 -Env demo` drops filter settings and rewrites card
values over the EA input defaults, and 9936's backtest set records
`card_defaults_source=not_found`, i.e. the measured run used the EA's OWN input
defaults). The deployable artifact is the backtest set with ONLY the risk block
changed, so every strategy and filter parameter reproduces the measurement
byte-for-byte.

The risk block for the phase selector is broader than the two RISK_* keys because
the phase now owns the per-trade cap and the phase itself:

    RISK_FIXED        1000 -> 0            (HR: RISK_PERCENT for live/demo, never mix)
    RISK_PERCENT      0    -> 3            (3x sleeve sizing)
    qm_risk_cap_pct   (absent) -> 3        (OWNER-ratified band (0,5.0]; WITHOUT this
                                            the 3% is clamped to 1% at
                                            QM_RiskSizer.mqh:111 — the 79.5->4.7 gap)
    prop_phase        (absent) -> 1 | 2    (1=Challenge target +10%, 2=Verification +5%)
    ; environment     backtest -> demo
    ; risk_mode       FIXED    -> PERCENT

Everything else is copied unchanged. prop_expected_login stays at its compiled
default 0 (off): the H3 account binding must be set to the real challenge login at
deploy time (T_Live-style manifest/SHA verification, OWNER+Claude), which cannot be
known here. prop_allow_unit_risk stays false — the cap is 3, not the rejected 1.0
sprint default. All other prop_* inputs keep their OFF-safe compiled defaults.

Caveat carried forward from make_challenge_setfiles.py: RISK_PERCENT sizes off live
equity, so position size drifts up as the account gains, while RISK_FIXED did not.
Over a challenge reaching +10% that is a second-order difference, but it is a
difference. QM_PropRiskBasis (anchor-to-start) is defined but not yet wired into the
entry path (implementation note L2), so this caveat still stands.
"""
import hashlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SLUG = "QM5_9936_ff-range-breakout-gmt3-h1"
SETS = REPO / "framework" / "EAs" / SLUG / "sets"
SRC = SETS / f"{SLUG}_USDJPY.DWX_H1_backtest.set"

RISK_PERCENT = 3.0   # 3x sleeve (single-account best)
RISK_CAP_PCT = 3.0   # un-clamp: cap must be >= RISK_PERCENT or sizing is clamped to 1%
PHASES = {1: "ftmo_phase1", 2: "ftmo_phase2"}

# Keys that ARE the intended risk block (excluded from the parameter-identity diff).
RISK_BLOCK = {"RISK_FIXED", "RISK_PERCENT", "qm_risk_cap_pct", "prop_phase"}


def patch(text: str, phase: int) -> str:
    out, seen_fixed, seen_pct = [], False, False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("RISK_FIXED="):
            out.append("RISK_FIXED=0")
            seen_fixed = True
        elif s.startswith("RISK_PERCENT="):
            out.append(f"RISK_PERCENT={RISK_PERCENT:g}")
            seen_pct = True
        elif s.startswith("; environment:"):
            out.append("; environment:  demo")
        elif s.startswith("; risk_mode:"):
            out.append("; risk_mode:    PERCENT")
        elif s.startswith("; set_version:"):
            out.append(line)
            out.append("; derived_from: backtest set, risk block only (FTMO phase selector)")
        else:
            out.append(line)
    if not seen_fixed:
        out.append("RISK_FIXED=0")
    if not seen_pct:
        out.append(f"RISK_PERCENT={RISK_PERCENT:g}")
    # Phase selector + un-clamp cap. Appended (set files match by key name, so
    # order is irrelevant); grouped under a comment for the human reader.
    out.append("; --- FTMO phase selector (QM_PropFirm.mqh) ---")
    out.append(f"prop_phase={phase}")
    out.append(f"qm_risk_cap_pct={RISK_CAP_PCT:g}")
    return "\n".join(out) + "\n"


def kv(text: str) -> dict:
    d = {}
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith(";") and "=" in line:
            k, _, v = line.partition("=")
            d[k.strip()] = v.strip()
    return d


def main() -> int:
    if not SRC.exists():
        print(f"!! backtest set not found: {SRC}")
        return 1
    src_text = SRC.read_text(encoding="utf-8", errors="replace")
    src_kv = kv(src_text)

    print(f"source: {SRC.relative_to(REPO).as_posix()}")
    print(f"target sleeve: 9936:USDJPY @ 3x  ->  RISK_PERCENT={RISK_PERCENT:g}, "
          f"qm_risk_cap_pct={RISK_CAP_PCT:g}\n")

    for phase, tag in PHASES.items():
        patched = patch(src_text, phase)
        dst = SETS / f"{SLUG}_USDJPY.DWX_H1_{tag}.set"
        dst.write_text(patched, encoding="utf-8", newline="\n")
        sha = hashlib.sha256(patched.encode("utf-8")).hexdigest()
        dst_kv = kv(patched)

        diff = sorted(
            k for k in (set(src_kv) | set(dst_kv))
            if k not in RISK_BLOCK and src_kv.get(k) != dst_kv.get(k)
        )
        status = "IDENTICAL" if not diff else f"DIFFERS: {diff}"
        print(f"[phase {phase}] {dst.name}")
        print(f"    sha256              {sha}")
        print(f"    RISK_FIXED          {src_kv.get('RISK_FIXED')} -> {dst_kv.get('RISK_FIXED')}")
        print(f"    RISK_PERCENT        {src_kv.get('RISK_PERCENT')} -> {dst_kv.get('RISK_PERCENT')}")
        print(f"    qm_risk_cap_pct     (absent) -> {dst_kv.get('qm_risk_cap_pct')}")
        print(f"    prop_phase          (absent) -> {dst_kv.get('prop_phase')}")
        print(f"    non-risk-block keys {status}")
        print(f"    keys(src)={len(src_kv)}  keys(dst)={len(dst_kv)}  "
              f"(delta = qm_risk_cap_pct + prop_phase = 2)\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
