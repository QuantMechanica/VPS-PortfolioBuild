"""Continuous book recomposition engine (Phase E, OWNER-DEC-CBE-20260915).

A thin, deterministic composition over the existing portfolio primitives
(``portfolio_common``, ``portfolio_kpi``, ``book_builder_common``,
``portfolio_correlation``, ``portfolio_montecarlo``).  It ingests a frozen input
snapshot (``frozen_snapshot.py``) and emits the section 58 per-venue output object
(``decide.py``) with the section 7 marginal-contribution metric set (``metrics.py``),
the section 57 venue fitness (``dxz_fitness.py`` / ``venue_fitness.py``), portfolio
alternatives (``alternatives.py``) and the section 59 materiality / anti-churn
predicate (``materiality.py``).

Directive: docs/ops/CONTINUOUS_BOOK_EVOLUTION.md (sections 5-9, 57-59, 70).
The engine never writes to the farm DB, never deploys, and never toggles AutoTrading;
its output is a recommendation package for OWNER review.
"""
