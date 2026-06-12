# Own-Data Studies H3-H4-H5: Intraday Structure 2026-06-12

**Task:** 648ffc09  
**Evidence:** `D:/QM/reports/research/intraday_h3_h4_h5_study_2026-06.csv`  
**Script:** `C:/QM/repo/framework/scripts/mt5_diagnostics/analyze_intraday_h3_h4_h5.py`  
**Data:** H1 bars from T_Export (D:/QM/mt5/T_Export/MQL5/Files/)  
**Resolution downgrade:** M30 was specified; M30 not yet exported from T_Export. H1 used as proxy — all conclusions are preliminary and subject to M30 upgrade.  
**DST handling:** broker_hour = (UTC_hour + 3) % 24 during US DST (2nd Sun Mar → 1st Sun Nov), else +2.  
**DEV:** 2018-2021 (full years). **OOS:** 2022-2025. 2026 excluded for OOS purity.  
**Pre-registered threshold:** tradeable = OOS net t > 2.0 AND same sign as DEV.

---

## H3: By-Broker-Hour Mean Log-Return (NDX.DWX, XAUUSD.DWX)

### NDX.DWX — Result: DEAD

No broker hour clears |t| > 2 in both DEV and OOS with the same sign. NDX intraday drift at H1 resolution is not tradeable. The power-hour proxy (broker hr 21) shows t = −0.47 DEV / +1.34 OOS — inconsistent sign. NY lunch proxy (broker hr 19): t = +1.02 DEV / −0.14 OOS — sign flip.

**Verdict: DEAD for NDX at H1. M30 upgrade unlikely to reverse this given inconsistency.**

### XAUUSD.DWX — Result: BUILD_CARD CANDIDATE ⚠️

**Stable hours (|t| > 2 in both DEV and OOS, same positive sign):** broker hours **03, 04, 05**

| Broker Hour | DEV mean % | DEV t | OOS mean % | OOS t | Notes |
|-------------|-----------|-------|-----------|-------|-------|
| bkr03       | +0.0425   | +4.43 | +0.0480   | +4.24 | n=357/351 (sparse — session-open gap) |
| bkr04       | +0.0140   | +2.12 | +0.0138   | +2.45 | n=1033/1026 (full coverage) |
| bkr05       | +0.0202   | +4.28 | +0.0102   | +2.13 | n=1033/1026 (full coverage) |

Broker hours 03-05 correspond approximately to **UTC 00-02 (DST) / UTC 01-03 (non-DST)** — the early Sydney-open / pre-Tokyo XAUUSD segment.

**Data quality note on bkr03:** Only ~35% of expected bars present at broker hour 03 (n≈350 vs ≈1033 for adjacent hours). This is consistent with Darwinex XAUUSD daily close/reopen around midnight broker time — bars 00-02 are partially absent in the raw data. The t-stats at bkr03 (+4.4 DEV, +4.2 OOS) are very high but may partly reflect survivorship bias (only the sessions that reopened cleanly are represented).

**Hours 04 and 05 have full coverage** (n>1000) and show stable positive t-stats in both periods. This is the **more reliable finding**.

**Interpretation:** Persistent positive drift in XAUUSD during early Asian session (broker 04-05, approximately 01:00-03:00 UTC) across 2018-2021 AND 2022-2025. Both periods show t > 2 with same sign.

**Mechanization path:** Time-of-day drift EA. Entry at open of broker hour 04, exit at close of broker hour 05. SL = 1.5×ATR(14) on H1. No directional filter needed given stable sign.

**M30 upgrade required before card:** At M30 resolution, we would have 30-minute slots instead of 1-hour. The actual strong signal may be concentrated in specific 30-minute windows within hours 04-05. DO NOT build the card on H1 alone — need M30 export from T_Export.

**Action required:** Codex to run Export_FX_Bars for XAUUSD.DWX M30 in T_Export. Then re-run the analysis at M30 resolution before building the card.

---

## H4: GDAXI Post-Xetra Drift Conditioned on Session Sign — Result: DEAD

Post-Xetra window (broker hr 18-22): no meaningful drift conditioned on Xetra body sign.

| Period | Body UP mean % | Body UP t | Body DN mean % | Body DN t |
|--------|---------------|-----------|---------------|-----------|
| DEV    | +0.0078       | +0.24     | −0.0005       | −0.01     |
| OOS    | +0.0105       | +0.44     | +0.0147       | +0.52     |

OOS body-DN mean is *positive* — the opposite direction to what a continuation hypothesis predicts. t-stats < 1 throughout. **Verdict: DEAD.**

Note: The post-Xetra window at H1 may be too coarse (5 bars: hrs 18-22). At M30 there might be a sharper pattern, but the completely flat t-stats make this unlikely to survive.

---

## H5: XAUUSD Asia Range Contraction vs London Persistence — Result: DEAD

Asia session (broker hr 01-08) range quintile vs London session (broker hr 09-14) absolute return.

OOS results per quintile are all t < 1. No monotonic relationship between Asia range size and London directional persistence. Both contracted-range (Q1) and expanded-range (Q5) London returns are negligible (OOS t < 1).

**Verdict: DEAD.** The Asia range does not predict London session direction at H1 resolution. M30 would give better range estimation but the Q1 vs Q5 OOS t-stats (~0.06 vs ~0.82) are too weak to suggest a real signal.

---

## Summary Verdicts

| Study | Verdict | Action |
|-------|---------|--------|
| H3 NDX | DEAD | None |
| H3 XAUUSD bkr04-05 | BUILD_CARD (pending M30) | Codex: export XAUUSD.DWX M30 from T_Export |
| H3 XAUUSD bkr03 | INCONCLUSIVE (sparse data) | Investigate session gaps before using |
| H4 GDAXI | DEAD | None |
| H5 XAUUSD | DEAD | None |

## Blockers

- M30 data not in T_Export. Required for XAUUSD bkr04-05 BUILD_CARD promotion.
- Codex action: run `D:/QM/mt5/T_Export/MQL5/Experts/Export_FX_Bars.mq5` configured for XAUUSD.DWX M30, 2016-2026. Then re-run `analyze_intraday_h3_h4_h5.py` with M30 data.
