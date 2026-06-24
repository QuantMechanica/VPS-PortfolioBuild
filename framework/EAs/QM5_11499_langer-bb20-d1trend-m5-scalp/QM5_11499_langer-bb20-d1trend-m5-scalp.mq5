#property strict
#property version   "5.0"
#property description "QM5_11499 Langer BB20 D1 trend M5 scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11499;
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
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input int    strategy_d1_sma_period         = 200;
input int    strategy_sl_lookback_bars      = 5;
input int    strategy_sl_cap_pips           = 20;
input int    strategy_tp_pips               = 20;
input int    strategy_be_trigger_pips       = 10;
input int    strategy_be_buffer_pips        = 1;
input int    strategy_spread_cap_pips       = 15;
input bool   strategy_block_friday_entries  = true;
input bool   strategy_london_session        = true;
input int    strategy_london_start_hour     = 9;
input int    strategy_london_end_hour       = 12;
input bool   strategy_newyork_session       = true;
input int    strategy_newyork_start_hour    = 15;
input int    strategy_newyork_end_hour      = 21;
input int    strategy_order_expiration_bars = 1;

bool InHourWindow(const int hour, const int start_hour, const int end_hour)
  {
   const int s = MathMax(0, MathMin(23, start_hour));
   const int e = MathMax(0, MathMin(23, end_hour));
   if(s == e)
      return true;
   if(s < e)
      return (hour >= s && hour < e);
   return (hour >= s || hour < e);
  }

bool SessionAllowsEntry(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(strategy_block_friday_entries && dt.day_of_week == 5)
      return false;

   bool any_session_enabled = false;
   bool inside = false;

   if(strategy_london_session)
     {
      any_session_enabled = true;
      if(InHourWindow(dt.hour, strategy_london_start_hour, strategy_london_end_hour))
         inside = true;
     }

   if(strategy_newyork_session)
     {
      any_session_enabled = true;
      if(InHourWindow(dt.hour, strategy_newyork_start_hour, strategy_newyork_end_hour))
         inside = true;
     }

   return (!any_session_enabled || inside);
  }

double CurrentSpreadDistance()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return -1.0;
   if(ask > bid)
      return ask - bid;
   return 0.0;
  }

bool HasOurPendingOrder()
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

bool ReadRecentRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, count, rates); // perf-allowed
   return (copied >= count);
  }

double LowestLowFromRates(const MqlRates &rates[], const int lookback)
  {
   double lowest = DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
     {
      if(rates[i].low > 0.0 && rates[i].low < lowest)
         lowest = rates[i].low;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double HighestHighFromRates(const MqlRates &rates[], const int lookback)
  {
   double highest = -DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
     {
      if(rates[i].high > 0.0 && rates[i].high > highest)
         highest = rates[i].high;
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

bool BuildLongRequest(QM_EntryRequest &req,
                      const MqlRates &signal_bar,
                      const MqlRates &rates[],
                      const double spread_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double entry = QM_StopRulesNormalizePrice(_Symbol, signal_bar.high + spread_distance);
   if(entry <= ask)
      return false;

   double sl = LowestLowFromRates(rates, strategy_sl_lookback_bars);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance <= 0.0)
      return false;
   if((entry - sl) > cap_distance)
      sl = entry - cap_distance;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   const double tp = QM_TakeFixedPips(_Symbol, QM_BUY_STOP, entry, strategy_tp_pips);
   if(tp <= entry || sl >= entry)
      return false;

   req.type = QM_BUY_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "BB20_D1TREND_M5_LONG_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(0, strategy_order_expiration_bars) * PeriodSeconds(PERIOD_M5);
   return true;
  }

bool BuildShortRequest(QM_EntryRequest &req,
                       const MqlRates &signal_bar,
                       const MqlRates &rates[],
                       const double spread_distance)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double entry = QM_StopRulesNormalizePrice(_Symbol, signal_bar.low - spread_distance);
   if(entry >= bid)
      return false;

   double sl = HighestHighFromRates(rates, strategy_sl_lookback_bars);
   if(sl <= 0.0 || sl <= entry)
      return false;

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance <= 0.0)
      return false;
   if((sl - entry) > cap_distance)
      sl = entry + cap_distance;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   const double tp = QM_TakeFixedPips(_Symbol, QM_SELL_STOP, entry, strategy_tp_pips);
   if(tp >= entry || sl <= entry)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = "BB20_D1TREND_M5_SHORT_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(0, strategy_order_expiration_bars) * PeriodSeconds(PERIOD_M5);
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!SessionAllowsEntry(TimeCurrent()))
      return true;

   const double spread_distance = CurrentSpreadDistance();
   if(spread_distance < 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && spread_distance > spread_cap)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurPendingOrder())
      return false;

   if(strategy_bb_period < 2 ||
      strategy_bb_deviation <= 0.0 ||
      strategy_d1_sma_period < 2 ||
      strategy_sl_lookback_bars < 1 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_tp_pips <= 0)
      return false;

   const int m5_count = strategy_sl_lookback_bars + 2;
   MqlRates m5[];
   if(!ReadRecentRates(PERIOD_M5, m5_count, m5))
      return false;

   MqlRates d1[];
   if(!ReadRecentRates(PERIOD_D1, 2, d1))
      return false;

   const MqlRates signal_bar = m5[1];
   const double close_d1 = d1[1].close;
   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double spread_distance = CurrentSpreadDistance();

   if(close_d1 <= 0.0 || sma_d1 <= 0.0 || bb_lower <= 0.0 || bb_upper <= 0.0 || spread_distance < 0.0)
      return false;

   const bool d1_up = (close_d1 > sma_d1);
   const bool d1_down = (close_d1 < sma_d1);
   const bool bullish_signal = (signal_bar.close > signal_bar.open);
   const bool bearish_signal = (signal_bar.close < signal_bar.open);

   if(d1_up && bullish_signal && signal_bar.close < bb_lower)
      return BuildLongRequest(req, signal_bar, m5, spread_distance);

   if(d1_down && bearish_signal && signal_bar.close > bb_upper)
      return BuildShortRequest(req, signal_bar, m5, spread_distance);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11499\",\"ea\":\"QM5_11499_langer_bb20_d1trend_m5_scalp\"}");
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
