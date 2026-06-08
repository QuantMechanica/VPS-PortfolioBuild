#property strict
#property version   "5.0"
#property description "QM5_11270 qt-bb-w"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  -- closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        -- risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() -- use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly --
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11270;
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
// FW1 2026-05-23 -- Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 -- only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period              = 20;
input double strategy_bb_deviation           = 2.0;
input int    strategy_pattern_horizon        = 75;
input double strategy_alpha_atr              = 0.10;
input double strategy_beta_atr               = 0.10;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 2.0;
input double strategy_structural_sl_atr_mult = 0.25;
input int    strategy_time_stop_bars         = 30;
input double strategy_spread_stop_fraction   = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks -- implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_CalcBands(const MqlRates &rates[],
                        const int shift,
                        const int period,
                        const double deviation,
                        double &mid,
                        double &stddev,
                        double &upper,
                        double &lower)
  {
   if(period < 2 || shift < 0 || shift + period > ArraySize(rates))
      return false;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double price = rates[shift + i].close;
      if(price <= 0.0)
         return false;
      sum += price;
     }

   mid = sum / (double)period;

   double variance = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double delta = rates[shift + i].close - mid;
      variance += delta * delta;
     }

   stddev = MathSqrt(variance / (double)period);
   upper = mid + deviation * stddev;
   lower = mid - deviation * stddev;
   return true;
  }

bool Strategy_LoadPatternRates(MqlRates &rates[])
  {
   const int horizon = MathMax(strategy_pattern_horizon, 5);
   const int bars_needed = horizon + MathMax(strategy_bb_period, 2) + 5;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates); // perf-allowed closed-bar pattern window; Strategy_EntrySignal is called after QM_IsNewBar().
   return (copied >= bars_needed);
  }

bool Strategy_FindBottomW(const MqlRates &rates[],
                          const int max_shift,
                          const double atr,
                          double &second_bottom)
  {
   second_bottom = 0.0;
   if(max_shift < 6 || atr <= 0.0)
      return false;

   const double alpha = strategy_alpha_atr * atr;
   double mid[], stddev[], upper[], lower[];
   ArrayResize(mid, max_shift + 1);
   ArrayResize(stddev, max_shift + 1);
   ArrayResize(upper, max_shift + 1);
   ArrayResize(lower, max_shift + 1);

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      if(!Strategy_CalcBands(rates, shift, strategy_bb_period, strategy_bb_deviation,
                             mid[shift], stddev[shift], upper[shift], lower[shift]))
         return false;
     }

   const double current_price = rates[1].close;
   if(current_price <= upper[1])
      return false;

   for(int second_shift = 2; second_shift <= max_shift - 3; ++second_shift)
     {
      const double second_price = rates[second_shift].close;
      if(second_price < lower[second_shift] || second_price > lower[second_shift] + alpha)
         continue;

      int above_shift = -1;
      for(int s = second_shift + 1; s <= max_shift - 2; ++s)
        {
         if(rates[s].close > mid[s])
           {
            above_shift = s;
            break;
           }
        }
      if(above_shift < 0)
         continue;

      int middle_shift = -1;
      for(int s = above_shift + 1; s <= max_shift - 1; ++s)
        {
         if(MathAbs(rates[s].close - mid[s]) <= alpha)
           {
            middle_shift = s;
            break;
           }
        }
      if(middle_shift < 0)
         continue;

      for(int first_shift = middle_shift + 1; first_shift <= max_shift; ++first_shift)
        {
         const double first_price = rates[first_shift].close;
         if(MathAbs(first_price - lower[first_shift]) > alpha)
            continue;
         if(second_price <= first_price)
            continue;
         if(second_price > first_price + alpha)
            continue;

         second_bottom = second_price;
         return true;
        }
     }

   return false;
  }

bool Strategy_SpreadTooWide()
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return true;

   const double planned_stop = strategy_atr_sl_mult * atr;
   if(planned_stop <= 0.0)
      return true;

   return ((ask - bid) > strategy_spread_stop_fraction * planned_stop);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only -- runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return Strategy_SpreadTooWide();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period < 2 || strategy_pattern_horizon < 5 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_alpha_atr <= 0.0 || strategy_beta_atr <= 0.0)
      return false;

   MqlRates rates[];
   if(!Strategy_LoadPatternRates(rates))
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int max_shift = MathMin(strategy_pattern_horizon,
                                 ArraySize(rates) - strategy_bb_period - 1);
   double second_bottom = 0.0;
   if(!Strategy_FindBottomW(rates, max_shift, atr, second_bottom))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr_stop = ask - strategy_atr_sl_mult * atr;
   const double structural_stop = second_bottom - strategy_structural_sl_atr_mult * atr;
   double sl = atr_stop;
   if(structural_stop > atr_stop && structural_stop < ask)
      sl = structural_stop;

   if(sl <= 0.0 || sl >= ask)
      return false;

   req.sl = sl;
   req.reason = "QT_BB_BOTTOM_W_LONG";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double stddev = QM_StdDev(_Symbol, _Period, strategy_bb_period, 1, PRICE_CLOSE, MODE_SMA);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const bool contraction_exit = (stddev > 0.0 && atr > 0.0 && stddev < strategy_beta_atr * atr);

   const int seconds_per_bar = PeriodSeconds(_Period);
   const int max_hold_seconds = strategy_time_stop_bars * seconds_per_bar;
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(contraction_exit)
         return true;

      if(max_hold_seconds > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && now - opened >= max_hold_seconds)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring -- do NOT edit below this line unless you know why.
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 -- 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   // per-tick recompute mistakes -- EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 -- emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
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
