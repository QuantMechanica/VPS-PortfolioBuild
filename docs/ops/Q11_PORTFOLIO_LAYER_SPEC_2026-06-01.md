# Q11 Portfolio-Construction-Layer — Engineering Spec

**Date:** 2026-06-01
**Authority:** DL-064 (Portfolio-Construction-Layer), OWNER directive 2026-06-01
**Owner of spec:** Claude · **Execution:** Codex (ops_issue tasks A/B/C)
**Status:** Spec frozen — Task A actionable now; B/C BLOCKED on A.

## Why

DL-064 ratified that the Strategy Farm's success metric shifts from "how many
EAs pass the gates" to **portfolio Sharpe / DD / uncorrelated-sleeve count**.
Today Q11 ("Portfolio Construction") is only a phase name; the sole portfolio
logic is `farmctl.py:7112` ("≥1 symbol passed = candidate"). This spec defines
the real machinery (DL-064 R-064-3).

Gate-0 (cost-correctness) is satisfied: Q04 applies an EA-side simulated
commission of **$7.00/lot round-trip** (`InpQMSimCommissionPerLot`, constant
`COMMISSION_PER_LOT_ROUND_TRIP = 7.00` in `framework/scripts/q04_walkforward.py`).
OWNER decided 2026-06-01: **Q02/Q03 stay gross screens; Q04 is the first
cost-aware gate.** The portfolio layer MUST be cost-correct (see §Cost rule).

## Inputs (verified on disk 2026-06-01)

1. **Per-trade close streams** — `<COMMON>/QM/q08_trades/<ea_id>_<SYMBOL>_DWX.jsonl`
   where `<COMMON>` = `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files`.
   166 streams over ~60 EAs today (incl. basket EA 10430 with 6 symbols). One
   JSON object per line:
   ```json
   {"event":"TRADE_CLOSED","time":1511784489,"net":-1402.26,"profit":-1402.25,"swap":0.00,"commission":-0.01,"volume":3.55}
   ```
   - `time` = unix epoch **seconds** (UTC). `net` = per-trade net P&L in account
     currency (USD). `volume` = lots. `commission` here is the tester's ~$0 on
     `.DWX` custom symbols — NOT the realistic $7/lot (see §Cost rule).
   - Filename symbol token uses `_` for `.` (`XAUUSD_DWX` ↔ `XAUUSD.DWX`).
   - Streams can be sparse (e.g. `10069_XAUUSD_DWX.jsonl` has 3 trades). Handle
     low-count series explicitly (see §Edge cases).

2. **Candidate set** — `portfolio_candidates` table in
   `D:/QM/strategy_farm/state/farm_state.sqlite`
   `(ea_id, symbol, q11_work_item_id, state, evidence_path, first_seen_at, updated_at)`,
   populated by `agent_router.py sync-q11-candidates` from **Q10 PASS** work_items.
   **Currently EMPTY** (pipeline front is at ~Q04; nothing has reached Q10 yet).
   The layer MUST therefore operate in two modes:
   - **candidate mode** (default once populated): only EA-symbols in
     `portfolio_candidates` with `state` in the Q12-ready set.
   - **discovery mode** (`--all-streams`): every q08_trades stream on disk —
     used NOW for development/validation against real data while the candidate
     table is empty. Discovery-mode output MUST be clearly labelled
     `"basis":"all_q08_streams_uncertified"` in the artifact so no one mistakes
     it for a certified portfolio.

## Cost rule (correctness-critical — do not skip)

The q08_trades `net` is **gross of realistic cost** (Q08 runs with
`InpQMSimCommissionPerLot=0`). Before building any return/equity series the
loader MUST compute, per trade:

```
net_of_cost = net - COMMISSION_PER_LOT_ROUND_TRIP * volume      # 7.00 USD/lot round-trip
```

Import the constant from `framework/scripts/q04_walkforward.py`
(`COMMISSION_PER_LOT_ROUND_TRIP`) — do NOT hardcode a second copy. The artifact
MUST record the commission value used. Building the portfolio on raw `net` would
rebuild exactly the gross-of-cost fiction Gate-0 eliminated — that is a hard
review-fail.

## Module layout

New package `tools/strategy_farm/portfolio/`:
- `portfolio_common.py` — shared loader (Task A builds; B/C import).
- `portfolio_correlation.py` — Task A.
- `portfolio_kpi.py` + `portfolio_assemble.py` — Task B.
- `portfolio_montecarlo.py` — Task C.

Artifacts → `D:/QM/strategy_farm/artifacts/portfolio/` (create if absent).
All scripts: `subprocess`-free pure computation, deterministic, no network. Use
only stdlib + numpy (numpy is already used in `framework/scripts/q08_davey/`).
On win32 any subprocess (none expected here) needs `CREATE_NO_WINDOW`.

---

## Task A — Loader + correlation matrix (`portfolio_common.py`, `portfolio_correlation.py`)

### A1 `portfolio_common.py`
- `load_streams(common_dir: Path, *, candidates: list[tuple[str,str]] | None = None) -> dict[tuple[int,str], list[Trade]]`
  Read q08_trades JSONL. If `candidates` given, restrict to those (ea_id, symbol);
  else all streams (discovery mode). Parse each line; skip non-`TRADE_CLOSED`.
- Apply the §Cost rule → each trade carries `net_of_cost`.
- `to_daily_pnl(trades) -> dict[date, float]` — sum `net_of_cost` per UTC calendar
  day. (Daily is the correlation granularity; a stream with all trades on
  distinct days still works.)
- `align(series_by_key) -> (dates: list[date], matrix: np.ndarray)` — union of all
  dates as the index; missing day for a series = 0.0 P&L that day (flat, no
  position closed). Return EA-symbol order alongside.

### A2 `portfolio_correlation.py`
- CLI: `--common-dir <path>` (default the live Common\Files), `--candidates-db`
  (default farm_state.sqlite; read `portfolio_candidates`), `--all-streams`
  (discovery mode), `--out <artifact.json>`, `--min-overlap-days <int default 60>`.
- Build the aligned daily-P&L matrix (A1), convert to daily returns proxy
  (use daily P&L directly as the series for correlation — these are absolute USD
  per fixed-risk run, which is the correct cross-EA comparison basis here).
- Compute the **Pearson correlation matrix** across EA-symbol series. For any
  pair whose overlapping non-zero-activity day count `< min_overlap_days`, set
  correlation to `null` and record the pair in `"insufficient_overlap"` — do NOT
  emit a spurious correlation from a handful of shared days.
- Emit artifact JSON:
  ```json
  {
    "generated_basis": "candidates" | "all_q08_streams_uncertified",
    "commission_per_lot_round_trip": 7.0,
    "n_series": 42, "n_days": 2103,
    "keys": ["10430:NDX.DWX", "..."],
    "correlation": [[1.0, -0.12, ...], ...],
    "insufficient_overlap": [["10069:XAUUSD.DWX","10430:NDX.DWX"], ...],
    "per_series": {"10430:NDX.DWX": {"trades": 88, "active_days": 71, "net_of_cost_total": 12750.4}}
  }
  ```

### A acceptance
- Runs `python tools/strategy_farm/portfolio/portfolio_correlation.py --all-streams
  --out D:/QM/strategy_farm/artifacts/portfolio/correlation_dev.json` against the
  166 live streams, exits 0, writes the artifact.
- A unit test `tools/strategy_farm/tests/test_portfolio_correlation.py` with a
  tiny synthetic fixture (2 anti-correlated series + 1 sparse series) asserting:
  (a) cost rule applied (`net_of_cost == net - 7*volume`), (b) anti-correlated
  pair ≈ -1.0, (c) sparse pair lands in `insufficient_overlap`.
- No hardcoded $7 (imported constant). Deterministic output (sorted keys).

---

## Task B — Portfolio KPI + assembler (BLOCKED on A; import A's loader)

`portfolio_kpi.py`: given a set of EA-symbol keys + per-key weight, build the
combined daily equity curve from A1's aligned matrix and compute **portfolio max
drawdown (%)**, **portfolio Sharpe** (annualised from daily series), total
net-of-cost profit. `portfolio_assemble.py`: greedy/Markowitz-lite selection that
picks a low-correlation subset whose combined max DD respects the mission bound
(5% daily / 20% total — parameterised; default target portfolio max DD ≤ 6%),
maximising Sharpe. Emit a portfolio manifest artifact (keys + weights + KPIs).
**Full sub-spec to be frozen against A's real output schema once A lands** — do
not start until Task A is APPROVED.

## Task C — Portfolio Monte Carlo (BLOCKED on A)

`portfolio_montecarlo.py`: resample the **combined** daily P&L series (block
bootstrap + trade-order shuffle) N times; emit the distribution of portfolio max
DD and terminal equity (p5/p50/p95). Distinct from per-EA Q05/Q06 reshuffle.
Sub-spec frozen after A. Do not start until A is APPROVED.

---

## Out of scope (this spec)
- Dashboard portfolio-view (separate task once artifacts exist).
- T_Live portfolio-manifest deploy (R-064-4 — OWNER+Claude gate, later).
- Making Q02/Q03 cost-aware — OWNER decided they stay gross.
- Wiring `sync-q11-candidates` into pump cadence — separate ops task.
