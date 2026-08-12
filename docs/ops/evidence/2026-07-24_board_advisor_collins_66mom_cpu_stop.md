# Board Advisor Commodity Sleeve — Collins 66% WTI CPU Stop

Date: 2026-07-24
Branch: `agents/board-advisor`
Role: Codex headless paced fleet

## Outcome

The selected next unbuilt commodity candidate is the source-defined Collins
9-day 66 percent momentum rule, specialized as an `XTIUSD.DWX` D1 carrier:

- source strategy ID: `SRC08_S01`
- proposed slug: `collins-66mom`
- source: Art Collins, *Beating the Financial Futures Market* (Wiley, 2006),
  Chapter 41, pp. 177-179, and Appendix Table 41.3, p. 232
- signal: compare the latest close's distance from the 9-day high (`XH`) and
  9-day low (`XL`)
- long: when `XH > XL`, arm a next-session buy stop at
  `open + 0.66 * XL`
- short: when `XL > XH`, arm a next-session sell stop at
  `open - 0.66 * XH`
- frozen stop distance: `1.32 * max(XH, XL)` from the filled entry

This is a structural daily stop-entry momentum rule. It uses only broker-native
OHLC, fixed arithmetic, fixed-risk sizing, and framework safety controls. It
requires no ML, banned indicator, external data, grid, martingale, or
pyramiding.

## Source boundary

The relevant source pages and appendix formula were read from the repository's
recorded local PDF. Collins reports the rule on equity-index and other
financial futures, not WTI. A WTI build must therefore be described as a
carrier falsification, not as a replication or a source-backed WTI performance
claim.

There is repository precedent for this bounded translation:
`QM5_12767_collins-15rex` is an approved WTI realization of a different
Collins rule. The `SRC08` source record and
`docs/research/LIBRARY_MINING_art-collins-2006_2026-06.md` durably record OWNER
approval of the bounded three-card Collins mining batch.

## Non-duplicate audit

At the stop time:

- no `collins-66mom` row existed in
  `framework/registry/ea_id_registry.csv`;
- no `SRC08_S01` strategy ID existed in the EA registry;
- no `QM5_*_collins-66mom` EA directory existed; and
- `strategy-seeds/cards/collins-66mom_card.md` remained an unallocated draft.

The load-bearing rule differs from the nearest WTI builds:

- `QM5_12767_collins-15rex` uses an SMA regime and a next-open
  `1.5 * prior-day range` expansion trigger;
- WTI Donchian builds use prior channel breaks;
- WTI TSMOM builds use multi-month return signs; and
- WTI calendar/event builds use month, weekday, inventory, expiry, refinery,
  OPEC, or holiday clocks.

The 9-day close-location geometry, asymmetric `0.66` next-open trigger, and
formula-derived `1.32` stop are jointly required. Treating only the lookback or
stop multiple as a new strategy would not pass this dedup decision.

## CPU ceiling evidence and stop

`python tools/strategy_farm/farmctl.py mt5-slots` at
`2026-07-24T10:34:25Z` reported seven active factory MT5 pipelines:

`T1`, `T3`, `T4`, `T7`, `T8`, `T9`, and `T10`.

The scan also saw `T_Live` and an FTMO terminal, but neither was counted as a
factory pipeline. The factory count of seven is the paced backtest ceiling.

Per the mission's explicit ceiling condition, work stopped before any pipeline
or build mutation:

- no EA ID was reserved;
- no magic number was allocated;
- no draft card was approved or moved;
- no EA, setfile, binary, or basket manifest was created;
- no Q02 item was enqueued;
- no tester or backtest was launched; and
- no `T_Live`, AutoTrading, deploy manifest, portfolio gate, or portfolio
  manifest was touched.

Concurrent background changes to `framework/registry/ea_id_registry.csv` and
untracked `docs/ops/source_harvest/strategies/` were observed and deliberately
left untouched.

## Resume gate

Resume only after `farmctl mt5-slots` shows fewer than seven active factory
pipelines. The governed continuation is: finalize and lint the WTI-only card,
obtain deterministic G0 approval, atomically reserve the next EA ID, create the
EA directory before magic allocation, regenerate the magic resolver, implement
the exact source rule, strict-compile with a `RISK_FIXED` backtest setfile, and
enqueue one Q02 work item without directly dispatching a tester.
