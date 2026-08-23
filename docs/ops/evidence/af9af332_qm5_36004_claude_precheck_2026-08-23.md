# Claude pre-check: QM5_36004 Gemini remediation (review_ea)

- Router task: `af9af332-6c97-4abd-a319-4373c82e0844`
- Gemini source task: `22225e01-3ed6-4a1f-8fca-b55655117d01`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/22225e01-3ed6-4a1f-8fca-b55655117d01.json`
- Reviewed against original Codex review: `docs/ops/evidence/80b2cb2a_qm5_36004_gemini_build_codex_review_2026-08-18.md`
- Remediation claim: `docs/ops/evidence/22225e01_qm5_36004_build_ea_result_2026-08-23.md`
- Remediation commits: `1c8d911f9` (source fixes), `73acf69db` (setfile build_hash + D10 fix)
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; Codex review still mandatory (hard rule)**

## Independent verification of the 7 original findings

| # | Codex finding | Verdict | Evidence |
|---|---|---|---|
| 1 | Full-position TP instead of 50% TP1 + runner | **FIXED** | `req.tp = 0.0` at entry; `Strategy_ManageOpenPosition` calls `QM_TM_PartialClose(ticket, half_lots, QM_EXIT_PARTIAL)` at +1 ATR, then moves SL to BE. |
| 2 | QQE persistent state used as "crossover" | **FIXED** | `Strategy_QQECross` compares state at shift 1 vs shift 2; only fires on a genuine transition. |
| 3 | Rollover blackout evaluated in broker time | **FIXED** | Now uses `QM_BrokerToUTC(TimeCurrent())` before the 23:55-00:05 window check. |
| 4 | Card loss-limit contract absent | **FIXED** | `QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), 2.5, 5.0, 1.0)` in `OnInit`; 2.0% entry halt in `Strategy_NoTradeFilter` (measured on day-start equity drawdown, a conservative proxy for "realized loss" — flag for Codex to confirm intent, non-blocking). |
| 5 | Producer result blocked, no smoke evidence | **NOT FIXED — blocking** | The evidence doc still admits `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. Confirmed on disk: `.ex5` file timestamp is 2026-08-17 23:23, the remediated `.mq5` is 2026-08-23 13:53. **The committed EX5 SHA-256 (`a83f0c2b2088079e028605e414fae6f98b4e91ad5500bfab22f1b3b7e34896d4`) is byte-identical to the EX5 reviewed and rejected on 2026-08-18** — the binary was never recompiled after the source remediation. This is the same stale-`.ex5`-vs-remediated-`.mq5` defect class previously caught and rejected on QM5_35004/QM5_35005/QM5_36003. |
| 6 | No committed identity | **FIXED** | Source and setfiles committed in `1c8d911f9` / `73acf69db`; working tree clean for the EA dir. |
| 7 | Entry filters suspended position management | **FIXED** | `OnTick` runs `Strategy_ManageOpenPosition()` and the exit-signal close loop before the news gate / `Strategy_NoTradeFilter`. |

## Dead-input scan (QM5_1355 defect class)

All 13 `strategy_*` inputs (ALMA, QQE, DPO, VFI, ATR, SL/TP/spread multipliers) have live use-sites beyond their own declaration. No dead inputs found.

## Evidence-doc checklist cross-check

Setfiles under `sets/` confirm `RISK_FIXED=1000` / `RISK_PERCENT=0` for all 4 basket symbols. `framework/registry/magic_numbers.csv` has 4 collision-free active rows (360040000-360040003) matching SPEC and the remediation doc. The compilation-refused claim in the remediation doc is accurate, not concealed — but it means the checked-in binary cannot be treated as reflecting the current source.

## Disposition

6 of 7 source-level findings are genuinely fixed. Finding 5 remains open and is release-blocking on its own terms: the checked-in `.ex5` predates the remediated `.mq5` by six days and reflects the pre-remediation code. QM5_36004 must be recompiled (in an off-window, per governance) and smoke-tested before any Codex acceptance or pipeline handoff. Left in REVIEW; not self-approved; no pipeline state changed.
