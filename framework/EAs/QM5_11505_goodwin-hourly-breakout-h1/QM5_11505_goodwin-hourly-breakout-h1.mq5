#property strict
#property version   "5.0"
#property description "QM5_11505 Goodwin hourly session breakout H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11505_goodwin-hourly-breakout-h1
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11505_goodwin-hourly-breakout-h1.md
//
// Mechanical mapping:
//   - Prior completed D1 candle sets long/short bias.
//   - At the broker-time entry window, place one pending stop order at the
//     recent H1 session high/low plus a 1-pip breakout buffer.
//   - Fixed 150-pip SL and 2R TP.
//   - Close any open position at the broker-time session-end window.
//
// Raw closed-bar OHLC reads are bounded and annotated as perf-allowed because
// this is bespoke session-box price action, not an indicator reimplementation.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11505;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    ENTRY_HOUR_GMT2            = 0;
input int    ENTRY_MINUTE               = 5;
input int    ENTRY_WINDOW_END_MINUTE    = 15;
input int    EXIT_HOUR_GMT2             = 2;
input int    EXIT_MINUTE                = 30;
input int    DST_OFFSET                 = 0;
input int    SESSION_RANGE_BARS         = 1;
input int    SL_PIPS                    = 150;
input double TP_RR                      = 2.0;
input int    BREAKOUT_BUFFER_PIPS       = 1;
input bool   SKIP_FRIDAY_ENTRY          = true;
input double SPREAD_CAP_PIPS            = 15.0;

int NormalizeHour(const int hour)
  {
   int h = hour % 24;
   if(h < 0)
      h += 24;
   return h;
  }

int BrokerMinutesOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsEntryWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);

   const int entry_hour = NormalizeHour(ENTRY_HOUR_GMT2 + DST_OFFSET);
   if(dt.hour != entry_hour)
      return false;

   // H1 cannot represent 00:05 exactly. For H1 and higher, use the containing
   // broker-hour bar; lower timeframes honor the minute inputs literally.
   if(PeriodSeconds((ENUM_TIMEFRAMES)_Period) >= 3600)
      return true;

   return (dt.min >= ENTRY_MINUTE && dt.min <= ENTRY_WINDOW_END_MINUTE);
  }

bool IsPastExitTime(const datetime broker_time)
  {
   const int exit_hour = NormalizeHour(EXIT_HOUR_GMT2 + DST_OFFSET);
   const int exit_minute = exit_hour * 60 + EXIT_MINUTE;
   return (BrokerMinutesOfDay(broker_time) >= exit_minute);
  }

int SecondsUntilExit(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   dt.hour = NormalizeHour(EXIT_HOUR_GMT2 + DST_OFFSET);
   dt.min = EXIT_MINUTE;
   dt.sec = 0;

   datetime expiry = StructToTime(dt);
   if(expiry <= broker_time)
      expiry += 86400;
   const int seconds_left = (int)(expiry - broker_time);
   return MathMax(60, seconds_left);
  }

bool HasDirectionalBias(bool &long_bias, bool &short_bias)
  {
   long_bias = false;
   short_bias = false;

   const double d1_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   if(d1_open <= 0.0 || d1_close <= 0.0)
      return false;

   long_bias = (d1_close > d1_open);
   short_bias = (d1_close < d1_open);
   return (long_bias || short_bias);
  }

bool ReadSessionRange(double &session_high, double &session_low)
  {
   session_high = 0.0;
   session_low = 0.0;
   const int bars = MathMax(1, SESSION_RANGE_BARS);

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high = iHigh(_Symbol, _Period, shift); // perf-allowed
      const double low = iLow(_Symbol, _Period, shift);   // perf-allowed
      if(high <= 0.0 || low <= 0.0)
         return false;
      if(session_high == 0.0 || high > session_high)
         session_high = high;
      if(session_low == 0.0 || low < session_low)
         session_low = low;
     }

   return (session_high > 0.0 && session_low > 0.0 && session_high > session_low);
  }

bool IsFridayEntryBlocked(const datetime broker_time)
  {
   if(!SKIP_FRIDAY_ENTRY)
      return false;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = SPREAD_CAP_PIPS * pip;
   return (spread > 0.0 && cap > 0.0 && spread > cap);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!IsEntryWindow(broker_now))
      return false;
   if(IsFridayEntryBlocked(broker_now))
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   bool long_bias = false;
   bool short_bias = false;
   if(!HasDirectionalBias(long_bias, short_bias))
      return false;

   double session_high = 0.0;
   double session_low = 0.0;
   if(!ReadSessionRange(session_high, session_low))
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, BREAKOUT_BUFFER_PIPS);
   if(buffer <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   double entry = 0.0;
   if(long_bias)
     {
      side = QM_BUY_STOP;
      entry = QM_StopRulesNormalizePrice(_Symbol, session_high + buffer);
     }
   else if(short_bias)
     {
      side = QM_SELL_STOP;
      entry = QM_StopRulesNormalizePrice(_Symbol, session_low - buffer);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, SL_PIPS);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, TP_RR);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_bias ? "goodwin_ny_buystop" : "goodwin_ny_sellstop";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = SecondsUntilExit(broker_now);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no BE, trailing, partial, or scale logic.
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return IsPastExitTime(TimeCurrent());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
