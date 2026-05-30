#property strict
#property version   "5.0"
#property description "QM5_1198 Quantpedia SP500 High Return Fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1198;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rank_lookback_d1    = 250;
input int    strategy_top_rank_count      = 25;
input int    strategy_min_history_d1_bars = 270;
input int    strategy_atr_period_d1       = 20;
input double strategy_stop_atr_mult       = 2.0;
input double strategy_gap_risk_mult       = 2.5;
input int    strategy_hold_trading_days   = 1;
input int    strategy_entry_hhmm_broker   = 1630;
input int    strategy_exit_hhmm_broker    = 2300;
input int    strategy_safety_exit_hhmm    = 2330;
input int    strategy_spread_m30_days     = 20;
input double strategy_spread_median_mult  = 3.0;
input int    strategy_max_spread_points   = 0;

datetime g_last_entry_signal_day = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsAllowedSymbol()
  {
   return (_Symbol == "SP500.DWX");
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

double Strategy_PlannedRiskMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED * PORTFOLIO_WEIGHT;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT / 100.0 * PORTFOLIO_WEIGHT;
   return 0.0;
  }

void Strategy_SortDoubleArray(double &values[])
  {
   const int n = ArraySize(values);
   for(int i = 1; i < n; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }
  }

double Strategy_MedianM30Spread()
  {
   const int bars_needed = MathMax(1, strategy_spread_m30_days) * 48;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, bars_needed, rates); // perf-allowed: called only from EntrySignal after framework new-bar gate.
   if(copied <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[count] = (double)rates[i].spread;
      ++count;
     }
   if(count <= 0)
      return 0.0;

   ArrayResize(spreads, count);
   Strategy_SortDoubleArray(spreads);
   if((count % 2) == 1)
      return spreads[count / 2];
   return (spreads[count / 2 - 1] + spreads[count / 2]) * 0.5;
  }

bool Strategy_SpreadAllowed()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && current_spread > strategy_max_spread_points)
      return false;

   const double median_spread = Strategy_MedianM30Spread();
   if(median_spread <= 0.0)
      return true;
   return ((double)current_spread <= median_spread * MathMax(1.0, strategy_spread_median_mult));
  }

bool Strategy_IsHighReturnTailSignal()
  {
   const int lookback = MathMax(10, strategy_rank_lookback_d1);
   const int top_count = MathMax(1, MathMin(strategy_top_rank_count, lookback));
   const int required = MathMax(strategy_min_history_d1_bars, lookback + strategy_atr_period_d1 + 5);
   if(Bars(_Symbol, PERIOD_D1) < required)
      return false;

   const double close_signal = iClose(_Symbol, PERIOD_D1, 1);
   const double close_prev = iClose(_Symbol, PERIOD_D1, 2);
   if(close_signal <= 0.0 || close_prev <= 0.0)
      return false;

   const double signal_return = (close_signal / close_prev) - 1.0;
   int higher_count = 0;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double close_a = iClose(_Symbol, PERIOD_D1, shift);
      const double close_b = iClose(_Symbol, PERIOD_D1, shift + 1);
      if(close_a <= 0.0 || close_b <= 0.0)
         return false;

      const double prior_return = (close_a / close_b) - 1.0;
      if(prior_return > signal_return)
         ++higher_count;
     }

   return (higher_count < top_count);
  }

int Strategy_HeldD1Bars(const datetime open_time)
  {
   const int open_shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
   if(open_shift < 0)
      return 0;
   return open_shift;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsAllowedSymbol())
      return true;
   if(!SymbolSelect(_Symbol, true))
      return true;
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QP_SP500_HIGHRET_FADE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(Strategy_Hhmm(broker_now) < strategy_entry_hhmm_broker)
      return false;

   const datetime signal_day = Strategy_DayKey(iTime(_Symbol, PERIOD_D1, 1));
   if(signal_day <= 0 || g_last_entry_signal_day == signal_day)
      return false;

   if(!Strategy_SpreadAllowed())
      return false;
   if(!Strategy_IsHighReturnTailSignal())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || bid <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_stop_atr_mult);
   if(req.sl <= bid)
      return false;

   g_last_entry_signal_day = signal_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed hold and hard stop only; no trailing or partial exits.
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const int hhmm = Strategy_Hhmm(broker_now);
   const int hold_days = MathMax(1, strategy_hold_trading_days);
   const double planned_risk = Strategy_PlannedRiskMoney();
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(planned_risk > 0.0 && PositionGetDouble(POSITION_PROFIT) <= -(strategy_gap_risk_mult * planned_risk))
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_HeldD1Bars(open_time) >= hold_days && hhmm >= strategy_exit_hhmm_broker)
         return true;
      if(Strategy_HeldD1Bars(open_time) > hold_days && hhmm >= strategy_safety_exit_hhmm)
         return true;
     }

   return false;
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
