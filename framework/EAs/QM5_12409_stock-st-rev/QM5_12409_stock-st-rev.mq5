#property strict
#property version   "5.0"
#property description "QM5_12409 Weekly Short-Term Reversal Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12409;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_weekly_return_bars  = 5;
input int    strategy_monthly_return_bars = 21;
input int    strategy_bucket_size         = 1;
input int    strategy_min_d1_bars         = 30;
input int    strategy_min_eligible        = 6;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.0;
input int    strategy_spread_days         = 60;
input double strategy_spread_mult         = 2.0;
input double strategy_basket_stop_r       = 5.0;

#define QM5_12409_SYMBOL_COUNT 7

string g_symbols[QM5_12409_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
  };

int g_slots[QM5_12409_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_12409_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 rebalance anchor.
  }

bool Strategy_IsWeeklyRebalanceDay(const datetime closed_day)
  {
   if(_Period != PERIOD_D1 || closed_day <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(closed_day, dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, QM_OrderType &side)
  {
   ticket = 0;
   opened_at = 0;
   side = QM_BUY;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? QM_SELL : QM_BUY;
      return true;
     }

   return false;
  }

double Strategy_ActiveRiskDollars()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT / 100.0;
   return 0.0;
  }

bool Strategy_BasketStopExceeded()
  {
   const double risk_dollars = Strategy_ActiveRiskDollars();
   if(strategy_basket_stop_r <= 0.0 || risk_dollars <= 0.0)
      return false;

   double open_pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      bool ours = false;
      const int pos_magic = (int)PositionGetInteger(POSITION_MAGIC);
      for(int s = 0; s < QM5_12409_SYMBOL_COUNT; ++s)
        {
         if(pos_magic == QM_Magic(qm_ea_id, g_slots[s]))
           {
            ours = true;
            break;
           }
        }
      if(!ours)
         continue;

      open_pnl += PositionGetDouble(POSITION_PROFIT);
      open_pnl += PositionGetDouble(POSITION_SWAP);
     }

   return (open_pnl < 0.0 && MathAbs(open_pnl) >= strategy_basket_stop_r * risk_dollars);
  }

bool Strategy_ReturnOverBars(const string symbol, const int lookback_bars, double &out_return)
  {
   out_return = 0.0;
   if(lookback_bars <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   if(!SymbolSelect(symbol, true))
      return false;
   if(Bars(symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, lookback_bars + 5))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);                  // perf-allowed: bounded D1 basket return read after new-bar gate.
   const double past_close = iClose(symbol, PERIOD_D1, 1 + lookback_bars);    // perf-allowed: bounded D1 basket return read after new-bar gate.
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   out_return = (recent_close / past_close) - 1.0;
   return true;
  }

int Strategy_BuildReturnTables(bool &eligible[], double &week_ret[], double &month_ret[])
  {
   ArrayInitialize(eligible, false);
   ArrayInitialize(week_ret, 0.0);
   ArrayInitialize(month_ret, 0.0);

   int count = 0;
   for(int i = 0; i < QM5_12409_SYMBOL_COUNT; ++i)
     {
      double wr = 0.0;
      double mr = 0.0;
      if(!Strategy_ReturnOverBars(g_symbols[i], strategy_weekly_return_bars, wr))
         continue;
      if(!Strategy_ReturnOverBars(g_symbols[i], strategy_monthly_return_bars, mr))
         continue;

      eligible[i] = true;
      week_ret[i] = wr;
      month_ret[i] = mr;
      ++count;
     }

   return count;
  }

bool Strategy_CurrentSelection(QM_OrderType &out_side)
  {
   out_side = QM_BUY;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0 || strategy_bucket_size <= 0)
      return false;

   bool eligible[QM5_12409_SYMBOL_COUNT];
   double week_ret[QM5_12409_SYMBOL_COUNT];
   double month_ret[QM5_12409_SYMBOL_COUNT];
   const int count = Strategy_BuildReturnTables(eligible, week_ret, month_ret);
   if(count < strategy_min_eligible || !eligible[current_index])
      return false;

   const int bucket_size = MathMax(1, MathMin(strategy_bucket_size, count / 2));
   bool selected_long[QM5_12409_SYMBOL_COUNT];
   bool selected_short[QM5_12409_SYMBOL_COUNT];
   ArrayInitialize(selected_long, false);
   ArrayInitialize(selected_short, false);

   for(int pick = 0; pick < bucket_size; ++pick)
     {
      int best = -1;
      for(int i = 0; i < QM5_12409_SYMBOL_COUNT; ++i)
        {
         if(!eligible[i] || selected_long[i])
            continue;
         if(best < 0 || week_ret[i] < week_ret[best])
            best = i;
        }
      if(best >= 0)
         selected_long[best] = true;
     }

   for(int pick = 0; pick < bucket_size; ++pick)
     {
      int best = -1;
      for(int i = 0; i < QM5_12409_SYMBOL_COUNT; ++i)
        {
         if(!eligible[i] || selected_long[i] || selected_short[i])
            continue;
         if(best < 0 || month_ret[i] > month_ret[best])
            best = i;
        }
      if(best >= 0)
         selected_short[best] = true;
     }

   if(selected_long[current_index])
     {
      out_side = QM_BUY;
      return true;
     }
   if(selected_short[current_index])
     {
      out_side = QM_SELL;
      return true;
     }

   return false;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = MathMin(MathMax(strategy_spread_days, 1), 128);
   double values[128];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 spread sample after new-bar gate.
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   const double median_spread = Strategy_MedianDailySpreadPoints();
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_weekly_return_bars <= 0 || strategy_monthly_return_bars <= 0)
      return true;
   if(strategy_min_d1_bars < strategy_monthly_return_bars + 2)
      return true;
   if(strategy_min_eligible < 2 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
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
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsWeeklyRebalanceDay(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   QM_OrderType selected_side = QM_BUY;
   if(!Strategy_CurrentSelection(selected_side))
      return false;

   const double entry = QM_OrderTypeIsBuy(selected_side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, selected_side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(selected_side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(selected_side) && sl <= entry)
      return false;

   req.type = selected_side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(selected_side) ? "QM5_12409_WEEKLY_REV_LONG"
                                                 : "QM5_12409_MONTHLY_REV_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR emergency stops and basket stop only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(!Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;

   if(Strategy_BasketStopExceeded())
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsWeeklyRebalanceDay(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;

   QM_OrderType selected_side = QM_BUY;
   const bool still_selected = Strategy_CurrentSelection(selected_side);
   g_last_exit_rebalance_day = rebalance_day;
   if(!still_selected)
      return true;
   if(selected_side != open_side)
      return true;

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_d1_bars, strategy_monthly_return_bars + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12409\",\"ea\":\"stock-st-rev\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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
