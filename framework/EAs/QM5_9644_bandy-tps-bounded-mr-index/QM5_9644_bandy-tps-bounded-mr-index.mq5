#property strict
#property version   "5.0"
#property description "QM5_9644 Bandy TPS Bounded Scale-In (Index, Long-Only)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_StdDev / QM_RSI / QM_MACD_Main /
//     QM_MACD_Signal / QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
//
// CARD-MANDATED DEVIATION (documented, not a corset violation): this EA has a
// non-trivial 3-slot bounded scale-in (card "Build-EA Notes"). The framework's
// default OnTick footer opens at the EA's FULL configured risk per fill; this
// card requires each of the 3 units to risk exactly 1/3 of that budget. The
// entry-open call in OnTick below therefore uses the explicit risk-mode/value
// QM_TM_OpenPosition(...) overload instead of the 2-arg default. Nothing else
// in the framework wiring is touched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9644;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
// NOTE: the card exempts unit-2/3 additions from the news blackout (only
// unit-1 is required to respect it); the framework's news gate is a single
// pre-entry check that cannot distinguish unit index, so it is applied
// uniformly here. This is strictly more conservative than the card (never
// riskier) and is documented in SPEC.md open_questions.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_zscore_lookback       = 20;
input double strategy_unit1_entry_z         = -2.0;
input double strategy_unit2_entry_z         = -2.5;
input double strategy_unit3_entry_z         = -3.0;
input double strategy_exit_z                = 0.0;
input int    strategy_regime_sma_period     = 200;
input int    strategy_atr_period            = 14;
input double strategy_catastrophic_atr_mult = 4.0;
input int    strategy_time_stop_days        = 10;
input int    strategy_unit_stale_days       = 15;
input int    strategy_vol_lookback_bars     = 252;
input double strategy_vol_percentile        = 99.0;

// -----------------------------------------------------------------------------
// Bounded scale-in state — persisted via GlobalVariable (restart-safe per the
// card's Build-EA Notes) and keyed per (ea_id*10000+slot) so multiple symbols
// running this EA on the same terminal never collide.
// -----------------------------------------------------------------------------

string Units_StateKeyPrefix()
  {
   return StringFormat("QM_9644_%d_", qm_ea_id * 10000 + qm_magic_slot_offset);
  }

int GetUnitsHeld()
  {
   const string key = Units_StateKeyPrefix() + "UNITS";
   if(!GlobalVariableCheck(key))
      return 0;
   return (int)MathRound(GlobalVariableGet(key));
  }

void SetUnitsHeld(const int units)
  {
   GlobalVariableSet(Units_StateKeyPrefix() + "UNITS", (double)units);
  }

datetime GetEntry1Time()
  {
   const string key = Units_StateKeyPrefix() + "E1TIME";
   if(!GlobalVariableCheck(key))
      return 0;
   return (datetime)GlobalVariableGet(key);
  }

double GetCatastrophicLevel()
  {
   const string key = Units_StateKeyPrefix() + "CATLVL";
   if(!GlobalVariableCheck(key))
      return 0.0;
   return GlobalVariableGet(key);
  }

void SetUnit1Anchor(const datetime t, const double catastrophic_level)
  {
   GlobalVariableSet(Units_StateKeyPrefix() + "E1TIME", (double)t);
   GlobalVariableSet(Units_StateKeyPrefix() + "CATLVL", catastrophic_level);
  }

void ResetUnitsState()
  {
   SetUnitsHeld(0);
   GlobalVariableSet(Units_StateKeyPrefix() + "E1TIME", 0.0);
   GlobalVariableSet(Units_StateKeyPrefix() + "CATLVL", 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// z = (close - SMA20) / StdDev20 on the last closed D1 bar.
bool ComputeZ(double &z_out, double &close_out)
  {
   if(strategy_zscore_lookback < 2)
      return false;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, closed_bar))
      return false;

   const double mean = QM_SMA(_Symbol, PERIOD_D1, strategy_zscore_lookback, 1, PRICE_CLOSE);
   const double sd = QM_StdDev(_Symbol, PERIOD_D1, strategy_zscore_lookback, 1, PRICE_CLOSE, MODE_SMA);
   if(closed_bar.close <= 0.0 || mean <= 0.0 || sd <= 0.0)
      return false;

   z_out = (closed_bar.close - mean) / sd;
   close_out = closed_bar.close;
   return true;
  }

// Vol-chaos guard (card "Zusätzliche Filter"): skip new entries (any unit) if
// ATR(14)/close sits in the top `strategy_vol_percentile` percentile over the
// last `strategy_vol_lookback_bars` closed D1 bars. Same bounded percentile-
// lookback pattern as QM_Mod_GrimesNestedPbV2 and the QM5_9641 sister card.
bool PassesVolChaosFilter()
  {
   if(strategy_vol_lookback_bars < 20)
      return true;

   double ratios[];
   ArrayResize(ratios, strategy_vol_lookback_bars);
   double current_ratio = 0.0;
   for(int i = 0; i < strategy_vol_lookback_bars; ++i)
     {
      MqlRates bar_i;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, i + 1, bar_i) || bar_i.close <= 0.0)
         return false;
      const double atr_i = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, i + 1);
      if(atr_i <= 0.0)
         return false;
      ratios[i] = atr_i / bar_i.close;
      if(i == 0)
         current_ratio = ratios[i];
     }
   ArraySort(ratios);
   int idx = (int)MathFloor((strategy_vol_percentile / 100.0) * (strategy_vol_lookback_bars - 1));
   if(idx < 0)
      idx = 0;
   if(idx >= strategy_vol_lookback_bars)
      idx = strategy_vol_lookback_bars - 1;
   return (current_ratio < ratios[idx]);
  }

// Trade Entry: evaluates the NEXT slot's z-score threshold (unit-1/2/3) gated
// by the SMA200 regime filter and vol-chaos guard. req.sl is always the
// catastrophic level anchored to unit-1's entry (fresh ATR-derived level when
// opening unit-1; the persisted level when adding unit-2/3) — this both sizes
// the position (via the framework's sl_points-based lot sizer) and becomes
// the real broker-side stop, so a single consistent stop always covers every
// unit without needing per-tick OrderModify synchronisation.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_zscore_lookback < 2 || strategy_regime_sma_period < 2 ||
      strategy_atr_period < 1 || strategy_catastrophic_atr_mult <= 0.0)
      return false;

   const int units_held = GetUnitsHeld();
   if(units_held < 0 || units_held >= 3)
      return false;

   double z = 0.0, close_px = 0.0;
   if(!ComputeZ(z, close_px))
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0 || close_px <= regime_sma)
      return false;

   double entry_threshold = strategy_unit1_entry_z;
   if(units_held == 1)
      entry_threshold = strategy_unit2_entry_z;
   else if(units_held == 2)
      entry_threshold = strategy_unit3_entry_z;
   if(z > entry_threshold)
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   double catastrophic_level = 0.0;
   if(units_held == 0)
     {
      const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr_now <= 0.0)
         return false;
      catastrophic_level = entry_price - strategy_catastrophic_atr_mult * atr_now;
     }
   else
     {
      const datetime entry1_time = GetEntry1Time();
      catastrophic_level = GetCatastrophicLevel();
      if(entry1_time <= 0 || catastrophic_level <= 0.0)
         return false; // scale-in state lost — do not add without a known unit-1 anchor

      const int held_days = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, entry1_time, TimeCurrent());
      if(held_days < 0 || held_days > strategy_unit_stale_days)
         return false;
     }

   if(catastrophic_level <= 0.0 || catastrophic_level >= entry_price)
      return false;

   if(!PassesVolChaosFilter())
      return false;

   req.sl = catastrophic_level;
   req.reason = StringFormat("BANDY_TPS_UNIT%d_LONG z=%.4f", units_held + 1, z);
   return true;
  }

// Trade Management: self-healing reconciliation only. The catastrophic stop
// is a real broker-side SL (set identically on every unit's order, per the
// entry hook above) so MT5 enforces it natively — no per-tick virtual check
// needed. If the persisted units_held disagrees with the broker's position
// count (TP/time-stop close, catastrophic stop-out, or a fresh backtest
// inheriting a stale GlobalVariable from a prior run), reset the scale-in
// state so the next signal starts a clean unit-1.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   if(GetUnitsHeld() > 0 && QM_TM_OpenPositionCount(magic) <= 0)
      ResetUnitsState();
  }

// Trade Close: evaluate only once per D1 calendar edge. Exit ALL units at the
// zero-line z-score take-profit or after the card's 10-trading-day time stop
// measured from unit-1's entry (regardless of when unit-2/3 were added).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return false;

   const datetime entry1_time = GetEntry1Time();
   if(strategy_time_stop_days > 0 && entry1_time > 0)
     {
      const int held_days = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, entry1_time, TimeCurrent());
      if(held_days >= strategy_time_stop_days)
         return true;
     }

   double z = 0.0, close_px = 0.0;
   if(!ComputeZ(z, close_px))
      return false;

   return (z >= strategy_exit_z);
  }

// News Filter Hook: no card-specific override. The framework's callable
// two-axis news gate (default ±30min pre/post high-impact) covers the card's
// unit-1 news blackout requirement (applied uniformly to all units — see the
// News input-group note above).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Called once a unit's order is confirmed filled. Anchors unit-1's time and
// catastrophic level for units 2/3 to reuse, and advances the slot counter.
void Strategy_OnUnitFilled(const double catastrophic_level)
  {
   const int units_held = GetUnitsHeld();
   if(units_held == 0)
      SetUnit1Anchor(TimeCurrent(), catastrophic_level);
   SetUnitsHeld(units_held + 1);
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
   if(Strategy_EntrySignal(req))
     {
      // CARD-MANDATED DEVIATION (see header comment): each of the 3 scale-in
      // units risks exactly 1/3 of the EA's configured risk budget, not the
      // full budget the 2-arg QM_TM_OpenPosition default would apply.
      ulong out_ticket = 0;
      const bool use_percent = (RISK_PERCENT > 0.0);
      const QM_RiskMode unit_mode = use_percent ? QM_RISK_MODE_PERCENT : QM_RISK_MODE_FIXED;
      const double unit_value = use_percent ? (RISK_PERCENT / 3.0) : (RISK_FIXED / 3.0);
      if(QM_TM_OpenPosition(req, out_ticket, 0, unit_mode, unit_value))
         Strategy_OnUnitFilled(req.sl);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
