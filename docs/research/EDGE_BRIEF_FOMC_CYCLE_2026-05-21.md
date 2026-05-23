# Edge Brief: FOMC Cycle Equity Risk Premium

Date: 2026-05-21
Status: priority research candidate, queued for Codex build as `QM5_10260_cieslak-fomc-cycle-idx`

## Thesis

The strongest near-term alpha candidate in the current QM universe is not another indicator stack. It is scheduled Federal Reserve event-cycle exposure on U.S. equity indices:

- Long U.S. index exposure during even weeks of the FOMC cycle.
- Universe: `NDX.DWX`, `WS30.DWX`, `SP500.DWX` for backtest; live promotion only through routable symbols (`NDX.DWX`, `WS30.DWX`) unless OWNER separately approves a proxy policy.
- Mechanism: macro uncertainty premium / Fed communication cycle, not price-pattern fitting.

## Why This Deserves Priority

This edge has three properties that many current backlog ideas do not:

1. Published, peer-reviewed support.
2. Deterministic calendar implementation.
3. Strong fit to the upgraded QM pipeline, especially real news replay and crisis slicing.

The FOMC-cycle paper by Cieslak, Morse, and Vissing-Jorgensen reports that, since 1994, the U.S. equity premium is concentrated in even FOMC-cycle weeks. CFA Institute's Journal Review summarizes the Journal of Finance paper and reports that an even-week strategy doubled the buy-and-hold Sharpe in their sample. The Oxford Review of Finance paper by Brusa, Savor, and Wilson supports the broader claim that the Fed has a unique effect on global equities around FOMC meetings.

## Key Sources

- Cieslak, Morse, Vissing-Jorgensen, "Stock Returns over the FOMC Cycle", Journal of Finance 2019, DOI 10.1111/jofi.12818. Summary: https://rpc.cfainstitute.org/research/cfa-digest/2020/05/dig-v50-n5-2
- Working paper PDF: https://www.stern.nyu.edu/sites/default/files/assets/documents/cycle_paper_cieslak_morse_vissingjorgensen.pdf
- Brusa, Savor, Wilson, "One Central Bank to Rule Them All", Review of Finance 2020. Oxford record: https://ora.ox.ac.uk/objects/uuid%3A61ef4010-7f35-40e2-abbf-f1d6db4a010b
- Lucca, Moench, "The Pre-FOMC Announcement Drift", FRBNY Staff Report 512: https://www.newyorkfed.org/research/economists/medialibrary/media/research/staff_reports/sr512.pdf
- Kurov, Wolfe, Gilbert, "The Disappearing Pre-FOMC Announcement Drift", Finance Research Letters 2021: https://pmc.ncbi.nlm.nih.gov/articles/PMC7525326/

## Critical Caveat

The narrow 24-hour pre-FOMC drift is not enough. Later research finds that the pre-FOMC drift weakened or disappeared after 2015. That makes `QM5_1213` and `QM5_1094` interesting but not the best primary bet.

The stronger candidate is the broader FOMC-cycle structure (`QM5_10260`), because it tests the full even-week risk-premium pattern instead of relying on the decayed 24-hour window only.

## Pipeline Plan

1. Build `QM5_10260_cieslak-fomc-cycle-idx` with embedded scheduled FOMC calendar.
2. Run strict Codex review, then P2 across `NDX.DWX`, `WS30.DWX`, `SP500.DWX`.
3. Promotion criteria remain normal: P2 profitable, P3/P3.5/P4 real walk-forward, P5/P5b/P5c stress, P6/P7/P8.
4. Require P8 real-news replay to prove the EA handles FOMC/news exposure deliberately, not accidentally.
5. If `SP500.DWX` is the only survivor, mark as research-only until routable proxy validation passes on `NDX.DWX` or `WS30.DWX`.

## Current Action

- `QM5_1160` duplicate ID was detected. Registry assigns `QM5_1160` to `qp-gold-christmas-drift`.
- New ID reserved: `QM5_10260` for `cieslak-fomc-cycle-idx`.
- Strategy Card moved to `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10260_cieslak-fomc-cycle-idx.md`.
- Codex build task queued: `5e9cdbad-f70d-46ab-89de-f0f2d80b3673`.
