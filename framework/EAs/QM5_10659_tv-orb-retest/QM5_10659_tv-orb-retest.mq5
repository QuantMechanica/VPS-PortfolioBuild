#property strict
#property version   "5.0"
#property description "QM5_10659 TradingView OR Breakout Retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
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
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10659;
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
input int    strategy_or_minutes              = 15;
input int    strategy_retest_expiry_bars      = 6;
input double strategy_long_rr                 = 2.0;
input double strategy_short_rr                = 2.0;
input int    strategy_atr_period              = 14;
input double strategy_min_or_atr_frac         = 0.05;
input double strategy_max_or_atr_frac         = 2.00;
input double strategy_max_sl_atr_mult         = 1.00;
input int    strategy_session_start_hour      = -1;    // -1 = symbol-aware broker-time default.
input int    strategy_session_start_minute    = -1;
input int    strategy_entry_cutoff_hour       = -1;    // -1 = symbol-aware broker-time default.
input int    strategy_entry_cutoff_minute     = -1;
input int    strategy_session_close_hour      = -1;    // -1 = symbol-aware broker-time default.
input int    strategy_session_close_minute    = -1;
input bool   strategy_long_monday             = true;
input bool   strategy_long_tuesday            = true;
input bool   strategy_long_wednesday          = true;
input bool   strategy_long_thursday           = true;
input bool   strategy_long_friday             = true;
input bool   strategy_short_monday            = true;
input bool   strategy_short_tuesday           = true;
input bool   strategy_short_wednesday         = true;
input bool   strategy_short_thursday          = true;
input bool   strategy_short_friday            = true;

int      g_or_day_key = 0;
bool     g_or_ready = false;
bool     g_first_breakout_consumed = false;
bool     g_order_or_trade_sent = false;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
double   g_long_stop = 0.0;
double   g_short_stop = 0.0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DayTime(const datetime ref_time, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(ref_time, dt);
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsGermanIndex()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0 || StringFind(_Symbol, "DE30") >= 0);
  }

bool Strategy_IsUSIndex()
  {
   return (StringFind(_Symbol, "NDX") >= 0 || StringFind(_Symbol, "WS30") >= 0 || StringFind(_Symbol, "SP500") >= 0);
  }

void Strategy_DefaultSessionTimes(int &start_h, int &start_m, int &cutoff_h, int &cutoff_m, int &close_h, int &close_m)
  {
   if(Strategy_IsUSIndex())
     {
      start_h = 16;
      start_m = 30;
      cutoff_h = 21;
      cutoff_m = 0;
      close_h = 22;
      close_m = 30;
      return;
     }

   if(Strategy_IsGermanIndex())
     {
      start_h = 10;
      start_m = 0;
      cutoff_h = 16;
      cutoff_m = 0;
      close_h = 18;
      close_m = 30;
      return;
     }

   start_h = 9;
   start_m = 0;
   cutoff_h = 17;
   cutoff_m = 0;
   close_h = 21;
   close_m = 0;
  }

void Strategy_SessionTimes(const datetime ref_time, datetime &session_start, datetime &entry_cutoff, datetime &session_close)
  {
   int start_h = 0;
   int start_m = 0;
   int cutoff_h = 0;
   int cutoff_m = 0;
   int close_h = 0;
   int close_m = 0;
   Strategy_DefaultSessionTimes(start_h, start_m, cutoff_h, cutoff_m, close_h, close_m);

   if(strategy_session_start_hour >= 0)
      start_h = strategy_session_start_hour;
   if(strategy_session_start_minute >= 0)
      start_m = strategy_session_start_minute;
   if(strategy_entry_cutoff_hour >= 0)
      cutoff_h = strategy_entry_cutoff_hour;
   if(strategy_entry_cutoff_minute >= 0)
      cutoff_m = strategy_entry_cutoff_minute;
   if(strategy_session_close_hour >= 0)
      close_h = strategy_session_close_hour;
   if(strategy_session_close_minute >= 0)
      close_m = strategy_session_close_minute;

   session_start = Strategy_DayTime(ref_time, start_h, start_m);
   entry_cutoff = Strategy_DayTime(ref_time, cutoff_h, cutoff_m);
   session_close = Strategy_DayTime(ref_time, close_h, close_m);
  }

void Strategy_ResetDayIfNeeded(const datetime broker_now)
  {
   const int day_key = Strategy_DateKey(broker_now);
   if(day_key == g_or_day_key)
      return;

   g_or_day_key = day_key;
   g_or_ready = false;
   g_first_breakout_consumed = false;
   g_order_or_trade_sent = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_long_stop = 0.0;
   g_short_stop = 0.0;
  }

bool Strategy_LongWeekdayAllowed(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week == 1)
      return strategy_long_monday;
   if(dt.day_of_week == 2)
      return strategy_long_tuesday;
   if(dt.day_of_week == 3)
      return strategy_long_wednesday;
   if(dt.day_of_week == 4)
      return strategy_long_thursday;
   if(dt.day_of_week == 5)
      return strategy_long_friday;
   return false;
  }

bool Strategy_ShortWeekdayAllowed(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week == 1)
      return strategy_short_monday;
   if(dt.day_of_week == 2)
      return strategy_short_tuesday;
   if(dt.day_of_week == 3)
      return strategy_short_wednesday;
   if(dt.day_of_week == 4)
      return strategy_short_thursday;
   if(dt.day_of_week == 5)
      return strategy_short_friday;
   return false;
  }

bool Strategy_HasOpenPositionOrPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int j = OrdersTotal() - 1; j >= 0; --j)
     {
      const ulong order_ticket = OrderGetTicket(j);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }

   return false;
  }

void Strategy_RemovePendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int j = OrdersTotal() - 1; j >= 0; --j)
     {
      const ulong order_ticket = OrderGetTicket(j);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(order_ticket, reason);
     }
  }

bool Strategy_BuildOpeningRange(const datetime session_start, const datetime range_end)
  {
   MqlRates or_rates[];
   const int copied = CopyRates(_Symbol, _Period, session_start, range_end - 1, or_rates); // perf-allowed: opening-range structural read, called only after skeleton QM_IsNewBar gate.
   if(copied <= 0)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   double last_bull_low = 0.0;
   double last_bear_high = 0.0;
   datetime last_bull_time = 0;
   datetime last_bear_time = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(or_rates[i].time < session_start || or_rates[i].time >= range_end)
         continue;
      if(or_rates[i].high <= 0.0 || or_rates[i].low <= 0.0)
         continue;

      if(or_rates[i].high > high)
         high = or_rates[i].high;
      if(or_rates[i].low < low)
         low = or_rates[i].low;

      if(or_rates[i].close > or_rates[i].open && or_rates[i].time >= last_bull_time)
        {
         last_bull_time = or_rates[i].time;
         last_bull_low = or_rates[i].low;
        }
      if(or_rates[i].close < or_rates[i].open && or_rates[i].time >= last_bear_time)
        {
         last_bear_time = or_rates[i].time;
         last_bear_high = or_rates[i].high;
        }
     }

   if(high <= 0.0 || low <= 0.0 || high <= low)
      return false;

   g_or_high = QM_StopRulesNormalizePrice(_Symbol, high);
   g_or_low = QM_StopRulesNormalizePrice(_Symbol, low);
   g_long_stop = QM_StopRulesNormalizePrice(_Symbol, last_bull_low);
   g_short_stop = QM_StopRulesNormalizePrice(_Symbol, last_bear_high);
   g_or_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double max_spread_distance = point * 100.0;
   if(ask > bid && (ask - bid) > max_spread_distance)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   Strategy_ResetDayIfNeeded(broker_now);

   if(strategy_or_minutes <= 0 || strategy_retest_expiry_bars <= 0 ||
      strategy_long_rr <= 0.0 || strategy_short_rr <= 0.0 ||
      strategy_atr_period <= 0 || strategy_max_sl_atr_mult <= 0.0)
      return false;

   if(g_order_or_trade_sent || g_first_breakout_consumed || Strategy_HasOpenPositionOrPendingOrder())
      return false;

   datetime session_start;
   datetime entry_cutoff;
   datetime session_close;
   Strategy_SessionTimes(broker_now, session_start, entry_cutoff, session_close);

   const datetime range_end = session_start + strategy_or_minutes * 60;
   if(broker_now < range_end || broker_now >= entry_cutoff || broker_now >= session_close)
      return false;

   if(!g_or_ready && !Strategy_BuildOpeningRange(session_start, range_end))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double or_range = g_or_high - g_or_low;
   if(or_range <= 0.0)
      return false;
   if(or_range < atr * strategy_min_or_atr_frac || or_range > atr * strategy_max_or_atr_frac)
      return false;

   MqlRates last_bar[];
   const int copied = CopyRates(_Symbol, _Period, 1, 1, last_bar); // perf-allowed: one closed breakout candle, called only after skeleton QM_IsNewBar gate.
   if(copied != 1)
      return false;

   const int expiry_seconds = strategy_retest_expiry_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(expiry_seconds <= 0)
      return false;

   const bool long_breakout = (last_bar[0].close > last_bar[0].open && last_bar[0].close > g_or_high);
   const bool short_breakout = (last_bar[0].close < last_bar[0].open && last_bar[0].close < g_or_low);
   if(!long_breakout && !short_breakout)
      return false;

   g_first_breakout_consumed = true;

   if(long_breakout)
     {
      if(!Strategy_LongWeekdayAllowed(last_bar[0].time))
         return false;
      if(g_long_stop <= 0.0 || g_long_stop >= g_or_high)
         return false;

      const double risk_distance = MathAbs(g_or_high - g_long_stop);
      if(risk_distance <= 0.0 || risk_distance > atr * strategy_max_sl_atr_mult)
         return false;

      req.type = QM_BUY_LIMIT;
      req.price = g_or_high;
      req.sl = g_long_stop;
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_long_rr);
      req.reason = "ORB_RETEST_LONG";
      req.expiration_seconds = expiry_seconds;
      g_order_or_trade_sent = (req.tp > 0.0);
      return (req.tp > 0.0);
     }

   if(!Strategy_ShortWeekdayAllowed(last_bar[0].time))
      return false;
   if(g_short_stop <= 0.0 || g_short_stop <= g_or_low)
      return false;

   const double short_risk_distance = MathAbs(g_short_stop - g_or_low);
   if(short_risk_distance <= 0.0 || short_risk_distance > atr * strategy_max_sl_atr_mult)
      return false;

   req.type = QM_SELL_LIMIT;
   req.price = g_or_low;
   req.sl = g_short_stop;
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_short_rr);
   req.reason = "ORB_RETEST_SHORT";
   req.expiration_seconds = expiry_seconds;
   g_order_or_trade_sent = (req.tp > 0.0);
   return (req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_ResetDayIfNeeded(broker_now);

   datetime session_start;
   datetime entry_cutoff;
   datetime session_close;
   Strategy_SessionTimes(broker_now, session_start, entry_cutoff, session_close);
   if(broker_now >= session_close)
      Strategy_RemovePendingOrders("session_close");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_ResetDayIfNeeded(broker_now);

   datetime session_start;
   datetime entry_cutoff;
   datetime session_close;
   Strategy_SessionTimes(broker_now, session_start, entry_cutoff, session_close);
   return (broker_now >= session_close);
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
