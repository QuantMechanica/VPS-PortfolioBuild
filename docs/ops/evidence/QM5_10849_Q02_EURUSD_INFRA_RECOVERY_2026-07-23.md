# QM5_10849 Q02 EURUSD infrastructure recovery — 2026-07-23

## Scope

- EA: `QM5_10849_tv-smema-sovereign`
- Work item: `3729d47c-db4a-43a2-8b8a-1f2f6191d62c`
- Phase / symbol: Q02 / `EURUSD.DWX`
- Failed evidence: `D:\QM\reports\work_items\3729d47c-db4a-43a2-8b8a-1f2f6191d62c\QM5_10849\20260723_151809\summary.json`
- Recovery owner: `codex:agents/board-advisor`

## Diagnosis

The Q02 result is infrastructure-invalid, not a strategy result:

- all three attempts produced `NO_HISTORY` plus `INCOMPLETE_RUNS`;
- every report had empty Expert and Symbol fields, an M0/1970 period, and zero bars;
- the tester configuration requested the correct EA, `EURUSD.DWX`, H1, Model 4, and the 2018-07-02 through 2022-12-31 window;
- the source and deployed EX5 hashes matched (`736d915dd9da3ef4d539f85a06f421d29333aa9fc1a18a897ab34161d070639b`) and remained stable during the run;
- the source and deployed RISK_FIXED backtest setfile hashes matched (`f9ce240ac26afa93c3fed65a7e5ceaf0c4ddde163f4d6cbb13c278e337c6ef3c`);
- `EURUSD.DWX` history coverage was recorded as 2017–2026.

The terminal exited before opening a valid tester context on T1. This is the same transient shared-bases/history-context failure class seen by the paced fleet, so recompiling or changing strategy logic would not address it.

## Recovery

The existing failed work-item row was reopened in place rather than inserting a duplicate. Its payload records this evidence path, the previous evidence path, and an `avoid_terminals: ["T1"]` constraint. The queue may dispatch it to another factory terminal when capacity is available. No backtest was launched manually.

This recovery does not touch T_Live, AutoTrading, the portfolio gate, or any live manifest.
