# QM5_20153 WTI Thursday Trend Build and Q02 Enqueue

Date: 2026-07-25  
Branch: `agents/board-advisor`

## Outcome

`QM5_20153_wti-thu-trend` adds one structural, low-frequency WTI sleeve:
buy the genuine Thursday D1 session only when the completed 252-D1 WTI return
is positive, then close at the next D1 boundary. This is a direct crude-oil
calendar/trend interaction, not an index, metal, XNG, RSI, or gold/silver-ratio
port. Diversification and portfolio admission remain downstream evidence
questions.

The source packet, OWNER-approved G0 card, deterministic EA/magic allocations,
V5 EA, compiled binary, SPEC, and one `RISK_FIXED=1000` backtest setfile were
committed in `6c51c2452`. Commit `3c1c2725a` refreshed the canonical setfile
hash after the final source state.

## Governance and source

- Source packet:
  `strategy-seeds/sources/QUAY-MOP-WTI-THUTREND-2026/source.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_20153_wti-thu-trend_card.md`
- Reputable lineages: Quayyum, Khan, and Ali (2020) for the positive WTI
  Thursday direction; Moskowitz, Ooi, and Pedersen (2012) for the completed
  12-month own-return sign.
- Card schema lint: PASS, no ML hits and no missing sections.
- Registry: EA 20153 active; slot 0 / `XTIUSD.DWX` / magic `201530000` active.

## Build verification

- Build artifact:
  `artifacts/builds/f8b0d5a1-6629-45c0-9f7c-b53eff65ba87.json`
- Compile recorded: PASS.
- Strict static build check rerun with `-SkipCompile`: PASS, zero failures and
  zero warnings.
- Report:
  `D:\QM\reports\framework\21\build_check_20260725_123240.json`
- MQ5 SHA256:
  `C1E9A97A42E7DC72CDD60F89C7941503D59B1BF6B02EB90D799FBF25CB8DB1C9`
- EX5 SHA256:
  `8B042BBF509D5819A2B3A9EF688CF5C38BBCC127139CF71F4CE38547F4069D14`
- Backtest setfile SHA256:
  `A00A1F75DA4A948184E9569EA1A6F4BAC4DFDB576DF6C82708D983DCA271E856`

## Paced Q02 handoff

- Work item: `e7a906e3-3eb0-47d5-9803-2c3b4c493e26`
- Phase/status: `Q02` / `pending`
- Carrier: `XTIUSD.DWX` / D1
- Queue postcondition: exactly one Q02 row exists for `QM5_20153`; it is
  unclaimed with attempt count zero.

No manual backtest was launched. Runtime was left to the paced factory. No
portfolio gate, T_Live file, deploy manifest, terminal process, or AutoTrading
state was changed.
