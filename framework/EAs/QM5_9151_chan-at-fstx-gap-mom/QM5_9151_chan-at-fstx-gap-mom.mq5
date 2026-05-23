#property strict
#property version   "5.0"
#property description "QM5_9151 Chan AT FSTX Opening-Gap Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9151;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_session_open_hour_broker  = 12;
input int    strategy_session_close_hour_broker = 0;
input int    strategy_return_lookback_sessions  = 90;
input double strategy_entry_z                  = 0.10;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 2.50;
input double strategy_max_spread_points        = 80.0;

int SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   datetime session_date = t;
   if(dt.hour < strategy_session_open_hour_broker)
      session_date = t - 86400;

   TimeToStruct(session_date, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool BuildSessionStats(const int today_key,
                       double &prior_high,
                       double &prior_low,
                       double &stdret)
  {
   prior_high = 0.0;
   prior_low = 0.0;
   stdret = 0.0;

   const int lookback = MathMax(strategy_return_lookback_sessions, 90);
   const int bars_needed = (lookback + 20) * 24;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, bars_needed, rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < (lookback + 2) * 12)
      return false;

   double highs[160];
   double lows[160];
   double closes[160];
   int count = 0;
   int active_key = -1;
   double active_high = 0.0;
   double active_low = 0.0;
   double active_close = 0.0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const int key = SessionKey(rates[i].time);
      if(key >= today_key)
         continue;

      if(active_key != key)
        {
         if(active_key >= 0 && count < 160)
           {
            highs[count] = active_high;
            lows[count] = active_low;
            closes[count] = active_close;
            ++count;
           }

         active_key = key;
         active_high = rates[i].high;
         active_low = rates[i].low;
         active_close = rates[i].close;
        }
      else
        {
         active_high = MathMax(active_high, rates[i].high);
         active_low = MathMin(active_low, rates[i].low);
         active_close = rates[i].close;
        }
     }

   if(active_key >= 0 && count < 160)
     {
      highs[count] = active_high;
      lows[count] = active_low;
      closes[count] = active_close;
      ++count;
     }

   if(count < lookback + 1)
      return false;

   prior_high = highs[count - 1];
   prior_low = lows[count - 1];
   if(prior_high <= 0.0 || prior_low <= 0.0)
      return false;

   double returns[120];
   double mean = 0.0;
   for(int r = 0; r < lookback; ++r)
     {
      const int idx = count - lookback + r;
      if(closes[idx - 1] <= 0.0 || closes[idx] <= 0.0)
         return false;
      returns[r] = (closes[idx] / closes[idx - 1]) - 1.0;
      mean += returns[r];
     }
   mean /= lookback;

   double variance = 0.0;
   for(int r = 0; r < lookback; ++r)
     {
      const double diff = returns[r] - mean;
      variance += diff * diff;
     }
   variance /= MathMax(1, lookback - 1);
   stdret = MathSqrt(variance);

   return (stdret > 0.0);
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   if(HasOpenPosition())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / point > strategy_max_spread_points);
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

   if(strategy_entry_z <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour != strategy_session_open_hour_broker)
      return false;
   if(HasOpenPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_H1, 0);
   if(bar_time <= 0)
      return false;

   const int today_key = SessionKey(bar_time);
   double prior_high = 0.0;
   double prior_low = 0.0;
   double stdret = 0.0;
   if(!BuildSessionStats(today_key, prior_high, prior_low, stdret))
      return false;

   const double today_open = iOpen(_Symbol, PERIOD_H1, 0);
   if(today_open <= 0.0)
      return false;

   const double upper_trigger = prior_high * (1.0 + strategy_entry_z * stdret);
   const double lower_trigger = prior_low * (1.0 - strategy_entry_z * stdret);

   if(today_open > upper_trigger)
     {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "CHAN_FSTX_GAP_MOM_LONG";
      return (req.price > 0.0 && req.sl > 0.0);
     }

   if(today_open < lower_trigger)
     {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "CHAN_FSTX_GAP_MOM_SHORT";
      return (req.price > 0.0 && req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline specifies no trailing, break-even, partial close, or scaling.
  }

bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour == strategy_session_close_hour_broker);
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9151\",\"ea\":\"QM5_9151_chan-at-fstx-gap-mom\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
