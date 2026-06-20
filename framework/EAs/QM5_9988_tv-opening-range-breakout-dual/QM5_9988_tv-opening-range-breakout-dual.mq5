#property strict
#property version   "5.0"
#property description "QM5_9988 TradingView dual opening-range breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// -----------------------------------------------------------------------------
// The five Strategy_* hooks below contain the card logic. Everything else is
// framework boilerplate that MUST stay intact (OnInit/OnTick wiring, framework
// lifecycle, risk + magic + news + Friday-close guard rails).
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// Registry changes are propagated through framework/scripts/update_magic_resolver.py.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9988;
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
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input bool   strategy_use_symbol_session_defaults = true;
input int    strategy_or1_start_hhmm    = 800;
input int    strategy_or1_end_hhmm      = 830;
input int    strategy_or2_start_hhmm    = 800;
input int    strategy_or2_end_hhmm      = 900;
input int    strategy_session_end_hhmm  = 2100;
input bool   strategy_enable_long_or1   = true;
input bool   strategy_enable_short_or1  = true;
input bool   strategy_enable_long_or2   = true;
input bool   strategy_enable_short_or2  = true;
input int    strategy_sl_mode           = 1;      // 0=fixed pips, 1=OR range multiple, 2=ATR multiple
input int    strategy_tp_mode           = 1;      // 0=fixed pips, 1=OR range multiple, 2=ATR multiple
input int    strategy_fixed_sl_pips     = 50;
input int    strategy_fixed_tp_pips     = 100;
input int    strategy_atr_period        = 14;
input double strategy_sl_range_mult     = 0.5;
input double strategy_tp_range_mult     = 1.0;
input double strategy_sl_atr_mult       = 1.0;
input double strategy_tp_atr_mult       = 2.0;
input double strategy_flat_or_atr_mult  = 0.3;
input double strategy_spread_sl_mult    = 0.3;
input int    strategy_max_concurrent_per_symbol = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;
   if(strategy_or1_start_hhmm < 0 || strategy_or1_start_hhmm > 2359 ||
      strategy_or1_end_hhmm < 0 || strategy_or1_end_hhmm > 2359 ||
      strategy_or2_start_hhmm < 0 || strategy_or2_start_hhmm > 2359 ||
      strategy_or2_end_hhmm < 0 || strategy_or2_end_hhmm > 2359 ||
      strategy_session_end_hhmm < 0 || strategy_session_end_hhmm > 2359)
      return true;
   if(!strategy_use_symbol_session_defaults &&
      strategy_or2_end_hhmm <= strategy_or1_end_hhmm)
      return true;
   if(strategy_atr_period <= 0 ||
      strategy_sl_range_mult <= 0.0 ||
      strategy_tp_range_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0)
      return true;
   return false;
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

   int or1_start = strategy_or1_start_hhmm;
   int or1_end = strategy_or1_end_hhmm;
   int or2_start = strategy_or2_start_hhmm;
   int or2_end = strategy_or2_end_hhmm;
   int session_end = strategy_session_end_hhmm;
   if(strategy_use_symbol_session_defaults)
     {
      if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" ||
         _Symbol == "SP500.DWX" || _Symbol == "XTIUSD.DWX")
        {
         or1_start = 1630;
         or1_end = 1645;
         or2_start = 1630;
         or2_end = 1700;
         session_end = 2300;
        }
      else
        {
         or1_start = 800;
         or1_end = 830;
         or2_start = 800;
         or2_end = 900;
         session_end = 2100;
        }
     }
   if(or2_end <= or1_end)
      return false;

   // perf-allowed: ORB needs the last closed bar's OHLC/time; this hook is
   // called only after the framework's single QM_IsNewBar() gate.
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, bar) != 1)
      return false;
   if(bar[0].time <= 0 || bar[0].high <= 0.0 || bar[0].low <= 0.0 || bar[0].close <= 0.0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar[0].time, dt);
   const int day_key = dt.year * 1000 + dt.day_of_year;
   const int bar_hhmm = dt.hour * 100 + dt.min;

   static int state_day_key = -1;
   static double or1_high = 0.0;
   static double or1_low = 0.0;
   static double or2_high = 0.0;
   static double or2_low = 0.0;
   static bool or1_has_range = false;
   static bool or2_has_range = false;
   static bool or1_armed_long = true;
   static bool or1_armed_short = true;
   static bool or2_armed_long = true;
   static bool or2_armed_short = true;

   if(day_key != state_day_key)
     {
      state_day_key = day_key;
      or1_high = 0.0;
      or1_low = 0.0;
      or2_high = 0.0;
      or2_low = 0.0;
      or1_has_range = false;
      or2_has_range = false;
      or1_armed_long = true;
      or1_armed_short = true;
      or2_armed_long = true;
      or2_armed_short = true;
     }

   if(bar_hhmm >= or1_start && bar_hhmm < or1_end)
     {
      if(!or1_has_range)
        {
         or1_high = bar[0].high;
         or1_low = bar[0].low;
         or1_has_range = true;
        }
      else
        {
         or1_high = MathMax(or1_high, bar[0].high);
         or1_low = MathMin(or1_low, bar[0].low);
        }
     }

   if(bar_hhmm >= or2_start && bar_hhmm < or2_end)
     {
      if(!or2_has_range)
        {
         or2_high = bar[0].high;
         or2_low = bar[0].low;
         or2_has_range = true;
        }
      else
        {
         or2_high = MathMax(or2_high, bar[0].high);
         or2_low = MathMin(or2_low, bar[0].low);
        }
     }

   if(bar_hhmm < or1_end || bar_hhmm >= session_end)
      return false;

   if(strategy_max_concurrent_per_symbol > 0)
     {
      int open_count = 0;
      for(int slot_offset = 0; slot_offset < 4; ++slot_offset)
         open_count += QM_TM_OpenPositionCount(QM_Magic(qm_ea_id, qm_magic_slot_offset + slot_offset));
      if(open_count >= strategy_max_concurrent_per_symbol)
         return false;
     }

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int selected_slot_offset = -1;
   QM_OrderType selected_type = QM_BUY;
   double selected_range = 0.0;
   string selected_reason = "";

   if(or1_has_range && bar_hhmm >= or1_end)
     {
      const double range1 = or1_high - or1_low;
      if(range1 >= strategy_flat_or_atr_mult * atr)
        {
         if(strategy_enable_long_or1 && or1_armed_long && bar[0].close > or1_high)
           {
            selected_slot_offset = 0;
            selected_type = QM_BUY;
            selected_range = range1;
            selected_reason = "OR1_LONG_CLOSE_BREAK";
           }
         else if(strategy_enable_short_or1 && or1_armed_short && bar[0].close < or1_low)
           {
            selected_slot_offset = 1;
            selected_type = QM_SELL;
            selected_range = range1;
            selected_reason = "OR1_SHORT_CLOSE_BREAK";
           }
        }
     }

   if(selected_slot_offset < 0 && or2_has_range && bar_hhmm >= or2_end)
     {
      const double range2 = or2_high - or2_low;
      if(range2 >= strategy_flat_or_atr_mult * atr)
        {
         if(strategy_enable_long_or2 && or2_armed_long && bar[0].close > or2_high)
           {
            selected_slot_offset = 2;
            selected_type = QM_BUY;
            selected_range = range2;
            selected_reason = "OR2_LONG_CLOSE_BREAK";
           }
         else if(strategy_enable_short_or2 && or2_armed_short && bar[0].close < or2_low)
           {
            selected_slot_offset = 3;
            selected_type = QM_SELL;
            selected_range = range2;
            selected_reason = "OR2_SHORT_CLOSE_BREAK";
           }
        }
     }

   if(selected_slot_offset < 0 || selected_range <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double entry_price = QM_OrderTypeIsBuy(selected_type) ? ask : bid;

   double sl_distance = 0.0;
   if(strategy_sl_mode == 0)
      sl_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fixed_sl_pips);
   else if(strategy_sl_mode == 2)
      sl_distance = atr * strategy_sl_atr_mult;
   else
      sl_distance = selected_range * strategy_sl_range_mult;
   if(sl_distance <= 0.0)
      return false;

   double tp_distance = 0.0;
   if(strategy_tp_mode == 0)
      tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fixed_tp_pips);
   else if(strategy_tp_mode == 2)
      tp_distance = atr * strategy_tp_atr_mult;
   else
      tp_distance = selected_range * strategy_tp_range_mult;
   if(tp_distance <= 0.0)
      return false;

   const double modeled_spread = (ask > bid) ? (ask - bid) : 0.0;
   if(modeled_spread > strategy_spread_sl_mult * sl_distance)
      return false;

   req.type = selected_type;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, selected_type, entry_price, sl_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, selected_type, entry_price, tp_distance);
   req.reason = selected_reason;
   req.symbol_slot = qm_magic_slot_offset + selected_slot_offset;
   req.expiration_seconds = 0;
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   if(selected_slot_offset == 0)
      or1_armed_long = false;
   else if(selected_slot_offset == 1)
      or1_armed_short = false;
   else if(selected_slot_offset == 2)
      or2_armed_long = false;
   else if(selected_slot_offset == 3)
      or2_armed_short = false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   int session_end = strategy_session_end_hhmm;
   if(strategy_use_symbol_session_defaults &&
      (_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" ||
       _Symbol == "SP500.DWX" || _Symbol == "XTIUSD.DWX"))
      session_end = 2300;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_hhmm = dt.hour * 100 + dt.min;
   if(now_hhmm < session_end)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const int pos_magic = (int)PositionGetInteger(POSITION_MAGIC);
      bool ours = false;
      for(int slot_offset = 0; slot_offset < 4; ++slot_offset)
        {
         if(pos_magic == QM_Magic(qm_ea_id, qm_magic_slot_offset + slot_offset))
           {
            ours = true;
            break;
           }
        }
      if(ours)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Multi-slot session-end exits are closed in Strategy_ManageOpenPosition()
   // so all four OR side/magic slots are handled, not just QM_FrameworkMagic().
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
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
