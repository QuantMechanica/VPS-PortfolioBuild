#property strict
#property version   "5.0"
#property description "QM5_10719 TradingView Gap Fill Opening Range"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10719;
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
input int    strategy_atr_period          = 14;
input double strategy_gap_atr_mult        = 0.25;
input int    strategy_or_minutes          = 15;
input double strategy_stop_atr_buffer     = 0.20;
input double strategy_min_stop_atr_mult   = 0.25;
input double strategy_max_stop_atr_mult   = 2.50;
input double strategy_continuation_rr     = 2.00;
input int    strategy_us_open_hour        = 15;
input int    strategy_us_open_minute      = 30;
input int    strategy_us_close_hour       = 22;
input int    strategy_us_close_minute     = 0;
input int    strategy_eu_open_hour        = 9;
input int    strategy_eu_open_minute      = 0;
input int    strategy_eu_close_hour       = 17;
input int    strategy_eu_close_minute     = 30;
input int    strategy_or_scan_bars        = 600;
input int    strategy_max_spread_points   = 500;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DayTime(const datetime t, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsEuIndex()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0);
  }

datetime Strategy_SessionOpen(const datetime t)
  {
   if(Strategy_IsEuIndex())
      return Strategy_DayTime(t, strategy_eu_open_hour, strategy_eu_open_minute);
   return Strategy_DayTime(t, strategy_us_open_hour, strategy_us_open_minute);
  }

datetime Strategy_SessionClose(const datetime t)
  {
   if(Strategy_IsEuIndex())
      return Strategy_DayTime(t, strategy_eu_close_hour, strategy_eu_close_minute);
   return Strategy_DayTime(t, strategy_us_close_hour, strategy_us_close_minute);
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

// No Trade Filter (time, spread, news): news is handled by the framework and
// Strategy_NewsFilterHook; this hook blocks fresh entries outside the cash
// session/OR window or during excessive spread while still allowing exits.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime session_open = Strategy_SessionOpen(now);
   const datetime session_close = Strategy_SessionClose(now);
   if(now < session_open + strategy_or_minutes * 60)
      return true;
   if(now >= session_close)
      return true;

   return false;
  }

// Trade Entry: gap-fill or continuation after the first-session opening range.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static int s_trade_session_key = 0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return false;
   if(strategy_atr_period < 1 || strategy_or_minutes < 5 || strategy_or_scan_bars < 20)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, strategy_or_scan_bars, rates); // perf-allowed: bounded OR/session structural read; Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < 10)
      return false;

   const datetime signal_time = rates[0].time;
   const int session_key = Strategy_DateKey(signal_time);
   if(s_trade_session_key == session_key)
      return false;

   const datetime session_open = Strategy_SessionOpen(signal_time);
   const datetime session_close = Strategy_SessionClose(signal_time);
   const datetime or_end = session_open + strategy_or_minutes * 60;
   if(signal_time < or_end || signal_time >= session_close)
      return false;

   double or_high = -DBL_MAX;
   double or_low = DBL_MAX;
   double today_open = 0.0;
   datetime first_or_bar = 0;
   int or_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bt = rates[i].time;
      if(bt < session_open || bt >= or_end)
         continue;

      or_high = MathMax(or_high, rates[i].high);
      or_low = MathMin(or_low, rates[i].low);
      if(first_or_bar == 0 || bt < first_or_bar)
        {
         first_or_bar = bt;
         today_open = rates[i].open;
        }
      or_count++;
     }

   const int expected_or_bars = (strategy_or_minutes + 4) / 5;
   if(or_count < expected_or_bars || today_open <= 0.0 || or_high <= or_low)
      return false;

   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, daily) != 1) // perf-allowed: one prior daily close used as the card's prior-session-close proxy on the gated path.
      return false;
   const double prior_close = daily[0].close;
   if(prior_close <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double gap = today_open - prior_close;
   if(MathAbs(gap) < strategy_gap_atr_mult * atr)
      return false;

   const double close_price = rates[0].close;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_price <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool signal = false;
   bool gap_fill = false;

   if(gap < 0.0 && close_price > or_high)
     {
      side = QM_BUY;
      signal = true;
      gap_fill = true;
     }
   else if(gap > 0.0 && close_price < or_low)
     {
      side = QM_SELL;
      signal = true;
      gap_fill = true;
     }
   else if(gap > 0.0 && close_price > or_high)
     {
      side = QM_BUY;
      signal = true;
      gap_fill = false;
     }
   else if(gap < 0.0 && close_price < or_low)
     {
      side = QM_SELL;
      signal = true;
      gap_fill = false;
     }

   if(!signal)
      return false;

   const double entry_price = (side == QM_BUY) ? ask : bid;
   const double stop = (side == QM_BUY)
                       ? (or_low - strategy_stop_atr_buffer * atr)
                       : (or_high + strategy_stop_atr_buffer * atr);
   const double stop_distance = MathAbs(entry_price - stop);
   if(stop_distance < strategy_min_stop_atr_mult * atr ||
      stop_distance > strategy_max_stop_atr_mult * atr)
      return false;

   double target = 0.0;
   if(gap_fill)
      target = prior_close;
   else if(side == QM_BUY)
      target = entry_price + strategy_continuation_rr * stop_distance;
   else
      target = entry_price - strategy_continuation_rr * stop_distance;

   if(side == QM_BUY && target <= entry_price)
      return false;
   if(side == QM_SELL && target >= entry_price)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = target;
   req.reason = gap_fill ? "GAP_FILL_OR_BREAK" : "CONTINUATION_OR_BREAK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   s_trade_session_key = session_key;
   return true;
  }

// Trade Management: no trailing, partial close, pyramiding, or break-even rule
// is specified by the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: force-flat at the local index-cash session end. SL/TP and
// Friday close are handled by the framework.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   return (now >= Strategy_SessionClose(now));
  }

// News Filter Hook: callable P8 hook; central framework news settings apply.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10719_tv_gap_or\"}");
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
