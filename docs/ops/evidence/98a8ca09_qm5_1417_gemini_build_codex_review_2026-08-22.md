# Codex review: QM5_1417 Gemini build

- Review task: `98a8ca09-c712-4064-866e-cf7112c465d5`
- Gemini source task: `14432f77-9abf-4032-aefc-278a6bdbad34`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/14432f77-9abf-4032-aefc-278a6bdbad34.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1417_classical-pennant-continuation-h1.md`
- Reviewed tree HEAD: `27c80e525a924aeca56e5d7c136a3228d99284e6`
- Source build commit: `09f175aefd1dd11f0af0ac66dd14923a6b0f1528`
- MQ5 SHA-256: `8f01e6c78b44922626a70c79ba96d8479427c0267f9f1cd6e8a92d24fad1fc5c`
- Existing EX5 SHA-256: `a22a278f4526793299851a1f4557bcaa9ee3fceb411c14d26726e68051830ee9`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, framework contracts, and focused checks
directly.

## Findings

### 1. Critical: missing pivot geometry is replaced by fabricated trendlines

The approved Phase-2 gate requires regression through at least two pivot highs
and at least two pivot lows (card lines 80-87). Source lines 455-471 take the
opposite path when either side has fewer than two pivots: they manufacture
`s_up=-0.05*ATR`, `s_lo=+0.05*ATR`, and boundary intercepts from the window
extremes. The calculated `slope_mid` is unused. This allows a pennant to pass
without the mandatory converging-pivot structure and changes the strategy's
defining geometry.

### 2. Critical: the approved pending-stop entry is implemented as a late market entry

The card requires a BUY-STOP or SELL-STOP at the projected boundary plus the
ATR buffer, valid for six H1 bars (card lines 103-110). Source lines 490-561
instead require the previous closed bar to have already crossed the trigger,
then fill a `QM_BUY`/`QM_SELL` request at the current ask/bid. No pending order
type or `expiration_seconds` is set. This changes entry price, gap/slippage
behavior, order lifetime, and stale-pattern cancellation.

### 3. Critical: the H4 SMA macro-bias direction is inverted

Source lines 186-203 call `CopyBuffer(..., start_pos=1, count=2, sma_vals)` and
then treat `sma_vals[0]` as the newer value. MetaQuotes documents that copied
data is physically stored oldest-first regardless of array properties, so
`sma_vals[0]` is shift 2 and `sma_vals[1]` is shift 1. The long test
`sma_vals[0] >= sma_vals[1]` therefore accepts a flat/falling SMA, while the
short test accepts a flat/rising SMA—the reverse of card lines 140-143.

Reference: https://www.mql5.com/en/docs/series/copybuffer

### 4. High: the mandatory card news window is shortened from 180 to 30 minutes

The card requires no entry within plus/minus three H1 bars of high-impact news
(card line 136), i.e. 180 minutes on each side. Source lines 25 and 677-680 use
`QM_NEWS_TEMPORAL_PRE30_POST30` and pass `30, 30`; the framework maps that enum
to 30 minutes before and after. The build has a news blackout, but not the one
OWNER approved for this strategy.

### 5. High: pattern state and the reuse lock are committed before order acceptance

Source lines 518-525 and 552-559 mutate TP/line state and start the ten-bar
reuse lock while only constructing the request. Lines 732-735 ignore the
boolean result from `QM_TM_OpenPosition`. A broker, risk, news, stress, or
contract rejection therefore consumes the setup and suppresses detection for
ten bars even though no trade executed.

### 6. High: the pattern-failure projection does not advance after entry

The fitted line reference is stored as a relative bar shift at entry. Exit
lines 638-641 always reuse `curr_shift=1` with the unchanged reference shift,
so the projected upper/lower line is frozen at the original x-coordinate as
new H1 bars arrive. The first-five-bars failure exit therefore does not test
the advancing converging triangle required by card lines 117-119.

### 7. High: the runtime execution contract is undeclared

`OnInit` (source lines 675-686) calls `QM_FrameworkInit` but never calls
`QM_FrameworkDeclareExecutionContract`. The current framework contract says
that declaration must immediately follow initialization, so the H1 chart
binding and Friday-close policy have no explicit fail-closed runtime check.

## Independent verification

- Producer JSON hashes match the reviewed MQ5 and existing EX5 exactly.
- `validate_build_guardrails.py` at the mandatory 336-hour ceiling: PASS, 15
  files checked, zero findings.
- `build_gate_hardening.py`: PASS, zero failures and warnings.
- `validate_spec_doc.py`: PASS.
- One active EA registry row and 14 active magic rows are present; the symbol
  matrix check passed for all 14 symbols.
- All 14 backtest setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- Focused forbidden scan found no ML imports, martingale logic, blocking
  `Sleep`, or raw `OrderSend`.
- A fresh forced compile was attempted through `compile_ea.py`, but the
  governed include mirror refused while terminal workers were active:
  `INCLUDE_MIRROR_REFUSED`. Summary evidence is
  `D:/QM/reports/compile/20260822_165611/summary.csv`. The existing EX5 was not
  changed. This is compile-infrastructure evidence, not a pipeline verdict.
- Producer smoke was deferred to governed Q02 dispatch. No backtest, pipeline
  phase, terminal launch, AutoTrading change, or live action was performed.

No Gemini MQ5 source, setfile, registry, resolver, binary, or task outside this
review was changed.
