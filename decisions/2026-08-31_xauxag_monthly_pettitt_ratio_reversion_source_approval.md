# XAU/XAG Monthly Pettitt Ratio Reversion - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
expressly offers an `XAUUSD`/`XAGUSD` market-neutral-style basket, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mpettitt-rv`
- proposed strategy ID:
  `SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade one unique central Pettitt rank-sum change point in thirteen
  synchronized completed monthly gold-minus-silver log-ratio endpoints

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   It preserves Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and official CME Group
   gold/silver ratio-spread carrier research. The evidence supports a related
   but state-dependent gold/silver relation and distinct metal demand drivers;
   it does not establish one constant equilibrium or universal reversion.
2. `strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256
   `A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98`.
   It preserves A. N. Pettitt's named 1979 peer-reviewed method record and
   complete pinned CRAN `trend` 1.1.7 method files at public mirror commit
   `d0ec3cf8b99b4f3226f5211f592955b85565721d`. The exact method ranks the
   complete observations, calculates every cumulative rank sum, and locates
   every split attaining the maximum absolute value. The original article
   body remains outside the complete-read claim.
3. `strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`,
   SHA-256
   `4919B9F71CEAA0D38FF22117A7E1AEBB419022B096FDFCD022D5311187A002B1`.
   This completely read governed port records the exact synchronized
   two-carrier Pettitt arithmetic, atomic lifecycle, and translation limits.
   Its oil/gas relation, carrier evidence, and performance boundary do not
   transfer.
4. The governed composite packet
   `strategy-seeds/sources/SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026/source.md`.

The records support a falsifiable paired-metal change-point experiment and
the exact non-parametric statistic, not the proposed trading conjunction.
The thirteen endpoints, central split band, contrarian direction,
synchronized CFD mapping, equal-target-notional construction, aggregate
fixed-dollar risk, stops, atomicity, consumed attempt, and lifecycle are
disclosed QM choices.

No source return, alpha, probability, significance, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, decorrelation,
or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XAU/XAG D1 close pair in
   each of the thirteen immediately prior consecutive completed broker
   months; reject malformed, stale, nonpositive, nonfinite, or tied log-ratio
   history.
3. Form chronological `s[i]=ln(XAU[i])-ln(XAG[i])`, assign strict ranks
   `R[i]` from 1 through 13, and calculate
   `U[k]=2*sum(R[0..k-1])-14*k` for every `k=1..12`. Require one and only one
   split attaining `U*=max(abs(U[k]))`, require `4<=K<=9`, and prove the
   permutation, range, parity, and unique-maximum invariants.
4. If `U[K]<0`, SELL XAU and BUY XAG because the later gold/silver ratio
   regime ranks higher. If `U[K]>0`, BUY XAU and SELL XAG because the later
   ratio regime ranks lower. Otherwise consume the month flat. No p-value,
   fitted hedge ratio, rolling center, scale, endpoint fallback, or magnitude
   sizing exists.
5. Open at most one opposite-side, equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and use frozen
   `3.5*ATR(20,D1)` hard stops, no targets, and bounded spreads.
6. Submit XAU first and XAG second, retain only a complete valid package,
   close at the next broker-month transition or after forty calendar days,
   and repair orphaned or malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. No significance
threshold is imported. The uniqueness rule and central split band were fixed
before market testing as density and lifecycle choices.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK`: named peer-reviewed
  gold/silver relation evidence, official exchange carrier research, a named
  peer-reviewed Pettitt record, complete pinned CRAN method files, and a
  completely read governed two-carrier arithmetic precedent. The exact
  trading conjunction remains untested.
- R2 `PASS`: clock, synchronization, ratio orientation, strict ranks, every
  cumulative sum, unique central split, contrarian sides, attempt, aggregate
  risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories plus MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, ranks, integer arithmetic,
  calendar, ATR, and execution state only; no trained output, banned signal
  method, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,747 EA-registry rows, 1,385 card
files, and 45 Strategy Wiki nodes. It found no exact identity and surfaced two
expected fuzzy neighbors. Evidence is
`artifacts/qm5_xauxag_mpettitt_rv_preallocation_dedup_20260831.json`, SHA-256
`86E98E01358C6CCA8B016DBDE45E4D206C49BEAB0A4672496E057321830E1FF9`.

Manual functional review fixes a different carrier or state object:

- `QM5_41175_xtixng-mpettitt-rv` applies the same statistic to the oil/gas
  ratio under different government and peer-reviewed relationship evidence.
  It owns XTI/XNG exposure. This candidate owns the economically different
  gold/silver monetary-versus-industrial spread expressly named by the OWNER.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` uses the same metal carrier but fixes
  one six-older/six-newer split and compares its 36 cross-block pairs against
  `U_new` thresholds. This candidate ranks thirteen endpoints, evaluates all
  twelve split points, and trades only one unique central maximizing split.
- `QM5_41247_xauxag-mcusum-rv` mean-centers twelve adjacent relative returns
  and scans eleven real-valued cumulative sums. This candidate consumes
  thirteen ratio levels, uses only strict ordinal ranks, never centers returns,
  and is invariant to ratio magnitudes that preserve rank order.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  calendar, path, flow, and other robust-rank families calculate different
  state objects, gates, or lifecycles.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal change-point basket.

Verdict:
`CLEAN_XAUXAG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any endpoint,
rank, split, side, attempt, risk, atomicity, or lifecycle defect.

Equal target notionals reduce common outright-metal direction but do not
prove beta, factor, market, dollar, volatility, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. No failed result may be rescued by
changing the sample, rank rule, central band, direction, hedge construction,
risk, hold, or by adding a filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
