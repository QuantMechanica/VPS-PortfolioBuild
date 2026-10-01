# Q08 hedged-basket sampling-unit critique (QM5_41112 → informs QM5_41119)

Task `2b03c503-3d8f-4ba8-8c0e-bb67ffd5695d` · critic: Claude (Opus) · 2026-10-02 · read-only.
No patch, no re-grade, no simulation of account risk. **The native QM5_41112 Q08 FAIL_HARD stays as it is**:
8.2 DSR p=0.14449 is EDGE_HARD on its own, so nothing below can change the parent verdict. DSR is out of scope.

## What I inspected

- `framework/scripts/q08_davey/sub_8_9_runs_test.py`: `run` and `_runs_test_p_value` (full)
- `framework/scripts/q08_davey/sub_8_11_mc_shuffle_dd.py`: `run` and `_max_drawdown_abs` (full)
- `framework/scripts/q08_davey/common.py`: `load_trades_from_log`, `trade_net_profits`, `trade_timestamp`
- `framework/scripts/q08_davey/aggregate.py`: `run_all` L1742–1962 and `_apply_worst_case_commission` L1252
- Sealed stream `…\q08_sealed_stream.42f9b94736e8cd23.jsonl` (sha256 `42f9b947…a147`, 106 rows, 45,321 B)

**Ordering and ties.** Nothing sorts the trades. `load_trades_from_log` keeps file order. `run_all` passes the
list through unchanged, and `_apply_worst_case_commission` rewrites `net` but keeps the order. 8.9 drops `net == 0`
rows; none exist here. The sequence the test sees is therefore the EA's emission order. In this stream the XAG leg
always comes before the XAU leg. 48 of 53 pairs close at the same second, and the other 5 within 59 s.

**Reproduction.** I ran `reproduce_readonly.py` with the canonical modules on the sealed stream. It gives 8.9 FAIL
(55 wins, 51 losses, 78 runs, p printed as 0.0, raw 2.53e-6; top-20% share 54.57%) and 8.11 PASS
(realized DD 1315.99, p95 4654.46). Both match the native extract exactly.

## (1) Concern verdicts and scope

| # | Concern | Verdict |
|---|---|---|
| C1 | 8.9 on individual legs of a hedged pair injects alternation mechanically | **SUPPORTED** |
| C2 | The two-sided test rejects *excess alternation*, which contradicts the gate's stated rationale (clustering) | **SUPPORTED** |
| C3 | The 8.9 result depends on arbitrary tie order between legs | **SUPPORTED** |
| C4 | Leg pairing explains 41112's 8.9 FAIL | **SUPPORTED** as a decomposition of the run count; whether a correctly specified test would pass is **NEEDS_MORE_EVIDENCE** |
| C5 | 8.11 leg permutation breaks hedge dependence | **SUPPORTED**. For this negatively coupled pair the error is conservative; for positively coupled baskets it would be optimistic |
| C6 | Neither test measures account daily MTM loss or margin risk | **SUPPORTED**; actual concurrent MTM is **NEEDS_MORE_EVIDENCE** |

**8.9 arithmetic** (n1=55, n2=51). E[R] = 2·55·51/106 + 1 = **53.92**. Var = 5610·5504 / (106²·105) = **26.172**, sd 5.116.
z = (78 − 53.92)/5.116 = **+4.71**. The z is positive: there are *more* runs than chance, which means alternation,
not streaks. The docstring (L13–15) says the test targets win/loss *clustering*. On that stated intent the
upper tail would not reject at all. The two-tailed `p = 2(1−Φ(|z|))` at L67 is what makes this a FAIL.

**Where the 78 runs come from.** R = 1 + 45 + 32:
- Within-pair transitions: 53, of which **45 change sign (84.9%)**. 45 of 53 pairs have opposite-sign legs.
  Swapping legs inside a pair cannot change this count.
- Between-pair transitions: 52, of which 32 change sign (61.5%). The null rate is 2·(55/106)(51/106) = 49.9%.
  A rough binomial z is ≈1.68, which is not significant, and these transitions are not independent either.

The leg-level FAIL is therefore carried by the within-pair hedge structure.

**Tie-order envelope** (exact dynamic program over all 2⁵³ within-pair orderings):

| Ordering | R | p | Result |
|---|---|---|---|
| As emitted (XAG first) | 78 | 2.5e-6 | FAIL |
| Reversed (XAU first) | 76 | 1.6e-5 | FAIL |
| Envelope minimum | 50 | 0.443 | PASS |
| Envelope maximum | 93 | 2e-14 | FAIL |

The minimum ordering is adversarial and data-snooped. It is **not** a legitimate re-grade. Its only purpose is to show
that the statistic is not identified for the leg-level unit.

**Exposed-data diagnostic only, not a verdict.** At cycle level (53 cycles, 30 W / 23 L) there are 30 runs, p = 0.403.
This number was computed after seeing the data. It must not be used to re-label 41112 or to calibrate any gate.

**8.11.** Shuffling individual legs (`run`, L216–222) splits winners from their hedges. Here that inflates the DD
distribution: the leg-level p95 is 4654.46, against 2045.63 for a cycle-block shuffle (diagnostic, same seed).
For a hedged pair this direction is conservative. For a same-direction basket (positive within-cycle covariance),
leg shuffling would *understate* the DD tail. Both tests run on realized closes only.

**MAE gap.** The worst cycle's summed leg MAE is −829.32, against a worst realized cycle of −411.94.
The stream has no MAE timestamps, so the sum is only an upper bound on concurrent floating loss.

## (2) Auditable examples

**8.9 order effect.** Take 10 hedged cycles. Odd cycles have legs (+3, −1); even cycles have legs (+1, −3).
Every pair contains one W leg and one L leg.

- **Winner-first order** gives W L W L … (20 legs). n1 = n2 = 10, R = 20, E = 11.
  Var = 2·100·180/(400·19) = 4.737, z = 9/2.176 = 4.135, **p = 3.5e-5 → FAIL**.
- **Same rows, ordered W L | L W | W L | …** All 10 within-pair changes remain. All 9 between-pair transitions
  are no-change, so R = 11 = E, z = 0, **p = 1.0 → PASS**. The data is identical; only the tie order differs.
- **Cycle level, separate illustration** with signs W W L W L L W L W W: n1 = 6, n2 = 4, R = 7, E = 5.8,
  Var = 2.027, z = 0.843, p = 0.399.

**8.11 dependence.** Take two cycles, each with legs (+100, −90), on 100,000 capital.

- **Realized order** +100, −90, +100, −90: equity 100,100 → 100,010 → 100,110 → 100,020, so **DD = 90**.
- **Leg permutation** −90, −90, +100, +100 gives **DD = 180**. Three of the six distinct orderings reach 180.
- **Cycle units** (+10, +10) give **DD = 0**.
- **Flipped sign**, with cycles (+50, +50) and (−60, −60): the cycle DD is 120 in either cycle order.
  Three of the six leg orderings give DD 60 or 70 (for example −60, +50, −60, +50 → 70), so the centre of the
  leg-shuffle distribution understates the coupled loss. That is the optimistic case.

All of the above are mathematical counterexamples. The empirical explanation for 41112 is the decomposition and
envelope in section (1).

## (3) Minimum evidence contract (preregister before any use)

1. **cycle_id** (EA-emitted, deterministic) on every closing-deal row, plus `position_id` and `deal_ticket`.
   - A missing or inconsistent cycle_id makes the stream **INVALID**, fail-closed.
   - No silent inference from `entry_time`. Here that grouping happens to give 53×2, but such inference may only
     come in as a separately preregistered and fixture-tested fallback.
2. **Partial closures**: each closing deal is a row linked to its position and cycle. Cycle P&L is the sum of
   those rows. Partial closes never create extra sampling units.
3. **Asynchronous exits**: a cycle's close time is its last leg's close. Units are ordered by
   (close time, cycle_id), never by file order.
4. **Overlapping cycles**: units whose holding intervals overlap merge into one block (connected component).
   Resampling operates on blocks.
5. **Costs**: worst-case commission, swap and fee are applied per deal *before* aggregation. Report both gross
   and net. Sign is evaluated on the net.
6. **Sparse samples**: use a cycle or block floor, not a leg floor; I suggest ≥ 40 units, matching DL-070.
   Below the floor the result is **INVALID, never PASS**. 41119's 32 leg trades are about 16 cycles.
7. **Two separate estimands.** Keep these apart:
   - *Diagnostic realized-close resampling* (8.9/8.11 on cycles or blocks). This is a structural robustness check.
   - *FTMO account-loss simulation*. This needs the daily MTM equity path (EQUITY_SNAPSHOT, 2021 rows exist),
     including floating P&L, the 5% daily and 10% total rules, and a block bootstrap with block length ≥ the
     longest cycle (about one month). This one is a simulation. It is not authorized here, and no 8.9/8.11 output
     may be cited as daily-loss, margin, independence or book-P80 evidence.

## (4) Preregistered fixtures (for a separate engineer, only if a DL authorizes the change)

- **F1 hedged alternation**: the 10-cycle toy. Legacy leg-level gives p = 3.5e-5 (pins the old behavior).
  The cycle-level unit is order-invariant.
- **F2 tie order**: the same rows in WL/LW order. Legacy gives R = 20 vs R = 11; the cycle unit gives an identical result.
- **F3 genuine streak**: 10 winning cycles followed by 10 losing cycles must still FAIL. The fix must not become a free pass.
- **F4 DD coupling**: the hedged and same-direction toys from (2). Assert cycle-block DD against the hand values above.
- **F5** missing cycle_id → INVALID.
- **F6** asynchronous exit with an overlapping cycle → one merged block.
- **F7** partial close → one cycle, P&L equals the sum of its deals.
- **F8** 16 cycles → INVALID.
- **F9** 41112 sealed stream (sha `42f9…a147`). The legacy path must keep reproducing R = 78 / p = 2.53e-6 /
  p95 = 4654.46. The native verdict stays immutable.

## (5) Next action and what stays unproved

**Next.** Write a governance DL, before QM5_41119 reaches Q08, that decides:
- (a) the multi-leg 8.9/8.11 unit (cycle/block), and
- (b) whether 8.9 stays two-sided.

Then implement it via Codex against F1–F9 and apply it prospectively only. Do not re-grade 41112.
Note that 41119 is likely to trip the same leg-level artifact; at about 16 cycles it would be INVALID under any
cycle floor anyway.

**Unproved:**
- whether 41112 or 41119 have any edge (DSR fails);
- concurrent intra-cycle MTM and FTMO daily-loss risk;
- whether a preregistered cycle-level 8.9 would pass any candidate (p = 0.403 is exposed-data only);
- book independence and P80.
