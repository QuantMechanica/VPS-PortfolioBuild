# Joint FTMO Backtest-Only EA — Design (2026-07-27)

Branch `agents/board-advisor`. Author: Claude. One design, decisive.

This specifies a **backtest-only measurement instrument**: a single EA that trades
several gated sleeves on ONE simulated account in ONE strategy-tester run, so the
account equity curve is *real* (not a proxy) and the sleeves' correlation *falls out*
of the run. It is OWNER's idea (2026-07-27): "dann hast du sofort auch immer ihre
Korrelation und sie handeln sofort gemeinsam."

Every load-bearing claim is anchored to `file:line` in the current tree. Where a fact
could not be established from code it is marked **NOT ESTABLISHED**.

---

## 0. Verdict and one-paragraph design

**Feasible.** The tester recon (`docs/ops/evidence/2026-07-27_mt5_multisymbol_tester_recon.md`)
concluded a joint multi-symbol `.DWX` run is not merely possible but *already in
production* (QM5_12781 reached Q05→Q08 as a 2-symbol real-tick basket). So this
document DESIGNS the instrument, it does not design around an infeasibility.

**The instrument.** One new EA, one new `ea_id`, **3 sleeves across 2 symbols**, all on
ONE account:

| slot | sleeve | symbol | strategy | timeframe | role |
|---|---|---|---|---|---|
| 0 | 9936 | USDJPY.DWX (host) | GMT+3 range breakout | H1 | lead |
| 1 | 13213 | USDJPY.DWX (host) | GMT+3 range breakout (Balke window) | H1 | same-edge probe |
| 2 | 10848 | XAUUSD.DWX (non-host) | MTF matrix ambush pullback | H1 | cross-asset diversifier |

`host_symbol = USDJPY.DWX`. Each sleeve's *exact* gated entry logic is compiled into a
shared, symbol/magic/param-parameterised signal module that the joint EA and the
original single-symbol EA both build from; fidelity is **verified by singleton replay**
(joint EA with one sleeve active must reproduce that sleeve's standalone Q08 stream
trade-for-trade), not asserted. Sizing is native `RISK_FIXED=1000` per sleeve (exactly
what was gated); the per-sleeve leverage the single-account study found optimal
(9936≈3x, 13213≈2x, 10848≈4x) is applied in **post-analysis**, exact under `RISK_FIXED`
linearity. The FTMO limits are **recorded, not enforced**: the EA emits a real per-bar +
every-new-intraday-low equity stream with a per-sleeve floating-P&L breakdown, from
which the −5% daily / −10% total / +10% / +5% predicates are computed with full fidelity
in post-analysis, at any leverage vector, without re-running. `prop_phase=OFF`,
stress=0, no live/demo path, name carries `backtest-only`.

This closes all three gaps the task cites: the **equity gap**
(`a5768d03_equity_export_gap_2026-07-27.md` — no more inventing intratrade equity), the
**intraday-interleaving** infidelity
(`2026-07-27_single_account_adversarial_review.md` §3 — trades now ordered by real tick
time), and **correlation** (measured from co-timed trades on one account).

---

## 1. Which sleeves, and why

Source of the pool: `docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md` §2 (the
15 gate-clean sleeves and their FUND_SCORE / breach / dormancy figures).

**IN — 9936:USDJPY (slot 0, lead).** Pool maximum FUND_SCORE 0.41, best drift
(med60 3.34), 0% multi-day (intraday-flat — clean for every FTMO phase), max inter-trade
gap 27d (< 30, dormancy-safe), 152 trades/yr. It is the single best single-account
candidate in the pool and the one whose 60/30 KPI OWNER was quoted (P(P1≤60d) 61.4%).
Its full source is read (`framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/QM5_9936_ff-range-breakout-gmt3-h1.mq5`).

**IN — 13213:USDJPY (slot 1, same-edge probe).** Also intraday-flat (0% multi-day),
gap 26d (safe), FUND_SCORE 0.19. Its source
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5`)
is **the same algorithm as 9936** — line-for-line identical Strategy_* functions,
differing only in three hour parameters (9936 range 01–06 GMT+3, cancel 13, close 20;
13213 range 03–06, single evening flat 18). The sleeve brief's own caveat is that
9936/13213 are "probably one edge, not two" (§2, §3, §5). Putting both on the account
does two useful things at once: it lets the joint run **measure** the 9936↔13213
correlation directly (settling the one-edge hypothesis with evidence instead of
inference), and it is the lowest-fidelity-risk second sleeve available (one shared
range-breakout module, two parameter sets).

**IN — 10848:XAUUSD (slot 2, cross-asset diversifier).** This is the sleeve that makes
the exercise worth the ~2 h / ~44 GB. Correlation "falling out of the run" is only
informative between *different* return streams; two USDJPY range-breakouts firing at the
same GMT+3 hour are near-collinear by construction and, alone, would make the "joint EA"
a single-symbol run that never exercises the multi-symbol machinery. XAUUSD is the only
other symbol with (a) full tick coverage over the window
(`2026-07-27_mt5_multisymbol_tester_recon.md` §2: XAUUSD.DWX head 2017-10-02, tail
2026-04-06, full) and (b) drift-carrying gate-clean sleeves. Of the two XAUUSD sleeves,
**10848 is chosen over 10553**: higher FUND_SCORE (0.17 vs 0.13), lower multi-day
exposure (40% vs 45%), and it is H1 like the USDJPY sleeves (one signal timeframe fewer
to manage). Its source is a genuinely different, stateful strategy (MTF SMA 5/8/13
matrix, ambush-pullback, ATR-frac entry, D-level target; head read at
`framework/EAs/QM5_10848_tv-mtf-ambush/QM5_10848_tv-mtf-ambush.mq5:80-95`) — it is the
heaviest extraction, and its inclusion is the point: it delivers the one thing the
USDJPY pair cannot, the realised USDJPY↔XAUUSD correlation.

**OUT — 13301:GDAXI (dormancy-disqualified).** FUND_SCORE 0.36 (2nd best) and the
cleanest risk shape in the pool, but **maxgap 36d > 30 → dq30**, disqualified on the
30-day dormancy clause OWNER has fixed (`sleeve_improvement_targets.md` §2 row 2, §5.3).
It is also short ~9 months of window (GDAXI.DWX tick history starts 2018-07, recon §2)
and is the symbol worst-hit by the shared-`bases` junction history-lock storm (recon §6.4:
GDAXI measured 126 INFRA vs 58 PASS). Three independent reasons to keep it out; the
dormancy DQ is the binding one.

**OUT — 10553:XAUUSD (redundant second gold sleeve).** A second XAUUSD sleeve would be
near-collinear with 10848 (same symbol, same asset), adding fidelity-verification burden
(a fourth, RSIOMA-family, module) for little new correlation information beyond what
{9936, 13213, 10848} already give. It is a trivial extension of this architecture — one
more module, the same two symbols, the same tester cost — if OWNER later wants to
reconstruct the exact four-stream campaign that `a5768d03` named. Deferred, not designed
out.

**Why 3/2 and not more.** Tester cost is set by the number of *symbols* (their tick
stores), not the number of *sleeves* (recon §4: the working set is dominated by the
XAUUSD 1.9 GB / USDJPY 0.96 GB tick stores). Two symbols is the recon's "cheapest and
best-proven" configuration (~20–44 GB, ~1.5–3 h on a quiet fleet, T9/T10). Adding a
third sleeve on an already-loaded symbol is nearly free; adding a third *symbol* is not,
and buys no goal the two chosen symbols miss.

---

## 2. Architecture — reuse the shipped basket machinery, one execution path

The recon inventory (`2026-07-27_multisymbol_machinery_recon.md` §1–§3) established the
pattern to reuse. The closest precedent is **QM5_10024** (fixed-weight multi-leg basket
with hardcoded `.DWX` symbol array and symbol-pinned slots): one EA attaches to ONE host
chart, warms every symbol's history, and opens each leg via `QM_BasketOpenPosition`.

- **Host chart:** USDJPY.DWX H1. `_Symbol` inside the EA equals the host; the Q08 trade
  stream and equity stream key on `_Symbol` (`QM_Common.mqh:965-967`).
- **History load (REQUIRED):** in `OnInit`, after `QM_FrameworkInit`, call
  `QM_SymbolGuardInit({USDJPY.DWX, XAUUSD.DWX})` then
  `QM_BasketWarmupHistory({USDJPY.DWX, XAUUSD.DWX}, PERIOD_H1, warmup)`. `SymbolSelect`
  alone does NOT load secondary-symbol history in the tester
  (`QM_SymbolGuard.mqh:100-141`, FW9); omitting the warmup → 0 bars on XAUUSD →
  fast-finish → INVALID (recon §1, §5.4). `QM_SymbolGuardInit` with >1 symbol also flips
  the guard into **basket mode** (`QM_SymbolGuard.mqh:57-65`), which is a hard
  prerequisite for §5's ownership resolution.
- **One open path for every leg.** All three sleeves open through
  `QM_BasketOpenPosition(ea_id, QM_NEWS_OFF, deviation, req, ticket)`
  (`QM_BasketOrder.mqh:106`). It accepts **pending stop orders** — the range breakout's
  core mechanism — because it maps `QM_OrderTypeIsStop(req.type)` to
  `TRADE_ACTION_PENDING` (`QM_BasketOrder.mqh:255`). It resolves the per-leg magic from
  `(ea_id, req.symbol_slot, req.symbol)`, sizes lots via `QM_LotsForRisk(req.symbol, …)`
  when `req.lots<=0`, and sends through the shared `QM_TradeContextSend`. Using it
  uniformly for the host legs too (not only XAUUSD) gives ONE code path and one place for
  the fidelity argument.
- **Management reuses the ticket-based helpers, which are symbol-agnostic.**
  `QM_TM_RemovePendingOrder(ticket, reason)` reads the order's symbol from the ticket
  (`QM_TradeManagement.mqh:329-334`); `QM_TM_MoveSL(ticket, sl, reason)` and
  `QM_TM_ClosePosition(ticket, reason)` operate by ticket (`:368`, `:358`). So the
  cancel-opposite, cancel-at-hour, 2-bar-swing trail, and session-close logic port
  verbatim, filtered per `(symbol, magic)`.

**Why not `QM_TM_OpenPosition` for the host legs?** `QM_EntryRequest` has no `symbol`
field — the QM_Entry path is implicitly `_Symbol`-bound and single-magic. Two USDJPY
sleeves on the host need two magics on one symbol; routing both through
`QM_BasketOpenPosition` with distinct `symbol_slot`s is cleaner than special-casing the
QM_Entry `explicit_magic` overload (`QM_TradeManagement.mqh:276-308`) and keeps the
fidelity argument single-path.

---

## 3. Entry-logic fidelity — THE CRUX, and how it is VERIFIED not asserted

The failure this section exists to prevent: the joint EA's per-sleeve logic silently
drifts from the single-symbol EA that was actually gated, so the run measures a
*different* strategy and proves nothing.

### 3.1 Mechanism — shared, parameterised signal modules; exact parameter binding

Do **not** re-implement any sleeve. Extract each gated EA's `Strategy_*` hooks into a
per-strategy include that is parameterised by `(symbol, timeframe, magic, params
struct)` and takes **no** dependency on `_Symbol` or `QM_FrameworkMagic()`:

- `QM_Sig_RangeBreakout.mqh` — the 9936/13213 algorithm. The two sleeves are the *same
  code* (verified: `QM5_9936….mq5:197-416` vs `QM5_13213….mq5:198-420` are identical
  save for the window-hour inputs), so ONE module hosts both, driven by a params struct
  `{range_start_hr, range_end_hr, cancel_hr, close_hr, atr_period, min/max_range_atr_mult,
  trail_trigger_r, range_scan_bars}`. Slot 0 binds 9936's struct, slot 1 binds 13213's.
- `QM_Sig_MtfAmbush.mqh` — the 10848 algorithm (SMA 5/8/13 matrix, ambush-pullback,
  stateful trailing via its `g_trail_ticket`/`g_highest_seen`, now carried per-sleeve
  state, not globals). Params struct binds 10848's inputs.

Each module exposes: `Refresh(state&)`, `WantsEntry(state&, out req[])`,
`Manage(state&)`, `WantsExit(state&)` — the same five-hook shape the skeleton already
uses, but taking a per-sleeve `state` struct and emitting `QM_BasketOrderRequest`s.

**Exact parameter binding — from the gated set files, not from memory.** The parameter
values are copied *verbatim* from the `_backtest.set` files that produced the gated Q08
streams (env=backtest, `RISK_FIXED=1000`), NOT the `ftmo_*` sets (those are env=demo /
`RISK_PERCENT`, which this instrument must never use):

- 9936 ← `…_USDJPY.DWX_H1_backtest.set`: `strategy_range_start_hour_gmt3=1`,
  `…_end_hour_gmt3=6`, `order_cancel_hour_gmt3=13`, `session_close_hour_gmt3=20`,
  `atr_period=14`, `min/max_range_atr_mult=0.4/2.5`, `trail_trigger_r=1.0`,
  `range_scan_bars=36`.
- 13213 ← `…_USDJPY.DWX_H1_backtest.set`: `strategy_range_start_hour=3`,
  `…_end_hour=6`, `strategy_exit_hour=18` (rest are the EA input defaults, which the set
  omits — identical to 9936's shared defaults).
- 10848 ← `…_XAUUSD.DWX_H1_backtest.set`: bind every `strategy_*` line present (SMA
  5/8/13, atr_period, ambush_atr_frac, initial_stop_pct, emergency_atr_mult,
  safety_trail_pct, target_d_level, doji/morning body ratios).

The joint EA's own set file re-declares these under namespaced prefixes
(`s0_range_start_hr=1`, `s1_range_start_hr=3`, `s2_sma_fast=5`, …) so Q08 sub-gate-8.5's
parameter perturbation (if ever run) still sees named params, and so the binding is
auditable line-by-line against the source sets.

**Re-magicking does not break fidelity.** Each `Strategy_*` filters positions/orders by
"its own magic", whatever that value is; the range-breakout and ambush logic are
invariant to the numeric magic. So compiling the sleeves under the joint `ea_id`'s
magics (§4) changes identity, not behaviour.

### 3.2 The four places the basket path could diverge from the QM_Entry path — and the control

Because the host legs move from `QM_TM_OpenPosition` (QM_Entry) to
`QM_BasketOpenPosition`, four behaviours must be checked, not assumed:

1. **Lot sizing / quantization.** Both paths ultimately call `QM_LotsForRisk(symbol,
   sl_points)`; the basket path then quantizes via `QM_BasketNormalizeLots`
   (`QM_BasketOrder.mqh:80-89`). Under `RISK_FIXED` with no money cap the risk budget is
   identical (§6), so lots should match to the volume step.
2. **News gating.** The single-symbol EA gates news once per tick on `_Symbol` with the
   **two-axis** `QM_NewsAllowsTrade2` (`QM5_9936….mq5:494-495`). `QM_BasketOpenPosition`
   internally calls the **legacy** single-mode `QM_NewsAllowsTrade` (`:126`). To avoid a
   double/￢different gate, each sleeve module runs its OWN two-axis gate for its OWN
   symbol/params *before* generating entries, and passes `QM_NEWS_OFF` into
   `QM_BasketOpenPosition`. USDJPY news serves both USDJPY sleeves; XAUUSD news serves
   the gold sleeve (index/metal currency mapping: `QM_NewsFilter.mqh:317-337`).
3. **Friday close.** `QM_FrameworkHandleFridayClose` acts on the framework magic /
   `_Symbol`. Each sleeve (all three ship `qm_friday_close_enabled=true`, hour 21 broker)
   must reproduce its Friday-close per its own `(symbol, magic)`.
4. **Stop-order fill semantics.** Pending BUY_STOP/SELL_STOP fills are price-crossing
   events, deterministic in Model 4; `type_time=GTC`, `expiration=0` in both paths
   (`QM_BasketOrder.mqh:265-270`). No divergence expected.

### 3.3 Verification protocol — singleton replay, bit-for-bit (the hard gate)

The adversarial review's unreachable blind spot was exactly this: its self-check
validated the refactor on singletons but "none of the genuinely new code"
(`2026-07-27_single_account_adversarial_review.md` §3). We close it by making singleton
replay the **admission gate for each sleeve into the joint run**:

1. Build the joint EA. For each sleeve S, run it **alone** (other sleeves disabled by a
   per-sleeve `enabled` flag), on S's symbol as host, over S's exact gated window and
   `_backtest.set` params, `RISK_FIXED=1000`, stress=0.
2. Compare the joint-EA-singleton Q08 `TRADE_CLOSED` stream to S's **standalone** gated
   Q08 stream, trade-for-trade on `(entry_time, close_time, net, volume)`. Require an
   exact match (net to the cent, volume to the step).
3. A sleeve that does not replay bit-for-bit is **not admitted** — its module is fixed
   until it does. Only after all three replay clean is the 3-sleeve joint run
   authoritative.

This is evidence (two CSV/JSONL streams + a diff), not inspection, and it catches any of
§3.2's four divergences by construction. It is the single most important control in this
design.

---

## 4. Magic numbers and per-symbol state isolation

**New `ea_id`.** Reserve the next free row in `framework/registry/ea_id_registry.csv`.
At time of writing the max active id is 20179, so the presumptive next is **20180** —
confirm free with `grep "^20180," framework/registry/ea_id_registry.csv` before
reserving (duplicate-dispatch discipline, memory `duplicate_build_dispatch`).

**Slot registration** (magic = `ea_id*10000 + slot`, `QM_MagicResolver.mqh:24-73`), three
rows in `framework/registry/magic_numbers.csv`, one per leg:

```
20180,ftmo-joint-sim-backtest-only,0,USDJPY.DWX,201800000
20180,ftmo-joint-sim-backtest-only,1,USDJPY.DWX,201800001
20180,ftmo-joint-sim-backtest-only,2,XAUUSD.DWX,201800002
```

- Two slots (0,1) sharing USDJPY.DWX is legal: the runtime check keys on `(ea_id, slot)`
  and the collision guard only rejects the SAME magic on a DIFFERENT symbol
  (`QM_MagicResolver.mqh:99-143`) — slot-0 and slot-1 carry different magics, so two
  concurrent USDJPY positions never collide.
- **Both symbols verified in `framework/registry/dwx_symbol_matrix.csv`** (USDJPY.DWX row
  33, XAUUSD.DWX row 36, `canonical_name_verified=true`). The `FAIL_tail_mid_bars`
  verdicts are tick-value / tail-timestamp verification concerns, **not** tester
  usability (recon §2; both symbols demonstrably backtest — 9936:USDJPY PASSed this
  morning, 1567:XAUUSD is on Q07). Tradability is checked against the matrix, never
  notes (memory `reference_dwx_sp500_unavailable`).
- **Order of operations:** dirs → CSV rows → `python framework/scripts/update_magic_resolver.py`
  (never hand-edit the generated `.mqh`) → verify → compile; run **serially**
  (magic-resolver race, memory 06-30). `codex_build_ea.md:495-516`.

**Per-symbol / per-sleeve state isolation.** Each sleeve carries its own `state` struct
(range hi/lo, day keys, skip keys for the breakout sleeves; trail ticket + highest-seen
for the ambush sleeve). No globals shared across sleeves. Every management loop filters
by the sleeve's `(symbol, magic)`; the duplicate-entry guard
`QM_BasketHasOpenPosition(magic, symbol)` (`QM_BasketOrder.mqh:51-65`) is already
per-`(magic,symbol)`, so sleeve-1's trail can never touch sleeve-0's USDJPY position even
though they share the symbol.

**`symbol_slot` hazard — explicit, every leg.** `QM_BasketOrderRequest` has **no**
default constructor (`QM_BasketOrder.mqh:14-25`); MQL5 does not zero local structs, so an
unset `req.symbol_slot` sends stack garbage into the magic resolver → wrong magic or
`QM_BASKET_REJECTED_BROKER/magic_resolution_failed` (recon §3.6, §5.3; memory
`news_filter_index_defect`). Every sleeve module sets `req.symbol_slot` explicitly for
every request (as all shipped basket EAs do). The joint EA additionally `ZeroMemory`s
each request struct at allocation as belt-and-braces.

---

## 5. Ownership / stream capture — the one hard prerequisite

The Q08 `TRADE_CLOSED` stream is rebuilt deterministically from deal history at shutdown
(`QM_Common.mqh:880-946`), decides ownership on the **opening** deal via
`QM_FrameworkOwnsMagicSymbol(opening_magic, symbol)` (`:902`), and writes one host-keyed
file `Common\Files\QM\q08_trades\20180_USDJPY_DWX.jsonl` with **every** line tagged by
its per-sleeve `magic` and `symbol` (`:941`, `:965-967`).

`QM_FrameworkOwnsMagicSymbol` returns true for a non-host magic **only in basket mode**
(`QM_Common.mqh:400-432`, recon §3.3): magic in `[ea_id*10000, ea_id*10000+SLOT_MAX]`,
slot registered, symbol in the guard's allowed set — and the allowed set is >1 only if
`QM_SymbolGuardInit({…two symbols…})` was called (§2). **If basket mode is not enabled,
the XAUUSD sleeve's trades are silently dropped from the stream** (the documented
`trades=0`/host-mismatch class, recon §2.3, §5.2). This is the single prerequisite the
build must not miss; the singleton replay of the XAUUSD sleeve (§3.3) catches it (its
stream would be empty).

**Consequence for deliverables #3 and #7:** per-sleeve realised P&L and the realised
correlation matrix (9936↔13213, 9936↔10848, 13213↔10848) are computed directly from this
one host-keyed stream — grouped by `magic`, ordered by `time` — with **no new code**. The
interleaving is real: trades appear in true close-time order on one account.

---

## 6. Risk sizing — native 1x `RISK_FIXED`, leverage in post-analysis

**Backtest = `RISK_FIXED`** (hard constraint; live is `RISK_PERCENT`, which this
instrument never carries). Each sleeve runs at its gated `RISK_FIXED=1000`.

**How the per-sleeve 3x/2x/4x is represented.** The single-account study's optimal
leverages (9936≈3x, 13213≈2x, 10848≈4x; `sleeve_improvement_targets.md` §2) were a
*Python post-hoc multiplier* on native-1x Q08 streams — never a gated parameter. Under
`RISK_FIXED` this is exact, not an approximation, because:

- `RISK_FIXED` sizes each trade off a **frozen money budget**, independent of equity and
  of other sleeves (`QM_RiskSizer.mqh:34-36,97-110,152-167`: "FIXED mode keeps the frozen
  money cap"). Per-trade lots depend only on that sleeve's own SL distance and its
  `RISK_FIXED`.
- Therefore a sleeve's dollar P&L is **linear** in its `RISK_FIXED`, and the joint
  balance path at any leverage vector `k=(k0,k1,k2)` is
  `balance_k(t) = 100000 + Σ_{closed before t} k_{sleeve} · net_1x` — reconstructable from
  the per-sleeve-tagged 1x trade stream (§5).

**The framework's 1% cap does NOT bite `RISK_FIXED`.** The `qm_risk_cap_pct` /
`QM_FrameworkSetRiskCapPct` ceiling is the **PERCENT-mode** rail (`cap = equity·pct/100`,
`QM_RiskSizer.mqh:86-87`); FIXED mode uses the frozen money cap, default 0 = uncapped
(`:108-110,163-167`). This is precisely why `RISK_PERCENT=4/8` was fiction in the demo
sets (memory: 1%-cap `QM_Common:182`) but `RISK_FIXED` scaling is real. The OWNER-ratified
5.0 ceiling (`QM_Common.mqh:315`) is untouched and irrelevant here.

**Decision: run at native 1x, leverage in post-analysis.** One 1x run reproduces the
exact equity path at *any* leverage vector, and lets the vector be **re-optimised against
the true joint intraday path** — strictly more informative than baking one vector into a
2 h run. To make the *intraday* path (not just the balance path) re-leverageable, the
equity sampler emits a **per-sleeve floating-P&L breakdown** at each sample (§7): then
`equity_k(t) = balance_k(t) + Σ_s k_s · floating_s_1x(t)`, exact.

**Caveat (disclosed):** re-leveraging is exact only up to lot **quantization** —
`k·lots_1x` need not equal `quantize(k·budget/…)` at the volume step (0.01 for these
symbols; error is sub-percent per trade). For a *bit-exact* as-deployed path at one
chosen vector, bake `RISK_FIXED=k·1000` per sleeve and re-run; that is a confirmatory
option, not the primary. `prop_phase=OFF` for both (§7 explains why).

---

## 7. The equity export — primary deliverable

The existing emitter is insufficient by design: `QM_EquityStreamOnNewBar`
(`QM_EquityStream.mqh:237-286`) emits ONE `EQUITY_SNAPSHOT` per **day**, at that day's
**close**, scope "account". It captures neither intraday equity nor the intraday
**low** — and the FTMO −5% daily limit is a predicate on the intraday equity *minimum*.
That is exactly the gap `a5768d03_equity_export_gap_2026-07-27.md` flagged
("TRADE_CLOSED streams … cannot … without inventing intratrade equity").

**New bounded tester-only sampler** (`QM_JointEquitySampler.mqh`, local to this
instrument), mirroring the Q08 stream's file conventions exactly
(`QM_Common.mqh:952-979`: `FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON)`,
persistent handle truncated once at first write, buffered append flushed at ~32 KB and on
shutdown). Path (host-keyed, one account = one file):

```
Common\Files\QM\q08_equity\20180_USDJPY_DWX.jsonl
```

This **consciously supersedes** a5768d03's proposed `q08_equity/<bare>_<SYMBOL>_DWX.jsonl`:
that naming assumed four *separate* single-symbol runs; the joint run produces ONE
account stream, so a single host-keyed file (matching the `q08_trades` convention) is
correct. Two deterministic row types (`QM_LogEvent`-style JSON objects, one per line,
all money `%.2f`):

- **`EQUITY_BAR`** — emitted once per host H1 closed bar (gate on `QM_IsNewBar()` of the
  host, which the EA already computes):
  `{"event":"EQUITY_BAR","t_utc":<epoch>,"t_broker":<epoch>,"day_key":<yyyymmdd>,`
  `"equity":E,"balance":B,"fl_total":F,"fl":[{"magic":201800000,"f":..},`
  `{"magic":201800001,"f":..},{"magic":201800002,"f":..}]}`
- **`EQUITY_LOW`** — emitted on every **new intraday low** of account equity. Track a
  running per-broker-day minimum; on any tick whose `ACCOUNT_EQUITY` is below it, emit an
  `EQUITY_LOW` row (same schema) and update the min; reset the min at broker-day rollover.

`equity`, `balance` from `AccountInfoDouble(ACCOUNT_EQUITY/ACCOUNT_BALANCE)`; the
per-sleeve `f` from summing floating P&L of open positions grouped by magic
(`PositionGetDouble(POSITION_PROFIT)+SWAP`), which is what makes §6's intraday
re-leveraging exact.

**Determinism / bound.** Model 4's tick sequence is deterministic, so both row types are
reproducible run-to-run. Volume: ~50k `EQUITY_BAR` rows over 9 yr of host H1 (~one file
MB-scale); `EQUITY_LOW` rows are a handful per day. Cheap, per the a5768d03 spec ("at
minimum an equity sample per bar plus every new intraday low").

**What post-analysis does with it (deliverable #4).** The FTMO predicates become exact
reads over `EQUITY_LOW`/`EQUITY_BAR` + the trade stream, at any leverage vector `k`:

- **−5% daily:** for each broker day, `min_t equity_k(t)` (from `EQUITY_LOW`, re-levered
  via §6) vs that day's start equity → breach if ≤ −5%.
- **−10% total:** running `min equity_k(t)` vs the 100 000 anchor → breach if ≤ −10%.
- **+10% / +5% first-passage:** first `t` with `equity_k(t) ≥ 110 000`, then within 30
  days ≥ +5% on the phase-2 anchor.
- **Flatten-at-target** (the PropFirm +28.8pp lever, `QM_PropFirm.mqh:16-28`) can be
  *replayed* over the intraday equity series without a re-run, on/off, to bound its
  effect.

### Why RECORD, not ENFORCE

The EA emits and does **not** act on the limits (`prop_phase=OFF`). Enforcing
(flatten-at-target, daily halt) would **truncate** the very equity path we are paying 2 h
to observe: you could not then measure the true breach distribution, the post-target
path, or re-score under a different policy. Recording is strictly more informative — one
run supports every policy question in post-analysis (flatten on/off, any daily-halt
threshold, any leverage vector), and the in-EA PropFirm enforcement is a **live**-time
tool (its equity-trip/balance-latch semantics, `QM_PropFirm.mqh:540-601`, are designed
for a live account that MUST act). The confirmatory as-deployed run with `prop_phase=1`
enforcement remains available if OWNER wants to see the instrument behave as it would
live.

---

## 8. Hazards specific to THIS instrument

1. **Q06 stress is invalid for it — so it must never run under stress.** The per-basket
   stress-reject memo assumes every leg of a logical entry opens inside ONE `OnTick`
   (`QM_BasketOrder.mqh:178-210`). This instrument's sleeves fire on **different**
   triggers/bars (both breakouts at 06:00 GMT+3, the ambush on its own MTF signal), so
   they do NOT share a tick — the memo would mis-account a stress draw. This is a
   non-issue **because the instrument only ever runs at stress=0** (Q08/Q10-style
   measurement): the whole stress block is skipped when `g_qm_entry_stress_reject_prob==0`
   (`:211`). It is a measurement instrument, not a Q06/Q07 gate candidate; it must not be
   enqueued for stress phases.
2. **Basket-mode ownership prerequisite** (§5) — the one build step that, if missed,
   silently drops the XAUUSD stream. Caught by singleton replay.
3. **History warmup prerequisite** (§2) — missing → INVALID fast-finish. Caught by
   singleton replay (the sleeve would make no trades).
4. **RAM / serialize.** 2-symbol real-tick working set 20–44 GB, ~1.5–3 h (recon §4). The
   EA MUST carry basket payload markers and be registered so the worker RAM-guards and
   **serializes** it (`terminal_worker.py:504-527`; `multisymbol_eas.txt`; recon §5.1):
   ship `basket_manifest.json` (`host_symbol`, `host_timeframe`, `basket_symbols`,
   `logical_symbol`, `portfolio_scope:"basket"`) and register in `multisymbol_eas.txt`.
   Run only on a **free** terminal (T9/T10) in a quiet fleet window — never T5 (dead
   engine), never T_Live. Nothing is launched by this document.
5. **Cost model — no invented commission.** `.DWX` history is spread-inclusive; only
   commission is injected, from `tools/strategy_farm/venue_cost_model.json`, via the
   tester groups file (same as any single-symbol run). The EA invents nothing.
6. **Friday-close and news per-sleeve** (§3.2 items 2–3) — reproduced per `(symbol,
   magic)`; caught by singleton replay.

---

## 9. What this run CAN and CANNOT prove

**CAN:**

- Produce the **true** single-account equity path (per-bar + every intraday low, with a
  per-sleeve floating breakdown) for the 3-sleeve book — closing the a5768d03 equity gap
  with **no invented intratrade equity**. −5% daily / −10% total / +10% / +5% become
  direct reads at any leverage vector.
- Order trades by **real tick time** on one account — removing the date-only
  cross-sleeve interleaving infidelity the adversarial review §3 could not otherwise
  reach.
- Yield the **realised** correlation matrix (9936↔13213 intra-edge; USDJPY↔XAUUSD
  cross-asset) from co-timed trades — settling the "9936/13213 are one edge" hypothesis
  with measurement, and giving OWNER the cross-asset number directly.
- Test whether diversification (2nd USDJPY + XAUUSD) **smooths** the equity path enough
  to lift effective first-passage vs the lone 9936 sleeve.

**CANNOT:**

- **Re-gate or re-derive the sleeves' edge.** Fidelity is only as strong as the singleton
  replay (§3.3); a sleeve that fails replay is not admitted. The run measures the *gated*
  sleeves interacting, nothing more.
- **Improve the statistical sample.** It is ONE historical path (2017-10→2025-12). The
  first-passage probability over overlapping starts still carries the ESS/CI limits the
  adversarial review §5 quantified (central ~36% for 9936@3x, 95% band ≈ [5%, 60%], ~44%
  blow-up). A sharper equity *measurement* does not enlarge the *sample*.
- **Speak to FTMO Funded weekend compliance for the XAUUSD sleeve.** 10848 is 40%
  multi-day; a Standard **Funded** account's weekend-close rule would bite it
  (`QM_PropFirm.mqh:304-312`, review M1). This instrument targets the **Challenge/
  Verification (P1/P2)** 60/30 KPI, where multi-day holds are permitted (and pessimistically
  charged); Funded-phase weekend legality is a separate question it does not answer.
- **Deliver a bit-exact as-deployed path at a specific leverage** without a baked re-run
  (§6 quantization caveat).
- **Serve Q06/Q07** — by construction (§8.1).

---

## 10. Build, naming, backtest-only guarantees

- **`ea_id`** 20180 (confirm free), **slug** `ftmo-joint-sim-backtest-only`, logical
  symbol e.g. `QM5_20180_FTMO_JOINT_SIM_BACKTEST_ONLY_H1`. The name carries
  `backtest-only` so it is unmistakable in the registry, logs, dashboards and file
  streams.
- **No live path, ever.** `RISK_FIXED` only; `RISK_PERCENT=0`; `prop_phase=OFF`;
  `env=backtest` set file only. Ship **no** `ftmo_*`/`_live`/demo set; never run
  `gen_setfile -Env demo` for it (memory `ftmo_multi_account_campaign`). It carries no
  deploy manifest and is excluded from any T_Live path.
- **Order of operations:** reserve `ea_id` row → add 3 `magic_numbers.csv` rows → regen
  `QM_MagicResolver.mqh` (`update_magic_resolver.py`) → verify → create EA dir + includes
  + `basket_manifest.json` → register in `multisymbol_eas.txt` → compile → **singleton
  replay each sleeve (§3.3)** → only then the 3-sleeve joint run on a free terminal.
- Commit hand-authored source promptly under a semantic label with explicit pathspecs
  (never `-a`); do not let the build pump sweep it into an auto-commit.

---

## 11. Status / evidence / risks / next step

- **Status:** design complete and decisive. Feasibility confirmed from recon (not
  designed around an infeasibility). Sleeve set fixed at {9936, 13213 : USDJPY.DWX} +
  {10848 : XAUUSD.DWX}, host USDJPY.DWX.
- **Evidence (read for this design):**
  `docs/ops/evidence/2026-07-27_multisymbol_machinery_recon.md`,
  `…_mt5_multisymbol_tester_recon.md`, `…_sleeve_improvement_targets.md`,
  `…_single_account_adversarial_review.md`, `a5768d03_equity_export_gap_2026-07-27.md`;
  `framework/include/QM/QM_BasketOrder.mqh`, `QM_PropFirm.mqh`, `QM_EquityStream.mqh`,
  `QM_RiskSizer.mqh` (grep), `QM_Common.mqh:315,400-432,875-979`,
  `QM_TradeManagement.mqh:276-374`, `QM_Logger.mqh:86-120`, `QM_SymbolGuard.mqh:57-141`;
  the 9936 and 13213 `.mq5` in full and 10848 head; the `_backtest.set` and `ftmo_*.set`
  of 9936/13213; `framework/registry/dwx_symbol_matrix.csv:33,36`,
  `ea_id_registry.csv` (max 20179).
- **Risks / caveats:** (a) fidelity rests entirely on singleton replay passing — if a
  sleeve will not replay, it is out, not fudged; (b) basket-mode ownership + history
  warmup are silent-failure prerequisites, mitigated by the replay gate; (c) 10848 is the
  heaviest extraction (stateful, different family) and the likeliest to need iteration;
  (d) post-hoc re-leveraging is exact only to lot quantization; (e) the run is one path —
  it sharpens the equity measurement, not the sample size.
- **Recommended next step:** route the build to Codex (Builder≠Approver) in this order —
  reserve id/magics + regen resolver; extract `QM_Sig_RangeBreakout.mqh` and re-point
  9936/13213 at it to prove the shared module reproduces both standalone (a pre-check on
  the same replay principle); then the joint EA + `QM_JointEquitySampler.mqh` +
  manifest; then singleton-replay all three; then one 3-sleeve ad-hoc run on T9/T10 in a
  quiet window. Report the equity stream, the trade stream, and the realised correlation
  matrix back for the post-analysis that re-measures the campaign at the chosen leverage
  vector.
