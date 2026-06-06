#property strict
#property version   "5.0"
#property description "QM5_10852 TradingView Brosio 8:00 Range Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10852;
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
// Session times are expressed in BROKER SERVER time. The source anchors are
// New York exchange local (America/New_York). Darwinex NY-Close server time is
// NY local + 7h year-round (server GMT+2/+3 vs NY GMT-5/-4 — both switch on US
// DST, so the offset is a constant +7). Conversion applied at build:
//   08:00 NY -> 15:00 broker   09:45 NY -> 16:45 broker   11:40 NY -> 18:40 broker
input int    strategy_anchor_hour              = 15;   // 08:00 NY (range anchor)
input int    strategy_anchor_minute            = 0;
input int    strategy_range_minutes            = 15;
input int    strategy_trade_start_hour         = 16;   // 09:45 NY (entry window open)
input int    strategy_trade_start_minute       = 45;
input int    strategy_trade_end_hour           = 18;   // 11:40 NY (entry window close + force-close)
input int    strategy_trade_end_minute         = 40;
input int    strategy_atr_period               = 14;
input double strategy_min_range_atr_mult       = 0.5;
input double strategy_max_range_atr_mult       = 2.5;
input double strategy_retest_tolerance_frac    = 0.10;
input double strategy_spread_stop_max_frac     = 0.15;
input double strategy_tp_rr                    = 4.0;
input double strategy_breakeven_rr             = 2.0;

int    g_session_day_key = 0;
bool   g_range_ready = false;
bool   g_range_valid = false;
bool   g_long_break = false;
bool   g_short_break = false;
bool   g_long_retraced = false;
bool   g_short_retraced = false;
bool   g_long_traded = false;
bool   g_short_traded = false;
double g_range_high = 0.0;
double g_range_low = 0.0;
double g_range_mid = 0.0;
double g_range_width = 0.0;

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_Minutes(const int hour_value, const int minute_value)
  {
   return hour_value * 60 + minute_value;
  }

bool Strategy_TimeInWindow(const int minute_of_day, const int start_minute, const int end_minute)
  {
   if(start_minute <= end_minute)
      return (minute_of_day >= start_minute && minute_of_day <= end_minute);
   return (minute_of_day >= start_minute || minute_of_day <= end_minute);
  }

void Strategy_ResetSession(const int day_key)
  {
   g_session_day_key = day_key;
   g_range_ready = false;
   g_range_valid = false;
   g_long_break = false;
   g_short_break = false;
   g_long_retraced = false;
   g_short_retraced = false;
   g_long_traded = false;
   g_short_traded = false;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_range_mid = 0.0;
   g_range_width = 0.0;
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_BuildRangeFromRates(const MqlRates &rates[], const int copied, const int day_key)
  {
   const int anchor_start = Strategy_Minutes(strategy_anchor_hour, strategy_anchor_minute);
   const int anchor_end = anchor_start + strategy_range_minutes;
   const int expected_bars = MathMax(1, strategy_range_minutes / 5);
   int found = 0;
   double high_value = -DBL_MAX;
   double low_value = DBL_MAX;

   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_DayKey(rates[i].time) != day_key)
         continue;
      const int bar_minute = Strategy_MinuteOfDay(rates[i].time);
      if(bar_minute < anchor_start || bar_minute >= anchor_end)
         continue;

      high_value = MathMax(high_value, rates[i].high);
      low_value = MathMin(low_value, rates[i].low);
      found++;
     }

   if(found < expected_bars || high_value <= low_value || low_value <= 0.0)
      return false;

   g_range_high = high_value;
   g_range_low = low_value;
   g_range_mid = (high_value + low_value) * 0.5;
   g_range_width = high_value - low_value;
   g_range_ready = true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
     {
      g_range_valid = false;
      return true;
     }

   g_range_valid = (g_range_width >= strategy_min_range_atr_mult * atr &&
                    g_range_width <= strategy_max_range_atr_mult * atr);
   return true;
  }

int Strategy_AdvanceState()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true); // dynamic array: rates[0] = most recent closed bar

   // Called only from OnTick after the framework `QM_IsNewBar()` gate.
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 96, rates); // perf-allowed: one closed-bar structural read
   if(copied < 4)
      return 0;

   const MqlRates bar = rates[0];
   const int day_key = Strategy_DayKey(bar.time);
   if(day_key != g_session_day_key)
      Strategy_ResetSession(day_key);

   if(!g_range_ready)
      Strategy_BuildRangeFromRates(rates, copied, day_key);

   if(!g_range_ready || !g_range_valid)
      return 0;

   // Track range breaks from range-completion onward. A break may occur before
   // the entry window opens; the retest entry below still fires only in-window.
   if(bar.high > g_range_high)
      g_long_break = true;
   if(bar.low < g_range_low)
      g_short_break = true;

   const int bar_minute = Strategy_MinuteOfDay(bar.time);
   const int trade_start = Strategy_Minutes(strategy_trade_start_hour, strategy_trade_start_minute);
   const int trade_end = Strategy_Minutes(strategy_trade_end_hour, strategy_trade_end_minute);
   if(!Strategy_TimeInWindow(bar_minute, trade_start, trade_end))
      return 0;

   const double tolerance = g_range_width * MathMax(0.0, strategy_retest_tolerance_frac);

   // After a break, latch the midpoint retrace, then enter on the reclaim
   // (long) / rejection (short) candle — "the candle after price retraces to
   // the range midpoint and reclaims/rejects".
   if(g_long_break && bar.low <= g_range_mid + tolerance)
      g_long_retraced = true;
   if(g_short_break && bar.high >= g_range_mid - tolerance)
      g_short_retraced = true;

   if(g_long_break && g_long_retraced && !g_long_traded && bar.close > g_range_mid)
     {
      g_long_traded = true;
      return 1;
     }

   if(g_short_break && g_short_retraced && !g_short_traded && bar.close < g_range_mid)
     {
      g_short_traded = true;
      return -1;
     }

   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;
   return false;
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

   if(Strategy_HasOpenPosition())
      return false;

   const int signal = Strategy_AdvanceState();
   if(signal == 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   if(signal > 0)
     {
      const double entry = ask;
      const double stop_dist = entry - g_range_low;
      if(stop_dist <= point)
         return false;
      if((ask - bid) > stop_dist * strategy_spread_stop_max_frac)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(g_range_low, _Digits);
      req.tp = NormalizeDouble(entry + stop_dist * strategy_tp_rr, _Digits);
      req.reason = "BROSIO_LONG_MIDPOINT_RECLAIM";
      return true;
     }

   const double entry = bid;
   const double stop_dist = g_range_high - entry;
   if(stop_dist <= point)
      return false;
   if((ask - bid) > stop_dist * strategy_spread_stop_max_frac)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(g_range_high, _Digits);
   req.tp = NormalizeDouble(entry - stop_dist * strategy_tp_rr, _Digits);
   req.reason = "BROSIO_SHORT_MIDPOINT_REJECT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_breakeven_rr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double stop_dist = is_buy ? (open_price - current_sl) : (current_sl - open_price);
      if(stop_dist <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved < stop_dist * strategy_breakeven_rr)
         continue;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool already_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                     : (current_sl <= open_price + point * 0.5);
      if(already_be)
         continue;

      QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "BROSIO_TP1_2R_BREAKEVEN");
     }
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int now_minute = Strategy_MinuteOfDay(TimeCurrent());
   const int trade_end = Strategy_Minutes(strategy_trade_end_hour, strategy_trade_end_minute);
   return (now_minute >= trade_end);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10852_tv_brosio_8range\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
