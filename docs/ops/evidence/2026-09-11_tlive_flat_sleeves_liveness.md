# T_Live flat-sleeve liveness audit — 2026-09-11

Task: `428f6802-36a3-4368-beab-6ce77185a360`. Scope was read-only: logs,
deployed-manifest/preset metadata, attribution and terminal journals were read;
no T_Live process, setting, order, chart, preset, or AutoTrading state changed.

The independent 2026-09-06 live-burnin evidence binds all 24 deployed identities
to the signed 24-sleeve manifest and classifies all eight requested magics as
`ATTACHED`; it reports the eight as flat during the 36 observed days. The
manifest supplies deployed timeframe/risk but no expected-trades/year field, so
the frequency comparison is explicitly UNKNOWN rather than inferred from the
six-week silence.

| Sleeve / magic | Deployed TF | Liveness evidence (per-EA log) | Classification | Owner action |
| --- | --- | --- | --- | --- |
| 10919 XTIUSD / 109190001 | H4 | `QM5_10919_ea-10919.log` lines 362, 371, 373–374: fresh news seed, `INIT_OK`, then 9/10 Sep snapshots | ALIVE_NO_SIGNAL (no blocking event) | None |
| 12567 XNGUSD / 125670002 | D1 | `QM5_12567_ea-12567.log` lines 1010, 1012: 9/10 Sep snapshots; same process has news/KS init at 999–1008 | ALIVE_NO_SIGNAL (no blocking event) | None |
| 12567 XAUUSD / 125670003 | D1 | `QM5_12567_ea-12567.log` lines 999–1008, 1011, 1013: news, KS baseline, `INIT_OK`, 9/10 Sep snapshots | ALIVE_NO_SIGNAL (no blocking event) | None |
| 12778 AUDUSD / 127780000 | D1 | `QM5_12778_ea-12778.log` lines 379–386: KS restore/baseline and `INIT_OK`; no `EQUITY_SNAPSHOT` in the evidence window | NOT_LOGGING, while attached | No re-attach/preset action; instrumentation repair needs a separately governed task |
| 12969 USDJPY / 129690000 | M30 | `QM5_12969_ea-12969.log` lines 317–323: fresh news seed, KS baseline and `INIT_OK`; no `EQUITY_SNAPSHOT` | NOT_LOGGING, while attached | No re-attach/preset action; instrumentation repair needs a separately governed task |
| 12989 XAUUSD / 129890003 | H4 | `QM5_12989_ea-12989.log` lines 440–449, 451–452: news, KS baseline, `INIT_OK`, 9/10 Sep snapshots | ALIVE_NO_SIGNAL (no blocking event) | None |
| 13117 EURGBP / 131170000 | D1 | `QM5_13117_ea-13117.log` lines 360–367: KS restore/baseline and `INIT_OK`; no `EQUITY_SNAPSHOT` | NOT_LOGGING, while attached | No re-attach/preset action; instrumentation repair needs a separately governed task |
| 13128 NDX / 131280000 | H1 | `QM5_13128_ea-13128.log` lines 364–371: KS baseline, `INIT_OK`, 9/10 Sep snapshots | ALIVE_NO_SIGNAL (no blocking event) | None |

The fourth telemetry-silent magic, 15670007 (not one of the eight flat
sleeves), is also attached: `QM5_1567_ea-1567.log` lines 311–317 records a
fresh news seed, KS baseline and `INIT_OK`. The burnin ledger records two opens
for it, so it is `ALIVE_NOT_LOGGING`, not detached.

No requested sleeve shows a kill-switch, calendar-staleness, margin, symbol or
attachment refusal in its cited log evidence. The terminal journal
`C:/QM/mt5/T_Live/MT5_Base/logs/20260911.log` shows normal accepted/dealt order
traffic at 00:01, 04:59, 11:25, 14:34 and 23:04; it supplies no attach failure
for these sleeves.

## Owner actions

None. All eight requested identities are attached and use manifest-matching
deployed presets. Re-attaching or replacing any preset is unsupported by this
read-only evidence and requires an OWNER-authorized deployment procedure.

**RESULT (Q-only):** Q-LIVE-LIVENESS REVIEW — four flat sleeves are healthy
emitters with no observed signal, and four are attached but telemetry-silent.
The missing telemetry is an instrumentation gap, not evidence that the EA is
unattached; expected annual trade frequency remains UNKNOWN because no such
field is present in the signed deployment manifest or supplied backtest evidence.
