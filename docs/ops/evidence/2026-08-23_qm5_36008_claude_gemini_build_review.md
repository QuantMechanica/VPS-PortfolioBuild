# Claude review: QM5_36008 Gemini build

- Review task: `b92a7b1b-ee6c-4e1c-85f7-6d37e1c747ee`
- Gemini source task: `bab6e8bf-435d-4da2-a25f-1e651cb33960`
- Source artifact: `D:/QM/strategy_farm/artifacts/build_results/QM5_36008_nnfx-gold-kama-vortex-supertrend_build_result.json`
- Reviewed source: `framework/EAs/QM5_36008_nnfx-gold-kama-vortex-supertrend/QM5_36008_nnfx-gold-kama-vortex-supertrend.mq5`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36008_nnfx-gold-kama-vortex-supertrend.md`
- **Verdict: CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff.**

Per hard rule (Gemini-originated code requires mandatory Codex review before acceptance),
this task stays in REVIEW; Claude does not self-approve or advance gemini-originated
builds to PIPELINE.

## Findings

### 1. High: two-stage TP1 + runner lifecycle collapsed to a single signal exit

Card §3.4 requires TP1 at +1.0 ATR closing 50% of volume and moving SL to break-even, then
holding a runner to the KAMA/Vortex/SuperTrend opposite-cross exit. `req.tp` is never set
(stays 0.0, no broker TP either), and `Strategy_ManageOpenPosition()` (lines 296-298) is an
empty stub — no partial close, no break-even move. Only the runner opposite-cross exit
(`Strategy_ExitSignal`, lines 300-347) exists. The approved two-stage payoff structure is
silently reduced to an all-or-nothing signal exit, same defect class as QM5_36001/36004
finding 1 before their remediation.

### 2. Medium: kill-switch / loss-limit contract not wired to card values

No `QM_KillSwitchInit` call with card values; the EA inherits the framework default
(`QM_Common.mqh:298` → daily=3.0%, portfolio DD=0.0%=disabled). Card §4.2 wants daily=2.5%,
total DD=5.0%. The card's §3.1.3 daily 2.0% realized-loss no-trade condition is also absent
from `Strategy_NoTradeFilter()` (only spread + rollover are checked). The approved drawdown
contract is not enforced at all for this EA.

### 3. High: OnTick ordering gates protective exits behind the entry filter

Line 401 `if(Strategy_NoTradeFilter()) return;` runs before `Strategy_ManageOpenPosition()`
(404) and `Strategy_ExitSignal()` (406). During a spread spike (>1.8x ATR) or the 23:55-00:05
rollover blackout, an already-open position is neither managed nor exited — the no-trade gate
(meant to govern entries only) also suspends protection of existing positions. Same defect
class as the Medium finding 7/6 on the sibling EAs.

## What is already correct (no defect)

- Rollover blackout uses `TimeGMT()` (true GMT), correctly encodes 23:55-00:05, unlike the
  sibling EAs' original (pre-remediation) broker-time bug.
- Crossover/persistent-state logic is faithful to the card, which specifies state comparisons
  (`>`/`<`) rather than "crosses", so no substitution defect here.
- Gold/XAU point handling: sizing via framework `QM_StopATR` (ATR-value x multiplier,
  symbol-agnostic), spread cap and WAE deadzone use `SYMBOL_POINT` — no hardcoded FX-pip
  assumption inappropriate for XAU.
- All 19 `strategy_*` inputs are read somewhere in the logic (no unwired inputs).
- `qm_news_stale_max_hours = 336` (at the hard ceiling, compliant, not above it).
- Both backtest setfiles (XAUUSD.DWX, XTIUSD.DWX) use `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `ENV=backtest`.

## Disposition

Return to the build lane for remediation: (1) implement the TP1/break-even/partial-close
lifecycle per card §3.4, (2) reorder `OnTick` so `Strategy_ManageOpenPosition`/
`Strategy_ExitSignal` run before `Strategy_NoTradeFilter`, (3) wire
`QM_KillSwitchInit(..., 2.5, 5.0, ...)` and the 2.0% daily entry halt per card §4.2. This is
the same fix pattern already applied and independently re-verified today for QM5_36001 and
QM5_36004 (`docs/ops/evidence/2026-08-23_qm5_36001_claude_remediation_reverify.md`,
`..._qm5_36004_...`) — the remediation there is a usable template.
