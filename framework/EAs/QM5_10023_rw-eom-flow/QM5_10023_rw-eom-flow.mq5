#property strict
#property version   "5.0"
#property description "QM5_10023 Robot Wealth End-of-Month Flow"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10023;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_days_before_eom = 3;
input int    strategy_rv_days               = 20;
input int    strategy_rv_median_days        = 252;
input bool   strategy_use_vol_filter        = true;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 1.5;
input int    strategy_max_spread_points     = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool StrategySymbolInBasket(const string symbol)
  {
   return (symbol == "SP500.DWX" || symbol == "NDX.DWX" || symbol == "WS30.DWX");
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!StrategySymbolInBasket(_Symbol))
      return true;

   if(_Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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
   const datetime entry_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke EOM calendar math; O(1) cached bar lookup; no QM_* equivalent
   if(entry_bar <= 0)
      return false;

   MqlDateTime entry_dt;
   TimeToStruct(entry_bar, entry_dt);

   int trading_days_after_entry = 0;
   for(int day = 1; day <= 10; ++day)
     {
      MqlDateTime candidate_dt = entry_dt;
      candidate_dt.hour = 0;
      candidate_dt.min = 0;
      candidate_dt.sec = 0;
      const datetime candidate_time = StructToTime(candidate_dt) + day * 86400;
      TimeToStruct(candidate_time, candidate_dt);
      if(candidate_dt.mon != entry_dt.mon)
         break;
      if(candidate_dt.day_of_week >= 1 && candidate_dt.day_of_week <= 5)
         trading_days_after_entry++;
      if(trading_days_after_entry > strategy_entry_days_before_eom)
         break;
     }

   if(trading_days_after_entry != strategy_entry_days_before_eom)
      return false;

   if(strategy_use_vol_filter)
     {
      const int rv_days = MathMax(2, strategy_rv_days);
      const int median_days = MathMax(5, strategy_rv_median_days);
      const int returns_needed = rv_days + median_days;
      const int closes_needed = returns_needed + 1;

      double closes[];
      ArraySetAsSeries(closes, true);
      const int copied = CopyClose(_Symbol, PERIOD_D1, 1, closes_needed, closes); // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
      if(copied < closes_needed)
         return false;

      double returns[];
      ArrayResize(returns, returns_needed);
      for(int i = 0; i < returns_needed; ++i)
        {
         if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
            return false;
         returns[i] = MathLog(closes[i] / closes[i + 1]);
        }

      double rv_values[];
      ArrayResize(rv_values, median_days);
      double sum = 0.0;
      double sum_sq = 0.0;
      for(int j = 0; j < rv_days; ++j)
        {
         sum += returns[j];
         sum_sq += returns[j] * returns[j];
        }

      for(int window = 0; window < median_days; ++window)
        {
         if(window > 0)
           {
            const double old_ret = returns[window - 1];
            const double new_ret = returns[window + rv_days - 1];
            sum += new_ret - old_ret;
            sum_sq += new_ret * new_ret - old_ret * old_ret;
           }

         const double mean = sum / rv_days;
         double variance = (sum_sq / rv_days) - (mean * mean);
         if(variance < 0.0)
            variance = 0.0;
         rv_values[window] = MathSqrt(variance) * MathSqrt(252.0);
        }

      const double current_rv = rv_values[0];
      ArraySort(rv_values);
      const double median_rv = (median_days % 2 == 1)
                               ? rv_values[median_days / 2]
                               : 0.5 * (rv_values[(median_days / 2) - 1] + rv_values[median_days / 2]);

      if(current_rv <= 0.0 || median_rv <= 0.0 || current_rv >= median_rv)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "RW_EOM_FLOW_T_MINUS_3";

   return (req.sl > 0.0 && req.sl < ask && ((ask - req.sl) / point) > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Baseline card has no trailing stop, break-even, partial, or TP management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   datetime open_time = 0;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;
   const datetime first_month_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke EOM month-rollover detection; O(1) cached lookup
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 2); // perf-allowed: bespoke EOM month-rollover detection; O(1) cached lookup
   if(first_month_bar <= 0 || prior_bar <= 0)
      return false;

   MqlDateTime first_dt;
   MqlDateTime prior_dt;
   MqlDateTime open_dt;
   TimeToStruct(first_month_bar, first_dt);
   TimeToStruct(prior_bar, prior_dt);
   TimeToStruct(open_time, open_dt);

   if(first_dt.mon == prior_dt.mon)
      return false;
   if(open_time >= first_month_bar)
      return false;
   if(open_dt.mon == first_dt.mon && open_dt.year == first_dt.year)
      return false;

   return true;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - unchanged from template.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10023\",\"ea\":\"rw_eom_flow\"}");
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
