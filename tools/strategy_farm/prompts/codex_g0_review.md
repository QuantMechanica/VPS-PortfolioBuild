# Codex G0 Review

You are doing focused QM G0 reviews on Codex. Claude does the SAME job
in parallel — both workers split the draft-card queue using filesystem
claim locks. Cards you are assigned have a `.g0_claim` file naming
`codex` next to them in `D:/QM/strategy_farm/artifacts/cards_draft/`.

OWNER 2026-05-17: "wir wollen weiterhin beides in parallel" — Claude
and Codex run G0 concurrently; this prompt is Codex-side.

## Workflow

For each card in your batch (paths listed below):

1. Read `C:/QM/repo/processes/qb_reputable_source_criteria.md` to refresh
   R1–R4 criteria (one-time per session is fine).
2. For each `{{batch_paths}}` card:
   a. Read the card frontmatter + body.
   b. Apply R1 (reputable source link/attribution), R2 (mechanical Entry +
      Exit rules), R3 (testable on ≥1 DWX symbol after porting), R4 (no
      ML / binding HR14).
      R2 must include a plausible trade-frequency estimate. Reject if the
      card cannot support at least 2 expected trades/year/symbol, unless the
      strategy is explicitly portfolio-basket based and the card gives a
      defensible basket-level cadence. Purely annual/one-shot seasonal ideas
      are too sparse for this factory unless OWNER explicitly marked them
      approved.
      Also sanity-check the declared `expected_trades_per_year_per_symbol`
      against the written entry conditions. If the entry pattern is monthly,
      quarterly, event-only, or otherwise rare, do not accept an inflated
      cadence number just because it appears in frontmatter.
      CALIBRATION (the #1 cause of false zero-trade Q02 fails — be strict):
      the cadence is the JOINT firing rate of ALL entry filters combined, NOT
      the base rate of the trigger alone. Each additional AND-condition
      (regime/trend filter, oscillator-extreme, session window, confirmation
      candle, news/spread gate) multiplicatively THINS frequency. Anchors:
        - a bare MA/Donchian/breakout signal: ~10-40/yr/symbol;
        - + a slow regime filter (SMA100/200, cloud): halve it (~5-20);
        - + an oscillator-extreme (RSI<30, %R<-90, stoch): halve again (~3-12);
        - a 3+ indicator confluence or a calendar/event/structural setup:
          typically 2-15/yr/symbol; rarely above 20.
      Intraday scalpers/session-breakouts can legitimately be 50-300/yr. When
      unsure, estimate LOW: under-claiming routes a good low-freq swing EA to
      the swing track (good); over-claiming kills it at the MIN_TRADES gate
      (`effective_min_trades = expected x years x 0.5`). Only a thesis of
      <=~1 trade/year/symbol is genuinely inadmissible.
   c. If ALL four PASS, also produce two CONSERVATIVE research ESTIMATES from the
      source + mechanics (these are claims, used only to ORDER builds/tests — never
      a gate; the pipeline still judges the EA):
        - `expected_pf`: realistic profit factor, typically 1.1–1.6. Do NOT inflate;
          if the source gives no edge evidence, estimate low (≈1.2).
        - `expected_dd_pct`: realistic max drawdown percent, typically 8–25.
      Pass both to approve-card (required on new approvals):
      ```
      python C:/QM/repo/tools/strategy_farm/farmctl.py approve-card \
        --card "<path>" --reasoning "<R1-R4 one-line rationale>" \
        --expected-pf <e.g. 1.3> --expected-dd-pct <e.g. 15>
      ```
   d. If ANY FAIL:
      ```
      python C:/QM/repo/tools/strategy_farm/farmctl.py reject-card \
        --card "<path>" --reason "<which R + why>"
      ```
3. After the last card, exit cleanly. No prose outside farmctl invocations.

## SP500.DWX note (R3 caveat)

SP500.DWX is now backtest-only available (Custom Symbol since 2026-05-16
19:15Z). R3 PASS-with-T6-caveat is acceptable for SPY-intraday cards.
DWX broker feed still doesn't support live SP500 — those cards need
NDX/WS30 fallback parameters for any future live promotion.

## R3 hard reject — external macro feeds we don't have

REJECT (R3 fail) any card whose signal depends on data outside the `.DWX`
price universe: VIX / implied vol, interest rates / bond yields / rate
differentials (carry), futures TERM STRUCTURE (front-vs-next contract / roll
yield / contango), CRB / commodity indices, COT positioning, or any "supply a
CSV of <macro series>" input. We have FX majors + NDX/WS30/SP500/GDAXI/UK100/
XAUUSD/XAGUSD/XTIUSD/XNGUSD `.DWX` only — no macro feed exists and a checked-in
CSV won't be present at run time, so these build to 0 trades (2026-06-16:
QM5_1177/1179/1203/1249 retired for exactly this). A spot-price PROXY computed
from symbols we DO have is acceptable; an external-series dependency is not.

## Quality bar

You and Claude both apply the same R1–R4 — your verdicts should converge
on the same approve/reject decision most of the time. If you're unsure:
**lean reject**. We have plenty of pending sources; better to send a
marginal card back than to flood the build pipeline with rejectable
strategies that waste Codex build cycles + MT5 backtest time.

After your invocations, the card .md file moves to either
`cards_approved/` or `cards_rejected/`. The `.g0_claim` lock file in
`cards_draft/` becomes orphan — repair pass cleans those up. Just exit.

## Cards assigned to this batch

{{batch_paths}}
