#property strict
#property version   "5.0"
#property description "QM5_1193 Quantpedia Stress USD Rebound"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1193;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.20;

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
input string strategy_equity_signal_symbol = "SP500.DWX";
input string strategy_oil_primary_symbol   = "XTIUSD.DWX";
input string strategy_oil_fallback_symbol  = "XBRUSD.DWX";
input double strategy_stress_threshold_pct = 0.0;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 1.5;
input int    strategy_safety_hold_days     = 2;
input int    strategy_min_d1_bars          = 30;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_mult          = 3.0;
input double strategy_basket_kill_mult     = 1.2;

#define QM5_1193_LEG_COUNT 5

string g_leg_symbols[QM5_1193_LEG_COUNT] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "AUDUSD.DWX",
   "USDJPY.DWX",
   "USDCAD.DWX"
};

int g_leg_slots[QM5_1193_LEG_COUNT] = {0, 1, 2, 3, 4};
int g_leg_direction[QM5_1193_LEG_COUNT] = {-1, -1, -1, 1, 1};

datetime g_last_entry_signal_day = 0;

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_CurrentLegIndex()
  {
   for(int i = 0; i < QM5_1193_LEG_COUNT; ++i)
      if(g_leg_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentLegIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_leg_slots[index];
  }

int Strategy_DirectionForCurrentSymbol()
  {
   const int index = Strategy_CurrentLegIndex();
   if(index < 0)
      return 0;
   return g_leg_direction[index];
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1193_LEG_COUNT; ++i)
      ok = (SymbolSelect(g_leg_symbols[i], true) && ok);
   if(strategy_equity_signal_symbol != "")
      ok = (SymbolSelect(strategy_equity_signal_symbol, true) && ok);
   if(strategy_oil_primary_symbol != "")
      ok = (SymbolSelect(strategy_oil_primary_symbol, true) && ok);
   if(strategy_oil_fallback_symbol != "")
      SymbolSelect(strategy_oil_fallback_symbol, true);
   return ok;
  }

bool Strategy_DailyReturn(const string symbol, const int shift, double &ret)
  {
   ret = 0.0;
   if(symbol == "")
      return false;
   if(!SymbolSelect(symbol, true))
      return false;
   if(iBars(symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, shift + 3))
      return false;

   const double close_now = iClose(symbol, PERIOD_D1, shift);
   const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   ret = (close_now / close_prev) - 1.0;
   return MathIsValidNumber(ret);
  }

bool Strategy_OilDailyReturn(const int shift, string &used_symbol, double &oil_ret)
  {
   used_symbol = "";
   oil_ret = 0.0;
   if(Strategy_DailyReturn(strategy_oil_primary_symbol, shift, oil_ret))
     {
      used_symbol = strategy_oil_primary_symbol;
      return true;
     }
   if(Strategy_DailyReturn(strategy_oil_fallback_symbol, shift, oil_ret))
     {
      used_symbol = strategy_oil_fallback_symbol;
      return true;
     }
   return false;
  }

bool Strategy_StressSignal(const datetime signal_day, double &equity_ret, double &oil_ret, string &oil_symbol)
  {
   equity_ret = 0.0;
   oil_ret = 0.0;
   oil_symbol = "";

   if(signal_day <= 0)
      return false;
   if(iTime(_Symbol, PERIOD_D1, 1) != signal_day)
      return false;
   if(!Strategy_DailyReturn(strategy_equity_signal_symbol, 1, equity_ret))
      return false;
   if(!Strategy_OilDailyReturn(1, oil_symbol, oil_ret))
      return false;

   const double threshold = strategy_stress_threshold_pct / 100.0;
   return (equity_ret < threshold && oil_ret < threshold);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
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
      return true;
     }

   return false;
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

bool Strategy_Is1193Magic(const int magic)
  {
   for(int slot = 0; slot < QM5_1193_LEG_COUNT; ++slot)
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
      if(!Strategy_Is1193Magic((int)PositionGetInteger(POSITION_MAGIC)))
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

void Strategy_Close1193Positions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_Is1193Magic((int)PositionGetInteger(POSITION_MAGIC)))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1193)
      return true;
   if(Strategy_CurrentLegIndex() < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SlotForCurrentSymbol())
      return true;
   if(strategy_equity_signal_symbol == "" || strategy_oil_primary_symbol == "")
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_safety_hold_days < 1)
      return true;
   if(strategy_min_d1_bars < MathMax(strategy_atr_period_d1 + 5, 10))
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int direction = Strategy_DirectionForCurrentSymbol();
   if(direction == 0)
      return false;

   req.type = (direction > 0 ? QM_BUY : QM_SELL);
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1193_STRESS_USD_REBOUND";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_day <= 0 || g_last_entry_signal_day == signal_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   double equity_ret = 0.0;
   double oil_ret = 0.0;
   string oil_symbol = "";
   if(!Strategy_StressSignal(signal_day, equity_ret, oil_ret, oil_symbol))
      return false;

   const double entry = (direction > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed((direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entry, req.sl))
      return false;

   g_last_entry_signal_day = signal_day;
   QM_LogEvent(QM_INFO, "STRESS_USD_SIGNAL_ON",
               StringFormat("{\"signal_day\":%I64d,\"leg\":\"%s\",\"slot\":%d,\"direction\":%d,\"equity_ret\":%.6f,\"oil_ret\":%.6f,\"oil_symbol\":\"%s\"}",
                            (long)signal_day, _Symbol, req.symbol_slot, direction, equity_ret, oil_ret, oil_symbol));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_BasketKillActive())
      Strategy_Close1193Positions();
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   const int open_day_key = Strategy_DayKey(opened_at);
   const int current_day_key = Strategy_DayKey(current_day);
   if(open_day_key > 0 && current_day_key > open_day_key)
      return true;

   const int shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   return (shift >= MathMax(2, strategy_safety_hold_days));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1193\",\"strategy\":\"qp-stress-usd-rebound\"}");
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
