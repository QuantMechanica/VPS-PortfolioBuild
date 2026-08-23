# Gemini Build EA Artifact: QM5_9910 bandy-tema-adx-crossover-trend

**Date:** 2026-08-23
**Agent:** gemini
**Task ID:** `499eaa2a-1f7a-47d2-b6df-a52d4d2999dc`
**EA ID:** QM5_9910
**Slug:** `bandy-tema-adx-crossover-trend`
**State:** REVIEW

---

## 1. Summary of Changes

- Implemented `QM5_9910_bandy-tema-adx-crossover-trend.mq5` according to the approved strategy card:
  - Entry: D1 closed-bar TEMA(8) / TEMA(21) crossover with ADX(14) >= 20.0 confirmation gate.
  - Exit: ATR(14) Chandelier trailing stop (2.0 * ATR mult) managed per-tick via `QM_TM_TrailATR`, opposite TEMA cross signal exit on closed bar, and 60-bar hard time stop.
  - Stop Loss: Initial stop at 2.0 * ATR distance with 5.0 * ATR catastrophic backstop.
- Created `SPEC.md` documenting strategy logic, parameter table, symbol universe, and risk model.
- Verified approved strategy card at `docs/strategy_card.md`.
- Appended strategy parameters to all backtest setfiles under `sets/`.

---

## 2. Verification

- `validate_build_guardrails.py` executed against `framework/EAs/QM5_9910_bandy-tema-adx-crossover-trend`:
  - 14 files checked (mq5 + 13 setfiles).
  - Verdict: **PASS** (0 findings, stale news <= 336h, fixed risk $1,000, risk percent = 0).
- Magic resolver verified: Magic numbers for EA 9910 (slots 0..12) registered in `magic_numbers.csv` and `QM_MagicResolver.mqh`.

---

## 3. Review Handoff

In accordance with Edge Lab charter rules, Gemini leaves this code task in `REVIEW` for mandatory Codex review before pipeline acceptance.
