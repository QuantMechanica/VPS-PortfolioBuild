# Claude review: QM5_37001 Gemini build

- Review task: `44c27df5-5676-4697-89d2-e17c399a0d4f`
- Gemini source task: `92c3eb98-4998-40dc-b31a-8b2da987365e`
- Source artifact: `D:/QM/strategy_farm/artifacts/build_results/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb_build_result.json`
- Reviewed source: `framework/EAs/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb.mq5`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb.md`
- **Verdict: CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff.**

Per hard rule (Gemini-originated code requires mandatory Codex review before acceptance),
this task stays in REVIEW; Claude does not self-approve or advance gemini-originated
builds to PIPELINE.

Stat-arb EAs carry two failure modes not present in the NNFX-family reviews done earlier
today: a generic-indicator substitute for the actual OU math, and look-ahead bias in the
regression window. Both were checked explicitly and are clean.

## Headline checks (clean)

- **OU math is genuinely implemented, not substituted.** OLS `Δx = a + b*x_{t-1}`,
  `θ = -ln(1+b)`, `HalfLife = ln(2)/θ`, `μ = -a/b`, `Z = (x-μ)/σ`, with the mean-reversion
  guard `b<0 && 1+b>0`. Entry (±2.0 z), TP (0.15), SL (3.5), half-life bounds ([5,40])
  match the card exactly.
- **No look-ahead bias.** `CopyRates` starts at shift 1 (last closed bar), `ArraySetAsSeries`
  true, z-score uses the closed bar, regression window is all-closed-bars, entry gated by
  `QM_IsNewBar()`.
- **No ML.** Pure OLS + arithmetic; no trained model, external param file, or ML library —
  compliant with the hard "no ML in V5 EAs" rule.
- Unwired inputs: all 12 `strategy_*` inputs are read.
- Setfiles/guardrails: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `qm_news_stale_max_hours=336`.
- Rollover blackout correctly uses `TimeGMT()`, 23:55-00:05 GMT window (card-exact).
- Max-open-1 enforced; ATR safety stop wired.

## Findings

### 1. Medium: time-stop uses a fixed constant instead of the trade's actual half-life

Card §3.4 specifies the time-stop as `2.5 x τ` where τ is the fitted half-life at entry.
Line 274 instead uses the constant `strategy_max_half_life` (40) directly, giving every
trade a fixed ~100-bar hold regardless of its actual fitted half-life. Entry τ is never
persisted per-position, so the per-trade time-stop the model specifies cannot be honored as
written.

### 2. Medium: capital-preservation contract not wired to card values

Card §3.1.3's daily-loss no-trade filter (>=2.0%) is not implemented in
`Strategy_NoTradeFilter` (only rollover + spread checked). Card §4.2's caps (2.5% daily DD,
5.0% total DD) are not wired; `QM_FrameworkInit` uses the generic
`QM_KillSwitchInit(...,3.0,0.0,1.0)` default (daily 3.0%, portfolio DD disabled). This is the
same recurring gap found in every NNFX-family EA reviewed today (QM5_36001, QM5_36004,
QM5_36008) — appears to be a systemic build-lane omission, not EA-specific.

### 3. Medium: input series is a raw price level, not the card's stated cointegrated spread

The card frames this as trading a cointegrated-pair spread ("BUY Spread Package"), but the
code runs the OU/OLS fit on a single instrument's raw close price (non-stationary FX level),
not a constructed stationary spread between two instruments. The OU *math* is faithful to
the formula; the *input series* it's applied to is not what the card describes. This does not
violate the "Verbund-EA = NUR Backtest; live = 1 EA/Symbol" convention (single-symbol is
fine for live), but the mean-reversion premise on a raw price level is weaker than the card's
narrative claims — Q02 economics will be the actual test of whether this matters, but it is
worth flagging as a design/thesis gap for OWNER rather than treating as pure implementation
noise.

### 4. Low: no-trade filter can gate exits during rollover/spread spikes

`Strategy_NoTradeFilter()` runs before `Strategy_ExitSignal()`; during the rollover blackout
or a spread spike, an open position cannot exit — traps risk in exactly the volatile windows
that should trigger protective exits, not suspend them.

## Disposition

Return to the build lane for remediation: (1) persist entry τ per-position and use it for the
`2.5 x τ` time-stop per card §3.4, (2) wire `QM_KillSwitchInit` and the 2.0% daily entry halt
to card §4.2 numbers (same fix already applied to the sibling NNFX EAs today), (3) reorder
`OnTick` so exits run before the no-trade gate. Finding #3 (raw-price vs cointegrated-spread
input) is a design note for OWNER, not a blocking code defect — flag it in the card/build
discussion rather than silently reworking the EA's instrument scope.
