#property strict
#property version   "5.0"
#property description "QM5_10949 zuck-fri-band"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10949;
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
input int    strategy_window_start_hour   = 16;
input int    strategy_window_start_min    = 30;
input int    strategy_window_end_hour     = 19;
input int    strategy_window_end_min      = 0;
input int    strategy_exit_hour_broker    = 20;
input int    strategy_exit_min_broker     = 30;
input double strategy_return_atr_mult     = 0.35;
input double strategy_min_range_atr_mult  = 0.50;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 1.0;
input double strategy_spread_pct_of_atr   = 15.0;
input int    strategy_scan_bars           = 200;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): central framework handles news and
// Friday close; this strategy adds the card's spread cap without fail-closing
// on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_atr_period <= 0 ||
      strategy_window_start_hour < 0 || strategy_window_start_hour > 23 ||
      strategy_window_end_hour < 0 || strategy_window_end_hour > 23 ||
      strategy_window_start_min < 0 || strategy_window_start_min > 59 ||
      strategy_window_end_min < 0 || strategy_window_end_min > 59 ||
      strategy_exit_hour_broker < 0 || strategy_exit_hour_broker > 23 ||
      strategy_exit_min_broker < 0 || strategy_exit_min_broker > 59)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_m15 <= 0.0)
      return false;

   const double spread = ask - bid;
   if(ask > bid && spread > (strategy_spread_pct_of_atr / 100.0) * atr_m15)
      return true;

   return false;
  }

// Trade Entry: Friday morning-range continuation breakout, long-only.
// Caller guarantees QM_IsNewBar() == true, so the bounded CopyRates scan runs
// once per closed bar rather than once per tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int scan_bars = (strategy_scan_bars < 50) ? 50 : strategy_scan_bars;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, _Period, 1, scan_bars, rates); // perf-allowed
   if(copied <= 0)
      return false;

   datetime latest_time = 0;
   int latest_index = -1;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time > latest_time)
        {
         latest_time = rates[i].time;
         latest_index = i;
        }
     }
   if(latest_index < 0)
      return false;

   MqlDateTime latest_dt;
   TimeToStruct(latest_time, latest_dt);
   if(latest_dt.day_of_week != 5)
      return false;

   const int window_start_min = strategy_window_start_hour * 60 + strategy_window_start_min;
   const int window_end_min   = strategy_window_end_hour * 60 + strategy_window_end_min;
   const int exit_min         = strategy_exit_hour_broker * 60 + strategy_exit_min_broker;
   const int latest_min       = latest_dt.hour * 60 + latest_dt.min;
   if(window_end_min <= window_start_min)
      return false;
   if(latest_min < window_end_min || latest_min >= exit_min)
      return false;

   const datetime day_start = latest_time - (latest_dt.hour * 3600 + latest_dt.min * 60 + latest_dt.sec);
   if(HistorySelect(day_start, TimeCurrent()))
     {
      const int deals = HistoryDealsTotal();
      const int magic = QM_FrameworkMagic();
      for(int d = 0; d < deals; ++d)
        {
         const ulong deal_ticket = HistoryDealGetTicket(d);
         if(deal_ticket == 0)
            continue;
         if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
            continue;
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            return false;
        }
     }

   bool have_window_bar = false;
   double morning_high = 0.0;
   double morning_low = 0.0;
   double morning_open = 0.0;
   double morning_close = 0.0;
   datetime earliest_window_time = 0;
   datetime latest_window_time = 0;

   for(int j = 0; j < copied; ++j)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[j].time, bar_dt);
      if(bar_dt.year != latest_dt.year || bar_dt.mon != latest_dt.mon || bar_dt.day != latest_dt.day)
         continue;

      const int bar_min = bar_dt.hour * 60 + bar_dt.min;
      if(bar_min < window_start_min || bar_min >= window_end_min)
         continue;
      if(rates[j].high <= 0.0 || rates[j].low <= 0.0)
         continue;

      if(!have_window_bar)
        {
         morning_high = rates[j].high;
         morning_low = rates[j].low;
         morning_open = rates[j].open;
         morning_close = rates[j].close;
         earliest_window_time = rates[j].time;
         latest_window_time = rates[j].time;
         have_window_bar = true;
        }
      else
        {
         morning_high = MathMax(morning_high, rates[j].high);
         morning_low = MathMin(morning_low, rates[j].low);
         if(rates[j].time < earliest_window_time)
           {
            earliest_window_time = rates[j].time;
            morning_open = rates[j].open;
           }
         if(rates[j].time > latest_window_time)
           {
            latest_window_time = rates[j].time;
            morning_close = rates[j].close;
           }
        }
     }

   if(!have_window_bar || morning_high <= 0.0 || morning_low <= 0.0)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double range_width = morning_high - morning_low;
   if(range_width < strategy_min_range_atr_mult * atr_h1)
      return false;

   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_m15 <= 0.0)
      return false;
   const double morning_return = morning_close - morning_open;
   if(!(morning_return > strategy_return_atr_mult * atr_m15))
      return false;

   const double close1 = rates[latest_index].close;
   if(!(close1 > morning_high))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_m15, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "zuck_fri_band_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: card specifies no trailing, partial, or break-even logic.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: Friday session-close proxy, before the framework hard Friday
// close backstop.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 5)
      return true;

   const int now_min = dt.hour * 60 + dt.min;
   const int exit_min = strategy_exit_hour_broker * 60 + strategy_exit_min_broker;
   return (now_min >= exit_min);
  }

// News Filter Hook: use the central framework news gate for scheduled Friday
// high-impact events.
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
