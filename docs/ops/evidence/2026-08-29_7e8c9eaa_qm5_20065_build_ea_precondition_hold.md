# QM5_20065 Build Evidence — Precondition Hold (Magic Allocation)

- Task ID: 7e8c9eaa-1af5-40ca-9f49-4c785b5ae07d (uild_ea, priority 10, assigned to Gemini)
- EA ID: QM5_20065
- Slug: pricebob-refbar-breakout-eurusd
- Date: 2026-08-29
- Branch: gents/board-advisor
- Outcome: PRECONDITION_HOLD_MAGIC_ALLOCATION_PENDING

---

## 1. Summary of Deliverables & Implementation

- **Source Implementation**: ramework/EAs/QM5_20065_pricebob-refbar-breakout-eurusd/QM5_20065_pricebob-refbar-breakout-eurusd.mq5
  - V5 framework corset adherence: All strategy logic partitioned into standard hooks (Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook).
  - Mechanics: EURUSD M15 reference-bar (08:00 broker time) breakout with D1 ATR range filters and max spread ratio checks.
  - Risk Model: Standard user inputs RISK_PERCENT=0.0 and RISK_FIXED=1000.0.
  - News Filter: qm_news_stale_max_hours=336, fail-closed compliance mode.
- **Specification**: ramework/EAs/QM5_20065_pricebob-refbar-breakout-eurusd/SPEC.md
- **Setfiles**: Generated backtest setfiles under ramework/EAs/QM5_20065_pricebob-refbar-breakout-eurusd/sets/:
  - EURUSD.DWX (slot 0)
- **Local Build Manifest**: ramework/EAs/QM5_20065_pricebob-refbar-breakout-eurusd/build_result.json

---

## 2. Verification & Guardrails

- alidate_build_guardrails.py run against QM5_20065_pricebob-refbar-breakout-eurusd.mq5:
  - **Verdict**: PASS (0 findings; max news stale hours 336; fixed risk .0).
- a_id_registry.csv check:
  - Active entry present: 20065,pricebob-refbar-breakout-eurusd,68eff294-e3b2-5010-82d8-e9dd5f4130e6,active,Research,2026-07-23,,,
- magic_numbers.csv check:
  - No active magic allocation for base 200650000.
  - compile_ea.py returns MAGIC_NOT_REGISTERED.

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab hard rules:
- Registry mutations must proceed through governed_magic_allocator.py in governed serial batches (tracked under task 8d1d903f-39cc-461f-ab90-7b932ce62fee).
- Gemini drafts code and documentation, leaving the task in REVIEW for mandatory Codex review before pipeline acceptance.

**Short Verdict**: PRECONDITION_HOLD: EA code & sets drafted; pending magic allocation in magic_numbers.csv (tracked by 8d1d903f).
