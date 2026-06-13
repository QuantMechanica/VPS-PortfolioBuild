#property strict
#property version   "5.0"
#property description "QM5_10635 Elite Trader Consolidation Breakout"

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
input int    qm_ea_id                   = 10635;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_M5;
input int             strategy_atr_period            = 14;
input int             strategy_consolidation_bars    = 2;
input int             strategy_prior_range_bars      = 6;
input double          strategy_range_atr_mult        = 0.60;
input double          strategy_breakout_atr_mult     = 0.10;
input double          strategy_volume_mult           = 1.20;
input int             strategy_volume_sma_bars       = 20;
input double          strategy_tp_rr                 = 1.60;
input int             strategy_time_exit_bars        = 18;
input double          strategy_max_session_move_atr  = 2.50;
input double          strategy_spread_stop_fraction  = 0.20;
input int             strategy_session_open_hhmm     = 0;
input int             strategy_session_close_hhmm    = 2359;
input int             strategy_start_after_minutes   = 30;
input int             strategy_stop_before_close_min = 90;
input int             strategy_pending_expiry_bars   = 1;
input int             strategy_history_bars          = 360;

double   g_last_closed_close = 0.0;
datetime g_last_closed_time = 0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int h = MathMax(0, MathMin(23, hhmm / 100));
   const int m = MathMax(0, MathMin(59, hhmm % 100));
   return h * 60 + m;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_DateWithMinutes(const datetime t, const int minutes)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = minutes / 60;
   dt.min = minutes % 60;
   dt.sec = 0;
   return StructToTime(dt);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadRates(MqlRates &rates[])
  {
   const int bars_needed = MathMax(strategy_history_bars,
                           strategy_volume_sma_bars + strategy_consolidation_bars + strategy_prior_range_bars + 10);
   ArrayResize(rates, bars_needed);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, bars_needed, rates); // perf-allowed: bounded session/range/volume scan, called only inside skeleton's closed-bar gate.
   if(copied < strategy_volume_sma_bars + strategy_consolidation_bars + strategy_prior_range_bars + 4)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

double Strategy_VolumeSma(MqlRates &rates[], const int start_shift)
  {
   if(strategy_volume_sma_bars < 1)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int s = start_shift; s < start_shift + strategy_volume_sma_bars && s < ArraySize(rates); ++s)
     {
      if(rates[s].tick_volume <= 0)
         continue;
      sum += (double)rates[s].tick_volume;
      ++samples;
     }

   if(samples != strategy_volume_sma_bars)
      return 0.0;
   return sum / (double)samples;
  }

bool Strategy_Consolidation(MqlRates &rates[], const double atr, double &range_low, double &range_high)
  {
   range_low = DBL_MAX;
   range_high = -DBL_MAX;
   if(strategy_consolidation_bars < 2 || strategy_prior_range_bars < 1 || atr <= 0.0)
      return false;

   const int first_consol = 2;
   const int last_consol = first_consol + strategy_consolidation_bars - 1;
   const int prior_first = last_consol + 1;
   const int prior_last = prior_first + strategy_prior_range_bars - 1;
   if(prior_last >= ArraySize(rates))
      return false;

   double prior_low = DBL_MAX;
   double prior_high = -DBL_MAX;
   for(int s = prior_first; s <= prior_last; ++s)
     {
      prior_low = MathMin(prior_low, rates[s].low);
      prior_high = MathMax(prior_high, rates[s].high);
     }

   if(prior_low == DBL_MAX || prior_high == -DBL_MAX || prior_high <= prior_low)
      return false;

   for(int s = first_consol; s <= last_consol; ++s)
     {
      const double bar_range = rates[s].high - rates[s].low;
      if(bar_range <= 0.0 || bar_range > strategy_range_atr_mult * atr)
         return false;
      if(rates[s].close < prior_low || rates[s].close > prior_high)
         return false;
      range_low = MathMin(range_low, rates[s].low);
      range_high = MathMax(range_high, rates[s].high);
     }

   return (range_low < range_high && range_low > 0.0);
  }

bool Strategy_SessionExtremes(MqlRates &rates[],
                              const datetime signal_time,
                              double &session_high,
                              double &session_low,
                              double &session_open)
  {
   session_high = -DBL_MAX;
   session_low = DBL_MAX;
   session_open = 0.0;

   const datetime session_start = Strategy_DateWithMinutes(signal_time, Strategy_HhmmToMinutes(strategy_session_open_hhmm));
   for(int s = 2; s < ArraySize(rates); ++s)
     {
      if(rates[s].time < session_start)
         break;
      if(rates[s].time >= signal_time)
         continue;

      session_high = MathMax(session_high, rates[s].high);
      session_low = MathMin(session_low, rates[s].low);
      session_open = rates[s].open;
     }

   return (session_high > 0.0 && session_low > 0.0 && session_high > session_low && session_open > 0.0);
  }

bool Strategy_BuildEntry(QM_EntryRequest &req,
                         const QM_OrderType stop_type,
                         const double trigger,
                         const double sl,
                         const double range_low,
                         const double range_high)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || trigger <= 0.0 || sl <= 0.0)
      return false;

   const bool is_long = (stop_type == QM_BUY_STOP);
   const double entry = is_long ? ((ask >= trigger) ? ask : trigger)
                                : ((bid <= trigger) ? bid : trigger);
   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(strategy_spread_stop_fraction > 0.0 && spread > strategy_spread_stop_fraction * stop_distance)
      return false;

   req.type = is_long ? ((ask >= trigger) ? QM_BUY : QM_BUY_STOP)
                      : ((bid <= trigger) ? QM_SELL : QM_SELL_STOP);
   req.price = (req.type == QM_BUY || req.type == QM_SELL) ? 0.0 : Strategy_NormalizePrice(trigger);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(is_long ? entry + stop_distance * strategy_tp_rr
                                            : entry - stop_distance * strategy_tp_rr);
   req.expiration_seconds = (req.type == QM_BUY_STOP || req.type == QM_SELL_STOP)
                            ? MathMax(1, strategy_pending_expiry_bars) * PeriodSeconds(strategy_timeframe)
                            : 0;
   req.reason = StringFormat("%s:%s:%s",
                             is_long ? "CBL" : "CBS",
                             DoubleToString(range_low, _Digits),
                             DoubleToString(range_high, _Digits));

   if(is_long && !(req.sl < entry && req.tp > entry))
      return false;
   if(!is_long && !(req.sl > entry && req.tp < entry))
      return false;
   return true;
  }

bool Strategy_ParseRange(const string comment, double &range_low, double &range_high)
  {
   range_low = 0.0;
   range_high = 0.0;
   if(StringFind(comment, "CBL:") != 0 && StringFind(comment, "CBS:") != 0)
      return false;

   const int first = StringFind(comment, ":");
   const int second = StringFind(comment, ":", first + 1);
   if(first < 0 || second < 0)
      return false;

   range_low = StringToDouble(StringSubstr(comment, first + 1, second - first - 1));
   range_high = StringToDouble(StringSubstr(comment, second + 1));
   return (range_low > 0.0 && range_high > range_low);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time and spread filters are entry-specific because open positions still
   // need session-close/time-stop exits after the entry window ends.
   return ((ENUM_TIMEFRAMES)_Period != strategy_timeframe);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   MqlRates rates[];
   if(!Strategy_LoadRates(rates))
      return false;

   g_last_closed_close = rates[1].close;
   g_last_closed_time = rates[1].time;

   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingOrder())
      return false;

   const int signal_minutes = Strategy_MinutesOfDay(rates[1].time);
   const int session_open_minutes = Strategy_HhmmToMinutes(strategy_session_open_hhmm);
   const int session_close_minutes = Strategy_HhmmToMinutes(strategy_session_close_hhmm);
   if(signal_minutes < session_open_minutes + strategy_start_after_minutes)
      return false;
   if(signal_minutes > session_close_minutes - strategy_stop_before_close_min)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double range_low, range_high;
   if(!Strategy_Consolidation(rates, atr, range_low, range_high))
      return false;

   double session_high, session_low, session_open;
   if(!Strategy_SessionExtremes(rates, rates[1].time, session_high, session_low, session_open))
      return false;

   if(MathAbs(rates[1].close - session_open) > strategy_max_session_move_atr * atr)
      return false;

   const double volume_sma = Strategy_VolumeSma(rates, 2);
   if(volume_sma <= 0.0 || rates[1].tick_volume < strategy_volume_mult * volume_sma)
      return false;

   const double buffer = strategy_breakout_atr_mult * atr;
   const double long_trigger = Strategy_NormalizePrice(session_high + buffer);
   const double short_trigger = Strategy_NormalizePrice(session_low - buffer);

   if(rates[1].high >= long_trigger && rates[1].close >= long_trigger)
     {
      const double sl = Strategy_NormalizePrice(range_low - buffer);
      return Strategy_BuildEntry(req, QM_BUY_STOP, long_trigger, sl, range_low, range_high);
     }

   if(rates[1].low <= short_trigger && rates[1].close <= short_trigger)
     {
      const double sl = Strategy_NormalizePrice(range_high + buffer);
      return Strategy_BuildEntry(req, QM_SELL_STOP, short_trigger, sl, range_low, range_high);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, partial, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int session_close_minutes = Strategy_HhmmToMinutes(strategy_session_close_hhmm);
   const int now_minutes = Strategy_MinutesOfDay(TimeCurrent());
   const int max_hold_seconds = MathMax(1, strategy_time_exit_bars) * PeriodSeconds(strategy_timeframe);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(now_minutes >= session_close_minutes)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && TimeCurrent() - open_time >= max_hold_seconds)
         return true;

      double range_low, range_high;
      if(g_last_closed_time <= 0 || g_last_closed_close <= 0.0 ||
         !Strategy_ParseRange(PositionGetString(POSITION_COMMENT), range_low, range_high))
         continue;

      if(g_last_closed_close >= range_low && g_last_closed_close <= range_high)
         return true;
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
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
