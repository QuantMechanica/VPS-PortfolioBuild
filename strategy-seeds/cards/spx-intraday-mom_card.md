# Strategy Card — SPX Market Intraday Momentum (last half-hour)

> Authored 2026-07-19 by Claude (board-advisor) for FTMO Challenge Book V3, Role 3
> (Equity Microstructure Champion — vacant per
> `docs/research/FTMO_CHALLENGE_EA_TARGET_BOOK_2026-07-17.md`).
> Sourcing evidence: session scratchpad `ftmo_sourcing/briefs.md` (ranked field of 5;
> this was Rank 1 / BUILD-CANDIDATE).

---

## Card Header

```yaml
strategy_id: SRC_FTMO_V3_R3_S01
ea_id: TBD                                   # allocate at APPROVED (registry append + tail-recheck)
slug: spx-intraday-mom
status: DRAFT                                # approve-card AFTER farmctl WIP lands (validator runs through it)
created: 2026-07-19
created_by: Claude (board-advisor)
last_updated: 2026-07-19

strategy_type_flags: [momentum, intraday, seasonality]
target_symbols: [SP500.DWX]                  # research symbol; NDX.DWX = robustness cross-check only
```

## 1. Source

```yaml
source_citations:
  - type: paper
    citation: "Gao, Lei; Han, Yufeng; Li, Sophia Zhengzi; Zhou, Guofu. (2018). Market intraday momentum. Journal of Financial Economics 129(2), 394-414. DOI 10.1016/j.jfineco.2018.05.009"
    location: "abstract + section 2 (predictive regressions first->last half-hour)"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Zarattini, Carlo; Aziz, Andrew; Barbon, Andrea. (2024). Beat the Market: An Effective Intraday Momentum Strategy for S&P500 ETF (SPY). Swiss Finance Institute Research Paper N 24-97. https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4824172"
    location: "full paper (net-of-cost replication 2007-2024)"
    quality_tier: B
    role: supplement
  - type: paper
    citation: "Bogousslavsky, Vincent. (2016). Infrequent Rebalancing, Return Autocorrelation, and Seasonality. Journal of Finance 71(6), 2967-3006. DOI 10.1111/jofi.12480"
    location: "theory: periodic intraday autocorrelation from infrequent rebalancing"
    quality_tier: A
    role: supplement
```

## 2. Concept

The S&P 500's first half-hour return (measured from the prior session close, so it
includes the overnight gap) positively predicts the same day's last half-hour return.
Documented drivers: late-informed investors trading toward the close and infrequent
portfolio rebalancing concentrating correlated flow at the open and close
(Bogousslavsky 2016). The effect strengthens on high-volatility days. We trade only
the last half-hour in the direction of the first half-hour, flat overnight.

## 3. Markets & Timeframes

```yaml
markets:
  - indices
timeframes:
  - M30                                      # signal/execution grid; data M1, Model 4 real ticks
primary_target_symbols:
  - SP500.DWX                                # research/backtest symbol (backtest-only availability is fine here)
notes: |
  Broker time = NY-close convention (GMT+2 winter / GMT+3 during US DST). US cash
  session 16:30-23:00 broker. First half-hour bar = 16:30-17:00 broker; last
  half-hour = 22:30-23:00 broker. FTMO live route would be US500.cash and requires
  full requalification on that route per the V3 book contract (research->FTMO symbol
  moves are never silently ported).
```

## 4. Entry Rules

```text
- at 22:30 broker (last-half-hour open), compute r_fh = Close(17:00 broker) / PrevSessionClose(23:00 broker) - 1
- if |r_fh| >= strategy_signal_vol_mult * median(|r_fh| over last strategy_vol_lookback sessions): signal is valid, else skip (magnitude filter -> ~12-18 trades/month)
- if r_fh > 0: BUY at market; if r_fh < 0: SELL at market
- catastrophe stop (non-alpha): strategy_stop_atr_mult * ATR(M30, 14) from entry
- skip Fridays entirely (Friday-Close hard rule forces flat before the trade window)
- skip if session data incomplete (missing 16:30-17:00 bar / prior close) or news blackout active
```

## 5. Exit Rules

```text
- time exit at 22:59 broker (one minute before cash close) — always flat overnight
- SL = catastrophe stop only (non-alpha); no TP (exit is time-based per the papers)
- no trailing, no partial closes
```

## 6. Filters (No-Trade module)

```text
- Fridays: no entry (framework Friday Close)
- half-days / short sessions: no entry if the session close bar sequence is not standard
- news blackout per QM_NewsFilter framework default
- magnitude filter per Entry Rules (the only strategy-specific gate)
```

## 7. Trade Management Rules

```text
- none beyond entry/exit; one position per magic+symbol (V5 default)
- pyramiding: NOT allowed; gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: strategy_signal_vol_mult
  default: 0.5
  sweep_range: [0.0, 0.25, 0.5, 0.75, 1.0]
- name: strategy_vol_lookback
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 3.0]
```

## 9. Author Claims (as reported; page-exact quotes to be pinned at G0 review)

```text
Gao/Han/Li/Zhou (2018, JFE 129:394-414): first half-hour return (including the
overnight gap) significantly predicts the last half-hour return of the same day;
predictability is stronger on high-volatility and high-volume days and yields
economically significant market-timing gains. (abstract-level claim)
Zarattini/Aziz/Barbon (2024, SFI 24-97): intraday momentum on SPY 2007-2024 with
realistic costs: ~19.6% annualized, net Sharpe 1.33 vs 0.45 buy-and-hold; Sharpe
~3.5 in VIX>40 regimes. (paper headline figures)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.25                            # net-of-spread estimate; FTMO indices = zero commission, spread-only
expected_dd_pct: 8
expected_trade_frequency: 150-220/year       # ~12-18/month after magnitude filter, Fridays skipped
risk_class: medium
gridding: false
scalping: false                              # one entry + one time exit per day; holds 29 minutes; not P5b-latency-critical
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Mechanical, no discretion
- [x] No ML
- [x] No gridding
- [x] Not scalping in the latency-critical sense (single M30 decision; P5b still runs per pipeline default)
- [x] Friday Close compatible via skip-Friday rule (no exception needed)
- [x] Source citations precise (DOIs/SSRN id, sections named)
- [x] No near-duplicate: distinct from QM5_20004 TOM (monthly calendar), QM5_1159 overnight-MA20 (overnight hold), QM5_4007 MAC5 (daily momentum-reversal), QM5_10326 closing-auction (auction imbalance), and the NDX/GDAXI breakout family (range breakouts). Same-family fallback (Bogousslavsky periodic autocorrelation) is documented in the sourcing brief, not co-proposed.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Friday skip, short-session skip, magnitude filter, news default"
  trade_entry:
    used: true
    notes: "22:30-broker signal from first-half-hour return incl. overnight gap"
  trade_management:
    used: false
    notes: "none"
  trade_close:
    used: true
    notes: "time exit 22:59 broker; catastrophe stop non-alpha"
```

```yaml
hard_rules_at_risk:
  - friday_close
  - news_pause_default
at_risk_explanation: |
  friday_close: the trade window (22:30-23:00 broker) lies after the Friday forced
  flat; resolved by skipping Friday entries entirely (frequency cost ~20%, cleaner
  than an exception). news_pause_default: last half-hour occasionally overlaps late
  announcements; framework news filter stays ON (no exception requested).
```

## 13. Implementation Notes (CTO fills at APPROVED)

```yaml
target_modules:
  no_trade: "session-completeness check + Friday skip + magnitude gate"
  entry: "prev-session-close anchor + 17:00-broker bar close; DST-invariant via broker NY-close convention"
  management: none
  close: "time exit via broker-clock minute check; QM_EXIT_STRATEGY reason"
estimated_complexity: small
estimated_test_runtime: "full-history M1 real-tick SP500.DWX, single run per config"
data_requirements: standard
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | TBD | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-19 | DRAFT (approve pending farmctl unblock) | this card |

## 16. Lessons Captured

```text
- 2026-07-19: sourced for FTMO V3 Role 3; decisive open question = post-2013 decay
  (Gao sample ends 2013; Zarattini reports net viability through 2024) — Q02 full
  history answers this cheaply before any deeper investment.
- Killed alternatives at sourcing: opening-range breakout (duplicates breakout
  family + alpha lives in single-stock cross-section), overnight drift (authors'
  own 2026 follow-up shows decay to ~zero since 2021), pre-FOMC drift (8/year,
  fails density; flagged as possible separate rare-event sleeve).
```
