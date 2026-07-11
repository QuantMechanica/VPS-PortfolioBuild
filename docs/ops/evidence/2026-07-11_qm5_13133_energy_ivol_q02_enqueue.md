# QM5_13133 XTI/XNG Pure-IVol Q02 Enqueue Evidence

Date: 2026-07-11
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency commodity/energy sleeve:
`QM5_13133_energy-ivol`. Once per broker month, the EA estimates XTI and XNG
idiosyncratic volatility from separate 252-observation OLS regressions against
an equal-weight XTI/XNG/XAU/XAG commodity factor. It buys the lower-IVol energy
leg, shorts the higher-IVol leg, and targets equal dollar notional.

This is an out-of-sample Q02 candidate, not a certified portfolio admission.
No decorrelation result, source performance transfer, or live readiness is
claimed.

## Candidate Selection And Dedup

The mission's named XAU/XAG ratio candidate was rejected because the repository
already contains direct ratio-reversion, ratio-breakout, residual-spread, and
stochastic gold/silver pairs. The WTI and XNG inventory also contains extensive
calendar, trend, reversal, inventory-event, carry, ratio, and higher-moment
sleeves.

The selected gap is the source's standalone commodity IVol strategy. Existing
nearby builds differ materially:

- `QM5_13113_energy-mom-ivol` requires 63-D1 momentum and IVol ranks to agree;
  it stays flat on conflict. QM5_13133 has no momentum input and always ranks
  the two energy residual volatilities at the monthly decision point.
- `QM5_12404_stock-lowvol` is long-only total volatility over a mixed
  index/metal/oil universe.
- `QM5_12530_chan-xsec-lowvol` is short-horizon contrarian mean reversion with
  a total close-dispersion filter and has no registered XTI/XNG carrier.
- `QM5_12567_cum-rsi2-commodity` buys oscillator pullbacks and contains no
  residual-volatility cross-section.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-ivol --strategy-id FUERTES-MOMIVOL-2015_XTI_XNG_S02 --author "Ana-Maria Fuertes Joelle Miffre Adrian Fernandez-Perez" --mechanic "monthly XTI XNG market neutral pure idiosyncratic volatility long lower residual volatility short higher residual volatility 252 D1 OLS four commodity equal weight benchmark one month hold"`

The tool returned one expected fuzzy hit on `energy-mom-ivol_card.md` because of
shared source and slug tokens. Manual rule, parameter, lifecycle, and economic-
mechanism review returned `CLEAN_AFTER_MANUAL_REVIEW` before allocation.

## Source And Card Evidence

- Primary: Fuertes, Miffre, and Fernandez-Perez (2015), "Commodity Strategies
  Based on Momentum, Term Structure and Idiosyncratic Volatility," *Journal of
  Futures Markets* 35(3), 274-297, DOI `10.1002/fut.21656`.
- Full text: City Research Online accepted manuscript,
  `https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf`.
- The complete 42-page manuscript was read end-to-end, including data,
  individual and combined strategies, robustness checks, references, tables,
  figures, and both appendices.
- The paper independently specifies the pure IVol strategy: rolling OLS
  residual standard deviation, low-IVol long/high-IVol short, monthly
  rebalance, and 1/3/6/12-month formation windows.
- Source packet: `strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`.
- Canonical card: `strategy-seeds/cards/energy-ivol_card.md`.
- Approved fleet card: `artifacts/cards_approved/QM5_13133_energy-ivol.md`.
- Card schema/ML lint: PASS.
- G0 readiness lint: PASS.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.

The source validates a broad exchange-futures cross-section. The EA narrows it
to four continuous CFD factor proxies and two traded energy legs. That is a Q02
kill risk, and no paper statistic is imported.

## Locked Mechanic

At the first tradable XTI D1 bar of a broker month:

1. Load 253 synchronized completed closes for XTI, XNG, XAU, and XAG.
2. Calculate 252 log returns and their equal-weight factor return.
3. Regress XTI and XNG separately on an intercept and that factor.
4. Compute residual standard deviation with 250 residual degrees of freedom.
5. Buy the lower-IVol energy leg and short the higher-IVol leg.
6. Split fixed stop risk in proportion to each leg's relative ATR stop, which
   targets equal dollar notional.
7. Reject broker-rounded lots if notional proxies differ by more than 20%.
8. Attach frozen `ATR(20) * 3.0` stops and no take-profit.
9. Close and renew next month, after 35 days, or on invalid/orphan composition.
10. Use current-month deal history to prevent restart or stop-out re-entry.

The factor, estimator, direction, formation window, notional target, and
monthly lifecycle are locked. The EA uses no momentum confirmation, RSI, price
ratio, z-score, carry/swap signal, external feed, banned indicator, or ML.

## Registry Evidence

- EA registry:
  `13133,energy-ivol,FUERTES-MOMIVOL-2015_XTI_XNG_S02,active`.
- Magic slot 0: `XTIUSD.DWX -> 131330000`.
- Magic slot 1: `XNGUSD.DWX -> 131330001`.
- `QM_MagicResolver.mqh` was regenerated with 14,848 rows and contains the new
  values; registry SHA256 is
  `97BF475A9B0F017B8FF7C148123BD1F8C1A6DCCC2F9708072B8C77F3FC9726A9`.

Resolver generation retained the repository's three pre-existing missing-
directory warnings for IDs `1001`, `1015`, and `1016`; no `13133` defect
remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13133_energy-ivol/QM5_13133_energy-ivol.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13133_energy-ivol/QM5_13133_energy-ivol.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_050001/QM5_13133_energy-ivol.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_050014.json`.
- SPEC validator: PASS.
- Guardrail validator: PASS.
- Symbol scope: `BASKET_OK`, 0 violations.
- MQ5 SHA256:
  `921556727ACFC8A508C9D933848E0271B73DEB49306BF7B54F9E093D7C800B48`.
- EX5 SHA256:
  `7A19953A6914E539983E0DDAC492595F5FBD610A1AFBD7821942D20C07FF5581`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13133_XTI_XNG_IVOL_D1`.
- Host: `XTIUSD.DWX`, D1.
- Traded symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Read-only factors: `XAUUSD.DWX`, `XAGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13133_energy-ivol/sets/QM5_13133_energy-ivol_QM5_13133_XTI_XNG_IVOL_D1_D1_backtest.set`.
- Setfile SHA256:
  `EC72623F51DBC9D1162879B9D5D94E53158B8E310CEC10CC2AD1DCB987D390EF`.
- Setfile build hash:
  `196ad989009dbd617d4ceff01909760054f88514d59b3777a1e08a277d07c02a`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly paired hold.

## Q02 Queue Evidence

- Build task: `a480301d-56c8-489e-bb2f-3594eacecec5` (`done`).
- Work item: `964d9d79-f9a6-40f8-9027-0efc7b01a394`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13133_XTI_XNG_IVOL_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Claimed by: none.
- Enqueued at: `2026-07-11T05:02:18+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two traded symbols, two read-only factor symbols, host
  `XTIUSD.DWX`, timeframe D1.

No manual smoke, backtest, terminal launch, dispatch tick, or worker tick was
started. The item was left pending for paced dispatch; this turn consumed no
backtest CPU.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate, gate threshold, portfolio KPI, or admission file changed.
