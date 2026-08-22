# Codex review: QM5_1425 Gemini build

- Review task: `c5811f96-bf23-490f-a8e5-2887606d16a7`
- Gemini source task: `77bb60df-1c46-46db-b0d5-3560e2949375`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/77bb60df-1c46-46db-b0d5-3560e2949375.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md`
- Reviewed tree HEAD: `27c80e525a924aeca56e5d7c136a3228d99284e6`
- Source build commit: `09f175aefd1dd11f0af0ac66dd14923a6b0f1528`
- MQ5 SHA-256: `263e03e45c3b6fe16398919bfb51421f23462ef2e1737c1eca8c6571a434af14`
- Existing EX5 SHA-256: `7cae1f96a30910f832df2d726e89205d714f26edd1b1eaaf0cf9b8a3e60fc51d`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, framework contracts, and focused checks
directly.

## Findings

### 1. Critical: reversed pivot ordering makes the entry search deterministically zero-trade

`Strategy_FindFractals` appends pivots while shifts descend from old to new
(source line 223). The resulting arrays therefore have larger/older shifts
first. Entry lines 308-329 assert the opposite ordering, treat the first item
as newest T3, and reject every later candidate when `s_t2 <= s_t3`. Because
every later appended pivot has a smaller shift, the inner body cannot reach
the spacing or pattern gates for any price history. This implementation cannot
emit an entry.

### 2. Critical: the mandatory trough-significance gate is absent

Card lines 57-62 require each trough to be at least `0.5*ATR` below its
surrounding 20-bar low. `strategy_trough_depth_atr` is declared at source line
46 but never read. The source accepts ordinary one-wing Williams fractals
without the 20-bar significance test, so even after the zero-trade ordering
bug is fixed the recognized structure would not match the approved card.

### 3. High: Gate 3 does not enforce exactly one intervening peak

The card requires exactly one significant pivot high between T1/T2 and exactly
one between T2/T3 (card lines 68-74). Source lines 342-373 accept any number of
high pivots and merely select the highest in each interval. Multi-peak
structures unauthorized by the card can pass.

### 4. Critical: the approved 12-bar BUY-STOP is replaced by a post-breakout market entry

The card requires a BUY-STOP at `neckline + 0.4*ATR`, valid for 12 H4 bars with
invalidation on a new low (card lines 90-94). Source lines 426-460 wait for a
closed-bar cross and create `QM_BUY` at the current ask. They set neither
`QM_BUY_STOP` nor `expiration_seconds`; the recency test at lines 315-317 also
adds an unexplained 20 bars to the configured 12. Entry price, order lifetime,
and invalidation semantics all differ from the approved strategy.

### 5. Critical: the D1 SMA macro-bias direction is inverted

Source lines 181-187 call `CopyBuffer(..., start_pos=1, count=2, sma_vals)` and
assume element zero is the newer SMA. MetaQuotes documents oldest-first
physical storage, so element zero is shift 2 and element one is shift 1. The
test `sma_vals[0] >= sma_vals[1]` accepts a flat/falling D1 SMA and rejects a
rising one, contrary to card lines 122-125.

Reference: https://www.mql5.com/en/docs/series/copybuffer

### 6. High: the mandatory card news window is shortened from 480 to 30 minutes

The card requires no entry within plus/minus two H4 bars of high-impact news
(card line 118), i.e. 480 minutes on each side. Source lines 25 and 543-548 use
`QM_NEWS_TEMPORAL_PRE30_POST30` and pass `30, 30`. The framework maps that mode
to 30 minutes before and after, so the configured blackout is materially
shorter than the approved contract.

### 7. High: order rejection consumes 40 bars of state, and restart loses exit state

Source lines 453-458 mark the setup active and start the 40-bar reuse lock
before `QM_TM_OpenPosition` is called; lines 599-602 ignore its result. A
rejected order therefore consumes the pattern without an execution. In the
opposite direction, all active setup fields are process-local defaults: after
an EA/terminal restart, `g_active_setup_valid=false`, so partial TP and the
first-eight-bars failure exit are disabled for an already-open position.

### 8. High: the runtime execution contract is undeclared

`OnInit` (source lines 543-554) calls `QM_FrameworkInit` but never calls
`QM_FrameworkDeclareExecutionContract`. The H4 chart binding and Friday-close
policy therefore lack the current framework's explicit fail-closed runtime
declaration.

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
  `D:/QM/reports/compile/20260822_165620/summary.csv`. The existing EX5 was not
  changed. This is compile-infrastructure evidence, not a pipeline verdict.
- Producer smoke was deferred to governed Q02 dispatch. No backtest, pipeline
  phase, terminal launch, AutoTrading change, or live action was performed.

No Gemini MQ5 source, setfile, registry, resolver, binary, or task outside this
review was changed.
