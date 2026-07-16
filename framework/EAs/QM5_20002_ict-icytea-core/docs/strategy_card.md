---
ea_id: 20002
slug: ict-icytea-core
strategy_id: ICT-ICYTEA-CORE-2026
status: intake
owner: claude
created_at: 2026-07-16
target_symbols: [EURUSD.DWX, GBPUSD.DWX]
timeframes: [M1, M5]
source: MQL5_Strategie_Spezifikation_some_icy_tea.docx (770 annotated ICT trades, @some_icy_tea)
---

# ICT icy-tea Core Model (QM5_20002)

Mechanization of the ICT / Smart-Money core setup distilled from 770 annotated trades of
@some_icy_tea. Faithful to `docs/BUILD_BRIEF.md` (spec Ch 3 core model). Timeframe: **M1**
execution with **M5** as second, HTF context M15/H1.

## Edge hypothesis
Intraday liquidity engineering: a **sweep** of a documented liquidity level (EQH/EQL,
PDH/PDL, session H/L) inside a **killzone** (London 02:00–05:00 NY / New York 07:00–10:00 NY)
is followed by a **Market Structure Shift with displacement** (impulse leaving a Fair Value
Gap). Entry is a limit into the impulse's **FVG/Order-Block** in the **discount** half of the
dealing range; stop behind the sweep extreme; target the **opposite external liquidity**.
CRV 1:3–1:5 typical. Direction-neutral (spec: 404 short / 366 long).

## Modules (spec Ch 5 — toggleable, core always on)
Judas Swing, Turtle Soup, Unicorn, Silver Bullet, TGIF, 3 Drives, Market-Maker Model, SMT
divergence filter, Index Macros, News-reversal. Phase 1 ships core-only; modules stubbed +
toggled, filled in Phase 2/3. Each config is a factory-testable set file.

## Honesty (spec Ch 9)
Source screenshots are winners only (survivorship) → no winrate implied; charts 2020–2023.
The **backtest must produce the expectancy** — gates decide, not the source's annotations.
Per-idea risk ≤1% (book rule); RISK_FIXED backtest / RISK_PERCENT live.

## Pipeline
Phase 1: core model, EURUSD then GBPUSD, London+NY killzone, validated against xlsx
reference trades before Q02. Gates Q02–Q10 decide viability.
