# Gemini Build EA Artifact: QM5_9911 bandy-donchian-20-classic-breakout-trend

**Date:** 2026-08-23
**Agent:** gemini
**Task ID:** `970379cc-27ef-4f71-a07e-5421e45171ef`
**EA ID:** QM5_9911
**Slug:** `bandy-donchian-20-classic-breakout-trend`
**State:** REVIEW

---

## 1. Summary of Changes

- Implemented `QM5_9911_bandy-donchian-20-classic-breakout-trend.mq5` according to the approved strategy card:
  - Entry: D1 closed-bar Donchian channel breakout (`donchian_high` / `donchian_low` over prior 20 completed bars shifts 2..21) confirmed by 200-SMA regime filter on shift 1 (`close[1] > regime` for Long, `close[1] < regime` for Short).
  - Exit: Turtle-style 10-bar trailing channel exit on completed bars (`close[1] < exit_llv` for Long, `close[1] > exit_hhv` for Short) and hard time stop (60 D1 bars).
  - Stop Loss: 2.5 * ATR(14) catastrophic backstop attached at entry.
- Created `SPEC.md` documenting strategy logic, parameter table, symbol universe, and risk model.
- Added approved strategy card to `docs/strategy_card.md`.
- Appended strategy parameters to all backtest setfiles under `sets/`.

---

## 2. Verification

- `validate_build_guardrails.py` executed against `framework/EAs/QM5_9911_bandy-donchian-20-classic-breakout-trend`:
  - 14 files checked (mq5 + 13 setfiles).
  - Verdict: **PASS** (0 findings, stale news <= 336h, fixed risk $1,000, risk percent = 0).
- Magic resolver verified: Magic numbers for EA 9911 (slots 0..12) registered in `magic_numbers.csv` and `QM_MagicResolver.mqh`.

---

## 3. Review Handoff

In accordance with Edge Lab charter rules, Gemini leaves this code task in `REVIEW` for mandatory Codex review before pipeline acceptance.
