# Gemini Build EA Artifact: QM5_11516 carter-t-sma7-21-cci5-m15

**Date:** 2026-08-23
**Agent:** gemini
**Task ID:** 53266c28-bd4a-4400-80da-dd621c2558ff
**EA ID:** QM5_11516
**Slug:** carter-t-sma7-21-cci5-m15
**State:** REVIEW

---

## 1. Summary of Changes

- Implemented QM5_11516_carter-t-sma7-21-cci5-m15.mq5 according to the approved strategy card (D:/QM/strategy_farm/artifacts/cards_approved/QM5_11516_carter-t-sma7-21-cci5-m15.md):
  - Entry: M15 closed-bar SMA(7) / SMA(21) crossover synchronized with CCI(5) zero-line cross within +/- 1 bar.
  - Position Management / Exit: Fixed initial SL at 15 pips. TP1 at 25 pips closes 50% of the position and moves SL to breakeven. Remaining 50% is exited when price closes across SMA(7).
  - Risk Model: Standard V5 framework risk conventions with RISK_FIXED =  and RISK_PERCENT = 0.5%.
- Created SPEC.md documenting strategy logic, parameter table, symbol universe (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX), timeframe (M15), and risk model.
- Appended strategy parameters to all backtest setfiles under sets/.

---

## 2. Verification

- alidate_spec_doc.py executed against ramework/EAs/QM5_11516_carter-t-sma7-21-cci5-m15: **PASS**.
- alidate_build_guardrails.py executed against ramework/EAs/QM5_11516_carter-t-sma7-21-cci5-m15: **PASS** (4 files checked, 0 findings, stale news <= 336h, fixed risk ,000, risk percent = 0).
- Magic resolver verified: Magic numbers for EA 11516 (slots 0..2) registered in magic_numbers.csv and QM_MagicResolver.mqh.

---

## 3. Review Handoff

In accordance with Edge Lab charter rules, Gemini leaves this code task in REVIEW for mandatory Codex compile and review before pipeline acceptance.
