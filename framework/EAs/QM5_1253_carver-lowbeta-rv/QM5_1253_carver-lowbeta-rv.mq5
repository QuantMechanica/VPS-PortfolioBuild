#property strict
#property version   "5.0"
#property description "QM5_1253 Carver Low-Beta Relative Value"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1253;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.090909;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_beta_lookback_days  = 756;
input double strategy_long_quantile       = 0.25;
input double strategy_short_quantile      = 0.25;
input double strategy_exit_long_quantile  = 0.35;
input double strategy_exit_short_quantile = 0.35;
input int    strategy_max_slots_per_side  = 2;
input int    strategy_min_group_breadth   = 4;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input double strategy_group_stop_r        = 2.0;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 2.0;

#define QM5_1253_SYMBOL_COUNT 11
#define QM5_1253_MAX_GROUP    6

string g_symbols[QM5_1253_SYMBOL_COUNT] =
  {
   "GER40.DWX", "NDX.DWX", "WS30.DWX", "UK100.DWX", "FRA40.DWX",
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX"
  };

int g_groups[QM5_1253_SYMBOL_COUNT] =
  {
   0, 0, 0, 0, 0,
   1, 1, 1, 1, 1, 1
  };

int g_last_entry_month = 0;
int g_last_exit_month  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1253_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const datetime last_closed = iTime(_Symbol, PERIOD_D1, 1);
   const datetime prior = iTime(_Symbol, PERIOD_D1, 2);
   if(last_closed <= 0 || prior <= 0)
      return false;
   return (Strategy_MonthKey(last_closed) != Strategy_MonthKey(prior));
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1253_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

int Strategy_GroupMembers(const int group_id, string &members[], int &slots[])
  {
   int count = 0;
   for(int i = 0; i < QM5_1253_SYMBOL_COUNT; ++i)
     {
      if(g_groups[i] != group_id)
         continue;
      members[count] = g_symbols[i];
      slots[count] = i;
      ++count;
     }
   return count;
  }

bool Strategy_HasOpenPosition(ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
   const int magic = QM_FrameworkMagic();
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
      direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

double Strategy_Median(double &values[], const int count)
  {
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
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

double Strategy_Return(const string symbol, const int shift)
  {
   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;
   return (c0 - c1) / c1;
  }

bool Strategy_GroupBetas(const int group_id, string &members[], int &slots[], int &member_count, double &betas[])
  {
   member_count = Strategy_GroupMembers(group_id, members, slots);
   if(member_count < strategy_min_group_breadth || member_count > QM5_1253_MAX_GROUP)
      return false;

   const int lookback = MathMax(60, strategy_beta_lookback_days);
   for(int i = 0; i < member_count; ++i)
      if(Bars(members[i], PERIOD_D1) < lookback + 10)
         return false;

   double group_returns[];
   ArrayResize(group_returns, lookback);
   double group_mean = 0.0;
   for(int bar = 1; bar <= lookback; ++bar)
     {
      double sum = 0.0;
      for(int i = 0; i < member_count; ++i)
         sum += Strategy_Return(members[i], bar);
      const double group_return = sum / (double)member_count;
      group_returns[bar - 1] = group_return;
      group_mean += group_return;
     }
   group_mean /= (double)lookback;

   double group_var = 0.0;
   for(int i = 0; i < lookback; ++i)
      group_var += (group_returns[i] - group_mean) * (group_returns[i] - group_mean);
   if(group_var <= 0.0)
      return false;

   for(int member = 0; member < member_count; ++member)
     {
      double sym_mean = 0.0;
      double sym_returns[];
      ArrayResize(sym_returns, lookback);
      for(int bar = 1; bar <= lookback; ++bar)
        {
         const double ret = Strategy_Return(members[member], bar);
         sym_returns[bar - 1] = ret;
         sym_mean += ret;
        }
      sym_mean /= (double)lookback;

      double cov = 0.0;
      for(int i = 0; i < lookback; ++i)
         cov += (sym_returns[i] - sym_mean) * (group_returns[i] - group_mean);
      betas[member] = cov / group_var;
     }
   return true;
  }

int Strategy_RankByBeta(const string symbol, double &betas[], string &members[], const int member_count)
  {
   int better = 0;
   int own = -1;
   for(int i = 0; i < member_count; ++i)
      if(members[i] == symbol)
         own = i;
   if(own < 0)
      return -1;

   for(int i = 0; i < member_count; ++i)
      if(i != own && betas[i] < betas[own])
         ++better;
   return better;
  }

bool Strategy_AllowedBySpread()
  {
   const int lookback = MathMax(5, MathMin(strategy_spread_median_days, 128));
   double spreads[128];
   int count = 0;
   for(int i = 1; i <= lookback; ++i)
     {
      const long raw_spread = (long)iSpread(_Symbol, PERIOD_D1, i);
      if(raw_spread <= 0)
         continue;
      spreads[count] = (double)raw_spread;
      ++count;
     }
   if(count < MathMax(3, lookback / 2))
      return true;
   const double median = Strategy_Median(spreads, count);
   const long current = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median <= 0.0 || current <= 0)
      return true;
   return ((double)current <= strategy_spread_mult * median);
  }

bool Strategy_StopDistanceAllowed(const ENUM_ORDER_TYPE order_type, const double entry, const double sl)
  {
   if(sl <= 0.0)
      return false;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level <= 0)
      return true;
   const double min_dist = (double)stops_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(order_type == ORDER_TYPE_BUY)
      return (entry - sl >= min_dist);
   return (sl - entry >= min_dist);
  }

bool Strategy_IsAllowedSlot(const string symbol, const int direction)
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;

   string members[QM5_1253_MAX_GROUP];
   int slots[QM5_1253_MAX_GROUP];
   double betas[QM5_1253_MAX_GROUP];
   int member_count = 0;
   if(!Strategy_GroupBetas(g_groups[idx], members, slots, member_count, betas))
      return false;

   const int rank = Strategy_RankByBeta(symbol, betas, members, member_count);
   if(rank < 0)
      return false;

   int side_cap = (int)MathFloor((double)member_count * ((direction > 0) ? strategy_long_quantile : strategy_short_quantile));
   side_cap = MathMax(1, MathMin(strategy_max_slots_per_side, side_cap));

   if(direction > 0)
      return (rank < side_cap);
   return (rank >= member_count - side_cap);
  }

bool Strategy_ShouldExitByRank(const int open_direction)
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;

   string members[QM5_1253_MAX_GROUP];
   int slots[QM5_1253_MAX_GROUP];
   double betas[QM5_1253_MAX_GROUP];
   int member_count = 0;
   if(!Strategy_GroupBetas(g_groups[idx], members, slots, member_count, betas))
      return true;

   const int rank = Strategy_RankByBeta(_Symbol, betas, members, member_count);
   if(rank < 0)
      return true;

   int long_keep = (int)MathCeil((double)member_count * strategy_exit_long_quantile);
   int short_keep = (int)MathCeil((double)member_count * strategy_exit_short_quantile);
   long_keep = MathMax(1, MathMin(member_count, long_keep));
   short_keep = MathMax(1, MathMin(member_count, short_keep));

   if(open_direction > 0)
      return (rank >= long_keep);
   return (rank < member_count - short_keep);
  }

void Strategy_ApplyGroupStop()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0 || strategy_group_stop_r <= 0.0)
      return;

   const int group_id = g_groups[idx];
   double group_profit = 0.0;
   ulong tickets[QM5_1253_MAX_GROUP];
   int ticket_count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const string pos_symbol = PositionGetString(POSITION_SYMBOL);
      int pos_slot = -1;
      for(int s = 0; s < QM5_1253_SYMBOL_COUNT; ++s)
         if(g_symbols[s] == pos_symbol && g_groups[s] == group_id)
            pos_slot = s;
      if(pos_slot < 0)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_Magic(qm_ea_id, pos_slot))
         continue;

      group_profit += PositionGetDouble(POSITION_PROFIT);
      if(ticket_count < QM5_1253_MAX_GROUP)
        {
         tickets[ticket_count] = ticket;
         ++ticket_count;
        }
     }

   if(group_profit >= -strategy_group_stop_r * RISK_FIXED)
      return;

   for(int i = 0; i < ticket_count; ++i)
      QM_TM_ClosePosition(tickets[i], QM_EXIT_STRATEGY);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1253)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != index)
      return true;
   if(strategy_beta_lookback_days < 60 || strategy_min_group_breadth < 4)
      return true;
   if(strategy_long_quantile <= 0.0 || strategy_short_quantile <= 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1253_CARVER_LOWBETA_RV";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalance())
      return false;

   const int month = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1));
   if(month <= 0 || month == g_last_entry_month)
      return false;
   if(!Strategy_AllowedBySpread())
      return false;

   ulong ticket = 0;
   int open_direction = 0;
   if(Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   int direction = 0;
   if(Strategy_IsAllowedSlot(_Symbol, 1))
      direction = 1;
   else if(Strategy_IsAllowedSlot(_Symbol, -1))
      direction = -1;
   if(direction == 0)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.symbol_slot = qm_magic_slot_offset;
   if(!Strategy_StopDistanceAllowed((direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entry, req.sl))
      return false;

   g_last_entry_month = month;
   QM_LogEvent(QM_INFO, "CARVER_LOWBETA_RV_SIGNAL_ON",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"direction\":%d}",
                            _Symbol, req.symbol_slot, direction));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_ApplyGroupStop();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   int open_direction = 0;
   if(!Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   if(!Strategy_IsMonthlyRebalance())
      return false;

   const int month = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1));
   if(month <= 0 || month == g_last_exit_month)
      return false;

   if(Strategy_ShouldExitByRank(open_direction))
     {
      g_last_exit_month = month;
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
   Strategy_SelectSymbols();

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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_beta_lookback_days + 20);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1253\",\"strategy\":\"carver-lowbeta-rv\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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

