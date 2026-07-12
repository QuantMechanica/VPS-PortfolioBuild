# PAPAILIAS-RSM-2021 — Return Signal Momentum

## Approval And Source Identity

- Mission approvals: OWNER-directed commodity/energy sleeves on 2026-07-10
  (XNG extraction) and 2026-07-12 (WTI extraction).
- Source type: peer-reviewed paper.
- Citation: Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
  "Return Signal Momentum," *Journal of Banking & Finance* 124, Article
  106063. DOI: `10.1016/j.jbankfin.2021.106063`.
- Published record: https://doi.org/10.1016/j.jbankfin.2021.106063
- Peer-reviewed accepted manuscript:
  https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf
- Full-read evidence: accepted manuscript read end-to-end, including Appendices
  A-I and individual-instrument Tables G.1-G.3, on 2026-07-10.

## Source Scope

The paper studies 55 liquid futures from January 1985 through March 2015,
including 24 commodity futures. Natural gas and WTI are explicit members of the
commodity panel (Table 1 and Appendix C, Table C.1). The data are converted from
daily excess-return series to monthly returns. The main signal uses a 12-month
lookback, rebalances monthly, and holds each renewed position for one month
(Sections 2.1 and 4).

## Mechanical Extraction

For instrument `s` at month `t`:

1. Convert each of the prior 12 completed monthly returns to a binary sign:
   `v_i = 1` for a non-negative return and `0` for a negative return.
2. Estimate positive-sign probability with the equal-weight mean:
   `P = sum(v_i) / 12` (Equation 7 and Section 4.1).
3. With fixed threshold `q=0.4`, hold long when `P >= q`; otherwise hold short
   (Equation 10 and Section 4.2).
4. Renew the signal monthly and hold for one month (Section 4 and footnote 19).
5. Scale exposure by ex-ante volatility in the source portfolio (Section 2.2 and
   Equation 11). The V5 carrier maps this to a fixed dollar risk budget and a
   frozen ATR hard stop; it does not copy the paper's 40% portfolio-volatility
   target.

The fixed threshold is selected because it is the source's best reported
portfolio variant, not through a QM data sweep. The adaptive cross-validation
threshold in Section 4.3 is deliberately excluded: it would add unnecessary
parameter adaptation and a different strategy.

## Evidence Relevant To XNG

- Table 1 reports natural gas as an explicit commodity future and the most
  volatile individual series in the panel.
- Table 2 reports a materially larger persistence advantage for the natural-gas
  sign signal than for conventional magnitude-based time-series momentum.
- Tables G.1 and G.2 report positive natural-gas results for the fixed-threshold
  RSM variants, including `q=0.4`.
- These are futures results, not validation of the Darwinex continuous CFD
  carrier. Q02 must independently determine trade count and economics.

## Evidence Relevant To WTI

- Table 1 and Appendix C Table C.1 explicitly include WTI futures, beginning
  with the CL1 series.
- Individual-instrument Table G.1 reports annualised mean return of 0.113 for
  WTI RSM0.4 versus 0.093 for conventional TSM in the source sample.
- Individual-instrument Table G.2 reports a WTI RSM0.4 Sharpe ratio of 0.302
  versus 0.247 for conventional TSM.
- Table G.3 is an adverse boundary, not supporting evidence: WTI RSM0.4 has a
  larger reported maximum drawdown than TSM. The V5 card therefore carries a
  low prior and leaves all efficacy, drawdown, cost, and correlation claims to
  the pipeline.
- These are rolled-futures results. They do not validate the Darwinex
  continuous CFD, its financing/roll construction, or the V5 ATR-stop overlay.

## Author Claim Boundary

The paper states: "A new type of momentum based on the signs of past returns is
introduced." (abstract, manuscript page 1). No portfolio-level or
individual-natural-gas performance number is imported as a V5 expectation.

## Extraction Verdict

Two symbol-specific strategies are extracted across the two bounded OWNER
missions:

- `PAPAILIAS-RSM-2021_XNG_S01`: monthly XNG return-sign momentum with a fixed
  12-month sign-probability signal and one-month holding period.
- `PAPAILIAS-RSM-2021_XTI_S02`: monthly WTI return-sign momentum with the same
  source-defined fixed 12-month sign-probability signal and one-month holding
  period. This is a WTI source-panel extraction, not a claim that changing the
  carrier creates a new statistical anomaly.

The source also describes a time-varying threshold and many cross-asset
portfolio variants. They are not extracted here because each mission is
bounded to one concrete commodity edge and the two fixed-threshold carriers are
complete.
