#property strict
#property version   "5.0"
#property description "QM5_1196 Quantpedia FX Linear Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1196;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.1667;

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
input int    strategy_min_monthly_observations = 24;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.0;
input int    strategy_spread_median_days       = 20;
input double strategy_spread_mult              = 3.0;
input double strategy_min_deviation_pct        = 0.05;
input int    strategy_stale_rebalance_days     = 5;
input double strategy_basket_kill_mult         = 2.5;

#define QM5_1196_LEG_COUNT 6

string g_symbols[QM5_1196_LEG_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX"
  };

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1196_LEG_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDJPY.DWX" || symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX");
  }

int Strategy_RebalanceKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsMonthEndClosedBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1196_LEG_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_NormalizedCurrencyValue(const string symbol, double &value)
  {
   value = 0.0;
   if(!SymbolSelect(symbol, true))
      return false;

   const int min_bars = MathMax(strategy_min_monthly_observations + 3, 30);
   if(Bars(symbol, PERIOD_MN1) < min_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, 1);
   const double base_close = iClose(symbol, PERIOD_MN1, strategy_min_monthly_observations + 1);
   if(recent_close <= 0.0 || base_close <= 0.0)
      return false;

   if(Strategy_IsUsdBaseSymbol(symbol))
      value = (base_close / recent_close) - 1.0;
   else
      value = (recent_close / base_close) - 1.0;

   return MathIsValidNumber(value);
  }

bool Strategy_BasketStats(double &basket_average, double &current_value, double &deviation, int &eligible_count)
  {
   basket_average = 0.0;
   current_value = 0.0;
   deviation = 0.0;
   eligible_count = 0;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return false;

   double sum = 0.0;
   bool current_seen = false;
   for(int i = 0; i < QM5_1196_LEG_COUNT; ++i)
     {
      double value = 0.0;
      if(!Strategy_NormalizedCurrencyValue(g_symbols[i], value))
         continue;
      sum += value;
      ++eligible_count;
      if(i == current_index)
        {
         current_value = value;
         current_seen = true;
        }
     }

   if(eligible_count < QM5_1196_LEG_COUNT || !current_seen)
      return false;

   basket_average = sum / (double)eligible_count;
   deviation = current_value - basket_average;
   return MathIsValidNumber(basket_average) && MathIsValidNumber(deviation);
  }

int Strategy_DirectionForCurrentSymbol(double &deviation, double &basket_average, double &current_value)
  {
   deviation = 0.0;
   basket_average = 0.0;
   current_value = 0.0;

   int eligible = 0;
   if(!Strategy_BasketStats(basket_average, current_value, deviation, eligible))
      return 0;

   const double threshold = MathMax(strategy_min_deviation_pct, 0.0) / 100.0;
   if(MathAbs(deviation) < threshold)
      return 0;

   int foreign_direction = (deviation < 0.0) ? 1 : -1;
   if(Strategy_IsUsdBaseSymbol(_Symbol))
      foreign_direction = -foreign_direction;
   return foreign_direction;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
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
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_StopDistanceAllowed(const ENUM_ORDER_TYPE type, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(type == ORDER_TYPE_BUY && sl >= entry)
      return false;
   if(type == ORDER_TYPE_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

double Strategy_IntendedBasketRisk()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT / 100.0;
   return 0.0;
  }

bool Strategy_Is1196Magic(const int magic)
  {
   for(int slot = 0; slot < QM5_1196_LEG_COUNT; ++slot)
      if(magic == qm_ea_id * 10000 + slot)
         return true;
   return false;
  }

double Strategy_BasketFloatingPnl()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_Is1196Magic((int)PositionGetInteger(POSITION_MAGIC)))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

bool Strategy_BasketKillActive()
  {
   const double intended_risk = Strategy_IntendedBasketRisk();
   if(intended_risk <= 0.0 || strategy_basket_kill_mult <= 0.0)
      return false;
   return (Strategy_BasketFloatingPnl() <= -intended_risk * strategy_basket_kill_mult);
  }

void Strategy_Close1196Positions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_Is1196Magic((int)PositionGetInteger(POSITION_MAGIC)))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1196)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != index)
      return true;
   if(strategy_min_monthly_observations < 24)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_stale_rebalance_days < 1)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1196_FX_LINEAR_MEANREV";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double deviation = 0.0;
   double basket_average = 0.0;
   double current_value = 0.0;
   const int direction = Strategy_DirectionForCurrentSymbol(deviation, basket_average, current_value);
   if(direction == 0)
      return false;

   const double entry = (direction > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0 ? QM_BUY : QM_SELL);
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.symbol_slot = qm_magic_slot_offset;
   if(!Strategy_StopDistanceAllowed((direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entry, req.sl))
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   QM_LogEvent(QM_INFO, "FX_MEANREV_SIGNAL_ON",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"direction\":%d,\"current_value\":%.6f,\"basket_average\":%.6f,\"deviation\":%.6f}",
                            _Symbol, req.symbol_slot, direction, current_value, basket_average, deviation));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_BasketKillActive())
      Strategy_Close1196Positions();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const int shift_since_open = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   const int stale_limit = 23 + strategy_stale_rebalance_days;
   if(shift_since_open >= stale_limit)
      return true;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   double deviation = 0.0;
   double basket_average = 0.0;
   double current_value = 0.0;
   const int desired_direction = Strategy_DirectionForCurrentSymbol(deviation, basket_average, current_value);

   const long pos_type = PositionGetInteger(POSITION_TYPE);
   const int current_direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
   if(desired_direction == 0 || desired_direction != current_direction)
     {
      g_last_exit_rebalance_key = rebalance_key;
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_MN1, strategy_min_monthly_observations + 5);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_atr_period_d1 + strategy_spread_median_days + 10, 80));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1196\",\"strategy\":\"qp-fx-meanrev-linear\"}");
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
