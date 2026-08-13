# Market intraday momentum card-draft evidence

Date: 2026-08-13  
Router task: `75e821e0-2105-4221-975a-f5ddd5afaf67`

The draft is a bounded extraction of candidate #2 from `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md`, which records the OWNER 2026-08-13 ultracode directive. It retains the first-hour-to-last-hour direction, ATR normalization, volatility floor, DST-aware cash-session clock, and mandatory end-of-day flatten. The implementation timeframe is fixed to M30 so the first and final cash hours can be represented without half-hour ambiguity; H1 remains the signal-normalization timeframe.

Traceability source: Gao, Han, Li and Zhou (2018), “Market Intraday Momentum,” *Journal of Financial Economics* 129(2). The card adds only framework-required risk, news, and fail-closed controls. It does not assert a G0 or pipeline verdict and deliberately uses a unique pending-allocation identity until post-review deterministic EA-ID reservation.

Artifact: `D:/QM/strategy_farm/artifacts/cards_review/PENDING_75E821E0_market-intraday-momentum.md`.
