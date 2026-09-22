# FTMO USDJPY `TRADE_RETCODE_TRADE_DISABLED` diagnosis

Task: `6fa7831a-1a6d-42b6-9307-dfc39eb12b6c`
Scope: read-only diagnosis of FTMO-Demo login `1514536732`; no order, order-check,
symbol-selection, terminal-control, restart, or AutoTrading action was authorized or
performed.

## Verdict

**`ACCOUNT_WIDE` — decisive.** The incident is not a USDJPY holiday/session closure
and not an EA timing defect. The connected terminal still permits trading and every
requested symbol advertises `SYMBOL_TRADE_MODE_FULL`, while the account-level flag is
`ACCOUNT_TRADE_ALLOWED=false`. Roughly four hours before the USDJPY rejects, FTMO
cancelled two XAUUSD pending orders and force-closed a USDCAD position with the
broker comment `CLOSED_BY_FTMO`. That cross-symbol administrative action is the
causal boundary supported by the evidence.

The exact FTMO business reason for disabling this login is not exposed by MT5. The
account name identifies a Free Trial and the governed local terms say Free Trials
deactivate after 14 calendar days from the first trade, so trial lifecycle is a
plausible explanation, but **expiry is not promoted to a proven cause here**.

## Read-only terminal snapshot

The collector attached through the Python MT5 IPC only after proving that exactly one
process was already running from
`C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe`. The process PID
was unchanged after collection. Snapshot facts:

- terminal: connected, build `6182`, `terminal_trade_allowed=true`,
  `tradeapi_disabled=false`;
- account: `account_trade_allowed=false`, `account_trade_expert=true`, no open
  positions, no pending orders;
- account name/server: `$100k FTMO Free Trial 2-Step` / `FTMO-Demo`;
- balance/equity: `100053.41` / `100053.41`.

| Requested symbol | Broker symbol | Trade mode | `SYMBOL_START_TIME` | `SYMBOL_EXPIRATION_TIME` |
|---|---|---:|---:|---:|
| USDJPY | USDJPY | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |
| XAUUSD | XAUUSD | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |
| USDCAD | USDCAD | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |
| XTIUSD | USOIL.cash | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |
| GBPUSD | GBPUSD | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |
| EURUSD | EURUSD | `SYMBOL_TRADE_MODE_FULL` (`4`) | `0` | `0` |

`SYMBOL_START_TIME` and `SYMBOL_EXPIRATION_TIME` are instrument-lifecycle fields,
not daily session boundaries. `SymbolInfoSessionTrade()` is not exposed by the
installed Python MT5 IPC. Running it would require attaching or executing MQL inside
the live demo terminal, which was outside this read-only task and was deliberately
not attempted. That limitation does not leave the requested classification
ambiguous: all six symbols are `FULL`, the account flag is false, and FTMO acted
across XAUUSD and USDCAD before USDJPY failed. Because the classification is
`ACCOUNT_WIDE`, the conditional request for an exact `SYMBOL_SESSION` window is not
applicable.

## Bound timeline

The EA log binds FTMO server time to UTC at `UTC+03:00`. Terminal journal timestamps
are Europe/Berlin local time (`UTC+02:00` on this date), not FTMO server time.

| UTC | FTMO server | Event |
|---|---|---|
| 2026-09-21 03:00 | 2026-09-21 06:00 | The same EA placed both USDJPY stops successfully (`retcode=10009`). |
| 2026-09-21 22:05 | 2026-09-22 01:05 | EA 10403 placed two XAUUSD stops successfully (`retcode=10009`; tickets `546985040`, `546985290`). |
| 2026-09-21 23:02:05 | 2026-09-22 02:02:05 | Both XAUUSD tickets changed to `ORDER_STATE_CANCELED`, well before their expirations. |
| 2026-09-21 23:02:06 | 2026-09-22 02:02:06 | FTMO order `547007430` / deal `524247545`, magic `0`, force-closed USDCAD with `CLOSED_BY_FTMO`. |
| 2026-09-22 03:00 | 2026-09-22 06:00 | Both USDJPY stop requests failed with retcode `10017` (`Trade disabled`). |
| snapshot | snapshot | Account trading false; all six symbol modes still `FULL`; inventory zero. |

This also corrects the incident clock label: journal `05:00` is Berlin local
`03:00Z`, which is **06:00 FTMO server**, not 05:00 server. The EA specification and
source place orders at the default 06:00 GMT+3-equivalent anchor, and the prior day's
same-anchor orders were accepted. No schedule shift or retry is justified.

## Holiday and FTMO-spec comparison

The [Japan Cabinet Office 2026 holiday
calendar](https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html) lists 21 September as
Respect for the Aged Day, 22 September as the statutory intervening holiday, and 23
September as Autumnal Equinox Day. This is relevant calendar context, but it cannot
explain the observed account state:

- the broker continued to advertise USDJPY and all comparison instruments as
  `SYMBOL_TRADE_MODE_FULL`;
- USDJPY succeeded at the identical server anchor on the preceding day;
- the disabling boundary first manifested as FTMO cancellation/closure on XAUUSD and
  USDCAD, not as a USDJPY-only session response; and
- the terminal was connected and terminal-level trading remained allowed while the
  account-level flag alone was false.

The governed local copy of FTMO's Symbols page says exact/amended hours must be
checked in the trading platform and against FTMO trading updates. Native platform
state was therefore given priority. The source-intake router refused a new generic
FTMO API fetch (`PERMISSION_REQUIRED`, `DEFERRED:SOURCE_POLICY`), so no ungoverned API
response is used in this verdict.

## Operational consequence

This evidence does **not** authorize an EA/card change. Retrying retcode 10017 cannot
overcome `ACCOUNT_TRADE_ALLOWED=false` and can only add avoidable requests.

For Sunday genesis:

1. Do not reuse login `1514536732` for the next generation.
2. Follow the already-decided fresh-account path in
   `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md`.
3. Before attach/launch and again before each entry-capable window, require a fresh
   readback with terminal connected, terminal trading allowed,
   `ACCOUNT_TRADE_ALLOWED=true`, `ACCOUNT_TRADE_EXPERT=true`, and every deployed
   symbol in `SYMBOL_TRADE_MODE_FULL`. Any false account flag is a hard no-entry
   condition.
4. If retcode 10017 recurs on a fresh login while both account flags are true, reopen
   the incident as a symbol/session-or-transient investigation before considering a
   bounded retry policy.

## Evidence and provenance

- `capture.json` — terminal/account/symbol dump, history, bound log excerpts, file
  hashes, and FTMO pulse state.
- `collect_read_only.py` — reproducible collector with the already-running-process
  guard and no trade-capable calls.
- `source_intake_router.json` — deterministic source-policy refusal for the proposed
  FTMO API fetch.
- `verification.json` — focused assertions over the classification, cross-symbol
  timeline, clock binding, provenance hashes, and collector call surface.
- `verify.py` — deterministic verification program.

Bound local sources:

| Source | SHA-256 |
|---|---|
| `docs/ops/evidence/ftmo_fetch_20260918/cand_symbols.html` | `103d7486d307d28588e4bae7849d062d944834e557fd01b8ddf6ae1cf756d684` |
| `docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md` | `6d6c7bdd43b690db44d1fac8e64fcb515c2db0d79ae6f12de00e7f5bbcb2e753` |
| `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` | `a20b8080a15e6c0801ef49956b33091e870a3ce79258870babfd0eea54ce1295` |
| `framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md` | `dfe0730c8f3f43844b400a011faa6489479eecb11d133a515c3a548ed3ebc436` |
| `framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5` | `ea3920720c4f71ebe2ed4266075e51bc0fad67b261ebf15ef6335a9c68584448` |
