# QM5_20077 Build Evidence — Precondition Hold (Magic Allocation)

- Task ID: 6c35c3ec-b576-4919-a321-796b7c813350 (uild_ea, priority 10, assigned to Gemini)
- EA ID: QM5_20077
- Slug: tr-channel-trail-breakout-h1
- Date: 2026-08-29
- Branch: gents/board-advisor
- Outcome: PRECONDITION_HOLD_MAGIC_ALLOCATION_PENDING

---

## 1. Summary of Deliverables & Implementation

- **Source Implementation**: ramework/EAs/QM5_20077_atr-channel-trail-breakout-h1/QM5_20077_atr-channel-trail-breakout-h1.mq5
  - V5 framework corset adherence: All strategy logic partitioned into standard hooks (Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook).
  - Mechanics: H1 closed-bar Donchian/ATR-channel breakout with D1 ATR volatility filter and 200 EMA macro trend filter.
  - Risk Model: Standard user inputs RISK_PERCENT=0.0 and RISK_FIXED=1000.0.
  - News Filter: qm_news_stale_max_hours=336, fail-closed compliance mode.
- **Specification**: ramework/EAs/QM5_20077_atr-channel-trail-breakout-h1/SPEC.md
- **Setfiles**: Generated backtest setfiles under ramework/EAs/QM5_20077_atr-channel-trail-breakout-h1/sets/ for portable basket symbols:
  - EURUSD.DWX (slot 0)
  - GBPUSD.DWX (slot 1)
  - NDX.DWX (slot 2)
  - USDJPY.DWX (slot 3)
  - XAUUSD.DWX (slot 4)
- **Local Build Manifest**: ramework/EAs/QM5_20077_atr-channel-trail-breakout-h1/build_result.json

---

## 2. Verification & Guardrails

- alidate_build_guardrails.py run against QM5_20077_atr-channel-trail-breakout-h1.mq5:
  - **Verdict**: PASS (0 findings; max news stale hours 336; fixed risk .0).
- a_id_registry.csv check:
  - Active entry present: 20077,atr-channel-trail-breakout-h1,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Research,2026-07-23,,,
- magic_numbers.csv check:
  - No active magic allocation for base 200770000.
  - compile_ea.py returns MAGIC_NOT_REGISTERED.

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab hard rules:
- Registry mutations must proceed through governed_magic_allocator.py in governed serial batches (tracked under task 8d1d903f-39cc-461f-ab90-7b932ce62fee).
- Gemini drafts code and documentation, leaving the task in REVIEW for mandatory Codex review before pipeline acceptance.

**Short Verdict**: PRECONDITION_HOLD: EA code & sets drafted; pending magic allocation in magic_numbers.csv (tracked by 8d1d903f).
