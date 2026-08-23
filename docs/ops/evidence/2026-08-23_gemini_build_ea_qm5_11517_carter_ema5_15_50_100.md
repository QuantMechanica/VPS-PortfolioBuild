# Gemini Build EA Artifact: QM5_11517 carter-t-ema5-15-50-100-macd-h4

**Date:** 2026-08-23
**Agent:** gemini
**Task ID:** df68e99a-096b-4875-b408-d64cf204f2b0
**EA ID:** QM5_11517
**Slug:** carter-t-ema5-15-50-100-macd-h4
**State:** REVIEW

---

## 1. Summary of Changes

- Implemented QM5_11517_carter-t-ema5-15-50-100-macd-h4.mq5 according to the approved strategy card (D:/QM/strategy_farm/artifacts/cards_approved/QM5_11517_carter-t-ema5-15-50-100-macd-h4.md):
  - Entry: H4 closed-bar 4-EMA ribbon alignment (EMA 5 crossing EMA 15 within 3 bars while price is above EMA 50 and EMA 100 for long, below for short) confirmed by MACD(12,26,9) zero-line sign.
  - Exit: Fixed SL at 30 pips and fixed TP at 60 pips.
  - Risk Model: Standard V5 framework risk conventions with RISK_FIXED =  and RISK_PERCENT = 0.5%.
- Created SPEC.md documenting strategy logic, parameter table, symbol universe (EURUSD.DWX, GBPUSD.DWX), timeframe (H4), and risk model.
- Appended strategy parameters to all backtest setfiles under sets/.

---

## 2. Verification

- alidate_spec_doc.py executed against ramework/EAs/QM5_11517_carter-t-ema5-15-50-100-macd-h4: **PASS**.
- alidate_build_guardrails.py executed against ramework/EAs/QM5_11517_carter-t-ema5-15-50-100-macd-h4: **PASS** (3 files checked, 0 findings, stale news <= 336h, fixed risk ,000, risk percent = 0).
- Magic resolver verified: Magic numbers for EA 11517 (slots 0..1) registered in magic_numbers.csv and QM_MagicResolver.mqh.

---

## 3. Review Handoff

In accordance with Edge Lab charter rules, Gemini leaves this code task in REVIEW for mandatory Codex compile and review before pipeline acceptance.
