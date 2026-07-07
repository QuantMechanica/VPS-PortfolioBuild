# Codex Review: Q09 Basket Host-Symbol Resolution

Task: `b4e2a62b-0819-4ced-a297-f85a78133422`  
Review target: `SELF_REVIEW (R21): Q09 basket host_symbol fix (portfolio_q08_contribution.py)`  
Date: 2026-07-07

## Verdict

PASS_CONDITIONAL. The current code fixes the basket logical-symbol stream mismatch at the shared `portfolio_common.load_streams()` choke point and the 12778 durable Q09 aggregate confirms the intended empirical outcome. Condition: add committed regression tests for basket aliasing and stale-host-vs-logical mtime selection; the behavior was verified by a temporary harness in this review, but the permanent test suite still mostly covers adjacent portfolio behavior.

## Evidence Reviewed

- `C:/QM/repo/tools/strategy_farm/portfolio/portfolio_q08_contribution.py`
- `C:/QM/repo/tools/strategy_farm/portfolio/portfolio_common.py`
- Commits:
  - `f8e79266b` - initial Q09 basket host-symbol resolution.
  - `b0d95663e` - review blockers: central aliasing in `load_streams`, stale-host mtime rule.
- `D:/QM/reports/work_items/0b1fddba-6c4e-47ec-b9b3-6b54273e5832/QM5_12778/Q09_PORTFOLIO/QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1/aggregate.json`
- `D:/QM/strategy_farm/state/farm_state.sqlite`

## Claim Checks

1. Logical basket symbols can miss stream files: VERIFIED. `stream_path_key()` converts stream filename underscores to dots. A logical candidate such as `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` does not naturally match a host-keyed file such as `12778_AUDUSD_DWX.jsonl`; without aliasing, basket Q09 can see `trade_count=0`.

2. Setfile `; host_symbol:` resolution mirrors the Q08 basket class: VERIFIED. `resolve_basket_stream_key()` scans the EA setfiles for `; host_symbol:` and resolves the basket candidate to the host-keyed stream. In the 12778 aggregate, `stream_resolution` is `host_symbol_from_setfile:QM5_12778_edgelab-audusd-eurjpy-cointegration_QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1_D1_backtest.set`.

3. Non-basket regression risk: VERIFIED by code path and harness. `BASKET_SYMBOL_RE = ^QM5_\d+_` gates the basket resolver. Non-basket candidates return `(None, None)` and continue through the ordinary `stream_path_key()` path.

4. 12778 scratch/durable re-evaluation: VERIFIED from durable farm evidence. The current farm DB has Q09 work item `0b1fddba-6c4e-47ec-b9b3-6b54273e5832` marked `done/PASS_PORTFOLIO`, and the aggregate reports:
   - `trade_count=195`
   - `stream_key=12778:AUDUSD.DWX`
   - `max_corr_to_book=0.1004857919`
   - `maxdd_with=0.2917107088`
   - `maxdd_without=0.3366164535`
   - `sharpe_with=2.4352605925`
   - `sharpe_without=2.4320058978`

## Focused Verification

Commands run from `C:/QM/repo`:

```text
python <temporary basket alias harness>
python -m unittest tools.strategy_farm.tests.test_portfolio_common tools.strategy_farm.tests.test_portfolio_q08_contribution
python <farm-db + aggregate reader for QM5_12778 Q09>
```

Output:

```text
basket alias harness: PASS
Ran 10 tests in 0.182s
OK

verdict: PASS_PORTFOLIO
reason: admitted
trade_count: 195
stream_key: 12778:AUDUSD.DWX
stream_resolution: host_symbol_from_setfile:QM5_12778_edgelab-audusd-eurjpy-cointegration_QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1_D1_backtest.set
max_corr_to_book: 0.1004857919
maxdd_with: 0.2917107088
maxdd_without: 0.3366164535
```

## Review Notes

- The follow-up architecture is better than the original one-sided `portfolio_q08_contribution.py` wrapper: aliasing belongs in `portfolio_common.load_streams()` because portfolio admission, manifest assembly, correlation, and Monte Carlo all consume that loader.
- `load_streams()` returns trades under the original candidate key for logical basket candidates, while reading from the resolved host/logical file key. That preserves book identity and avoids silent basket sleeve drops.
- The newer-logical-file rule is important. If both a durable logical-named stream and a volatile host-named stream exist, the newer file wins so a farmctl refresh through the logical path is not shadowed by stale host data.
- Permanent tests should cover:
  - host-symbol file returned under original logical basket key;
  - non-basket candidates unchanged;
  - logical file newer than host file wins;
  - host file newer or logical absent resolves to host file.
