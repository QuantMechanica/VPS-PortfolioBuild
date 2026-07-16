# QM5_20002 ict-icytea-core — Build Brief (Phase 1: Core Model)

Source spec: `MQL5_Strategie_Spezifikation_some_icy_tea.docx` (770 annotated ICT trades,
@some_icy_tea). Reference trades: `Trades_some_icy_tea.xlsx`. Extracted spec text:
`D:\QM\reports\ict_intake\spec.txt`. **Implement EXACTLY as the spec requires** (OWNER
2026-07-16). This brief maps the spec's Core Model (Ch 3) onto the QM V5 4-module pattern.
Phases 2–3 (modules) are separate briefs; the architecture below leaves module hooks in place.

Long side described throughout; **short side is the exact mirror** (spec Ch 3 opener).

## Architecture (spec Ch 5 + Ch 7 mandate: ONE EA, core always on, modules toggleable)

Single EA `QM5_20002_ict-icytea-core`. Core model always active. Setup variants (Judas,
TurtleSoup, Unicorn, SilverBullet, TGIF, 3Drives, MMxM, SMT, IndexMacros, News) are
`input bool Setup_*` toggles — Phase 1 wires the toggles + leaves the module functions
stubbed (return no-op) so per-module set files test cleanly once filled. The factory tests
configurations via SET FILES (core-only, core+each module) — those are the individual
"strategies" the OWNER asked to send through the factory.

## Framework 4-module mapping

| Framework hook | ICT responsibility |
|---|---|
| **No-Trade** (`QM_NoTrade`) | killzone/session time filter (DST-aware), news blackout, Friday close, max-trades-per-KZ counter |
| **Trade Entry** (`Strategy_EntrySignal`) | Core model: sweep → MSS+displacement → PD-array entry (FVG/OB) → premium/discount filter → min-RR check |
| **Trade Management** (`Strategy_ManageOpenPosition`) | partial at PartialAt, then SL→breakeven; runner to final TP |
| **Trade Close** (`Strategy_ExitSignal`) | session-end/day-end flat; hard TP at opposite liquidity is an order TP, not signal |

Use `QM_DSTAware` for NY-time→broker-time killzone conversion (TZ offset input; DST). Use
`QM_MTFCoherence`/`CopyRates` for HTF context. Reuse FVG/OB helpers from
`QM5_10628_et-fvg-sweep-fill` / `QM5_10095_gh-ict-orderblk` where correct, but re-verify
each definition against the spec below — do NOT assume prior EAs match this spec.

## Exact algorithmic definitions (spec Ch 3 + Ch 4)

All on ExecutionTF (default M1). "Pip" = 10 points on a 5-digit FX symbol.

### 1. Swing points (fractals) — spec Ch3 S1
- Swing high at bar i: `High[i] > High[i±1..SwingLookback]`. Swing low mirror. `SwingLookback` default 1–2.
- Maintain rolling arrays of the last N swing highs/lows (price + bar index + time).

### 2. Liquidity levels — spec Ch3 S1
- **EQH/EQL**: ≥2 swing highs (lows) within `EqualTolerance` (default 2 pips OR 0.1×ATR14). Cluster them; the level = their mean. EQL below = SSL (sell-stops); EQH above = BSL.
- **Fixed daily levels**: PrevDayHigh/Low (spec: 116 trades), Asian High/Low (session 20:00–00:00 NY), PrevWeekHigh/Low. Compute via HTF/day boundaries in broker time.
- These are the sweep targets (S2) and TP targets (S6).

### 3. Liquidity sweep (manipulation) — spec Ch3 S2
- Sweep of a low L: a bar makes `Low < L` but `Close > L` (rejection), OR price returns above L within `SweepReturnBars` (default 3) bars. Mirror for highs.
- Record sweep extreme = the lowest low of the sweeping bar(s). This anchors SL.
- Quality upgrade (Phase 2): sweep terminates inside an HTF FVG/OB → stronger. Leave a hook.

### 4. MSS with displacement — spec Ch3 S3
- After a low-sweep: **body-close** break of the last relevant Lower High (last swing high before the swept low). `Close > that_swing_high` (close, not wick).
- **Displacement** (must hold at least one): (a) the breakout impulse creates ≥1 FVG, AND/OR (b) an impulse candle body ≥ `DisplacementATR`(1.5) × ATR14. Require FVG-in-impulse by default (spec: ~700 trades have FVG).
- CISD (Phase 2 alt): close above the open of the last contiguous down-candle series.

### 5. FVG (bullish) — spec Ch4
- 3-candle: `Low[k1_left] ... ` with the newest-to-oldest indexing: bullish FVG when `Low(newer bar) > High(older bar)` across the 3-candle window → gap zone `[High(older); Low(newer)]`. Precisely: bars A(oldest),B,C(newest); bullish FVG = `Low(C) > High(A)`; zone = `[High(A), Low(C)]`.
- Min size `FVG_MinPoints` (default 10 on 5-digit). CE = 50% of the zone.

### 6. Order Block (bullish) — spec Ch4
- Last **down-close** candle immediately before the up displacement impulse. Zone = `[Open, Low]` (conservative param: `[High, Low]`). Mean Threshold MT = 50% of zone.

### 7. Entry zone (PD-array) in the retracement — spec Ch3 S4
- Priority: **+FVG** (default) → **+OB** → (Phase 2: Breaker, Unicorn=Breaker∩FVG).
- `EntryMode`: FVG-edge (default) | FVG-CE | OB-MT.
- Place a **buy limit** at the chosen level (FVG upper edge / CE / OB open / MT).
- **Premium/Discount filter** (`PremiumDiscountFilter` default true): DealingRange = sweep-low → impulse-high. Longs ONLY if the entry zone is **below 50%** (discount) of the range. Shorts mirror. Spec: "FVG below 50% – ignore it" for the wrong side.
- Optional OTE (param, default off): entry in 0.62–0.79 retpurchase (sweet spot 0.705).

### 8. Stop-loss — spec Ch3 S5
- A few points below the **sweep extreme** (manipulation low) minus `SL_BufferPoints` (10–20) + spread. (Alt param: below the entry-zone low.)

### 9. Take-profit & management — spec Ch3 S6
- TP = nearest **opposite external liquidity**: nearest EQH/BSL, session high (London/NY), PDH/PDL, PrevWeekHigh, or open HTF FVG. Pick the nearest un-taken pool beyond entry. **No fixed pip TP.**
- **MinRR** (`MinRR` default 2.0): reject the setup if `(TP-entry)/(entry-SL) < MinRR`.
- **Partial** at `PartialAt` (default 50% of range), close `PartialPct` (50%), then SL→breakeven; runner to final TP.

### 10. No-Trade / timing — spec Ch2.3 + Ch6
- Killzones in **NY time**, converted to broker time via `TZ_Offset` input + DST (`QM_DSTAware`):
  - `KZ_London` 02:00–05:00 NY (default on), `KZ_NewYork` 07:00–10:00 NY (default on).
- `MaxTradesPerKZ` default 2 (per killzone per symbol). Reset each session.
- News blackout `NewsFilterMinutes` ±15 (QM_NewsFilter). Friday close (framework default).
- Trade-duration cap: flat by session-end/day-end (param).

## Inputs (spec Ch 7 — implement all; group under "Strategy")
`ExecutionTF(M1)`, `HTF_Context(M15,H1)`, `SwingLookback(2)`, `EqualTolerance_Pips(2)`,
`EqualTolerance_ATRfrac(0.1)`, `SweepReturnBars(3)`, `DisplacementATR(1.5)`,
`RequireFVGInImpulse(true)`, `FVG_MinPoints(10)`, `EntryMode(FVG_EDGE)`,
`PremiumDiscountFilter(true)`, `UseOTE(false)`, `SL_BufferPoints(15)`, `MinRR(2.0)`,
`PartialPct(50)`, `PartialAt(50)`, `BreakevenAfterPartial(true)`, `MaxTradesPerKZ(2)`,
`TZ_Offset_NYtoBroker`, `KZ_London_on(true)`, `KZ_NewYork_on(true)`,
`Setup_Judas/TurtleSoup/Unicorn/SilverBullet/TGIF/3Drives/MMxM/IndexMacro(false)`,
`UseSMT(false)`. Framework groups (Framework/Risk/News/Friday Close) per V5 convention;
RISK_FIXED=1000 backtest / RISK_PERCENT live; per-idea risk ≤1% (book rule).

## Correctness validation (mandatory before factory)
1. Compile clean (compile_one), 0 errors.
2. **Reference-trade replay**: pick ~10 documented EURUSD M1 NY/London trades from the xlsx
   (with entry/exit prices + concepts), run the EA over those exact dates, confirm it fires
   a same-direction entry near the documented entry within tolerance. Divergences must be
   explained (discretionary HTF-bias choices are acceptable gaps; a wrong sweep/MSS/FVG
   definition is a bug to fix).
3. DST self-check: killzone boundaries land at the correct broker time in a winter AND a
   summer sample week.
4. Only then: build + enqueue Q02 on EURUSD (priority 1), then GBPUSD.

## Honesty guardrails (spec Ch 9)
Screenshots are winners only (survivorship) → no winrate implied; the backtest must produce
the expectancy. Charts are 2020–2023; regime may have shifted. These do NOT change the
implementation — they set expectations for the gate verdicts.
