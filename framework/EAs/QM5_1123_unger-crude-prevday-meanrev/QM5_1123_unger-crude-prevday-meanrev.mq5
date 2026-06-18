#property strict
#property version   "5.0"
#property description "QM5_1123 Unger crude previous-day mean reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1123;
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
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.5;
input bool   strategy_use_vwap_proxy_tp       = true;
input double strategy_tp_rr                   = 1.0;
input int    strategy_daily_atr_lookback      = 120;
input double strategy_daily_atr_percentile    = 25.0;
input bool   strategy_skip_eia_day            = true;
input int    strategy_eia_day_of_week         = 3;     // Sunday=0, Wednesday=3.
input int    strategy_session_start_hhmm      = 100;
input int    strategy_flatten_hhmm            = 2200;
input int    strategy_max_spread_points       = 80;

int Strategy_Hhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 100 + dt.min;
  }

datetime Strategy_DayStart(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_DayOfWeek(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.day_of_week;
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

void Strategy_TodayTradeState(bool &long_taken, bool &short_taken, bool &stopped_out)
  {
   long_taken = false;
   short_taken = false;
   stopped_out = false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   if(!HistorySelect(Strategy_DayStart(TimeCurrent()), TimeCurrent()))
      return;

   const int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      const ENUM_DEAL_REASON deal_reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);

      if(deal_entry == DEAL_ENTRY_IN)
        {
         if(deal_type == DEAL_TYPE_BUY)
            long_taken = true;
         if(deal_type == DEAL_TYPE_SELL)
            short_taken = true;
        }

      if(deal_entry == DEAL_ENTRY_OUT && deal_reason == DEAL_REASON_SL)
         stopped_out = true;
     }
  }

bool Strategy_DailyAtrFilterAllowsTrade()
  {
   if(strategy_daily_atr_lookback < 20)
      return true;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double atr_values[];
   ArrayResize(atr_values, strategy_daily_atr_lookback);
   int count = 0;

   for(int shift = 1; shift <= strategy_daily_atr_lookback; ++shift)
     {
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr_value > 0.0)
        {
         atr_values[count] = atr_value;
         ++count;
        }
     }

   if(count < 20)
      return false;

   ArrayResize(atr_values, count);
   ArraySort(atr_values);

   double pct = strategy_daily_atr_percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;

   int pct_index = (int)MathFloor((pct / 100.0) * (count - 1));
   if(pct_index < 0)
      pct_index = 0;
   if(pct_index >= count)
      pct_index = count - 1;

   return current_atr >= atr_values[pct_index];
  }

bool Strategy_SpreadAllowsTrade()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return false;

   return true;
  }

// No Trade Filter: time, spread, EIA/news-day suppression.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int hhmm = Strategy_Hhmm(broker_now);

   if(hhmm < strategy_session_start_hhmm || hhmm >= strategy_flatten_hhmm)
      return true;

   if(strategy_skip_eia_day && Strategy_DayOfWeek(broker_now) == strategy_eia_day_of_week)
      return true;

   if(!Strategy_SpreadAllowsTrade())
      return true;

   return false;
  }

// Trade Entry: fade prior-day/five-session extremes after closed-bar reclaim.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M15)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   bool long_taken = false;
   bool short_taken = false;
   bool stopped_out = false;
   Strategy_TodayTradeState(long_taken, short_taken, stopped_out);
   if(stopped_out)
      return false;

   if(!Strategy_DailyAtrFilterAllowsTrade())
      return false;

   const double prev_day_low = iLow(_Symbol, PERIOD_D1, 1);      // perf-allowed: fixed closed-bar D1 trigger; no QM_Low helper exists.
   const double prev_day_high = iHigh(_Symbol, PERIOD_D1, 1);    // perf-allowed: fixed closed-bar D1 trigger; no QM_High helper exists.
   const double prev_day_close = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: fixed closed-bar D1 target; no QM_Close helper exists.
   const double fifth_day_low = iLow(_Symbol, PERIOD_D1, 5);     // perf-allowed: fixed closed-bar D1 trigger; no QM_Low helper exists.
   const double fifth_day_high = iHigh(_Symbol, PERIOD_D1, 5);   // perf-allowed: fixed closed-bar D1 trigger; no QM_High helper exists.

   if(prev_day_low <= 0.0 || prev_day_high <= 0.0 || prev_day_close <= 0.0 ||
      fifth_day_low <= 0.0 || fifth_day_high <= 0.0)
      return false;

   const double low_trigger = MathMin(prev_day_low, fifth_day_low);
   const double high_trigger = MathMax(prev_day_high, fifth_day_high);

   const double bar_low = iLow(_Symbol, PERIOD_M15, 1);       // perf-allowed: fixed closed-bar reclaim test; no QM_Low helper exists.
   const double bar_high = iHigh(_Symbol, PERIOD_M15, 1);     // perf-allowed: fixed closed-bar reclaim test; no QM_High helper exists.
   const double bar_close = iClose(_Symbol, PERIOD_M15, 1);   // perf-allowed: fixed closed-bar reclaim test; no QM_Close helper exists.
   if(bar_low <= 0.0 || bar_high <= 0.0 || bar_close <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   double entry_price = 0.0;
   if(!long_taken && bar_low < low_trigger && bar_close > low_trigger)
     {
      req.type = QM_BUY;
      req.reason = "LOW_TRIGGER_RECLAIM_LONG";
      entry_price = ask;
     }
   else if(!short_taken && bar_high > high_trigger && bar_close < high_trigger)
     {
      req.type = QM_SELL;
      req.reason = "HIGH_TRIGGER_RECLAIM_SHORT";
      entry_price = bid;
     }
   else
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || MathAbs(entry_price - req.sl) / point <= 0.0)
      return false;

   if(strategy_use_vwap_proxy_tp)
     {
      const double target = QM_StopRulesNormalizePrice(_Symbol, (prev_day_high + prev_day_low + prev_day_close) / 3.0);
      const bool target_valid = (req.type == QM_BUY && target > entry_price) ||
                                (req.type == QM_SELL && target < entry_price);
      req.tp = target_valid ? target : 0.0;
     }
   else
      req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_tp_rr);

   return true;
  }

// Trade Management: card specifies no trailing, break-even, partial close, or scale-in.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: flatten all open positions before crude session end.
bool Strategy_ExitSignal()
  {
   return Strategy_Hhmm(TimeCurrent()) >= strategy_flatten_hhmm;
  }

// News Filter Hook: EIA inventory release-day proxy; central V5 news filters still run.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_skip_eia_day && Strategy_DayOfWeek(broker_time) == strategy_eia_day_of_week)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1123_unger_crude_prevday_meanrev\"}");
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
