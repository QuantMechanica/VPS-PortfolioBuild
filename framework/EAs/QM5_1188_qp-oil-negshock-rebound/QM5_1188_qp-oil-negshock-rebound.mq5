#property strict
#property version   "5.0"
#property description "QM5_1188 Quantpedia Oil Negative-Shock Rebound"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1188;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 20;
input double strategy_shock_atr_mult      = 2.0;
input int    strategy_atr_percentile_bars = 252;
input double strategy_min_atr_percentile  = 70.0;
input double strategy_sl_atr_mult         = 1.0;
input int    strategy_safety_hold_days    = 2;
input int    strategy_min_history_bars    = 275;
input int    strategy_max_spread_points   = 0;
input bool   strategy_skip_friday_signal  = true;

#define QM5_1188_SYMBOL_COUNT 2

string g_symbols[QM5_1188_SYMBOL_COUNT] = {
   "XTIUSD.DWX",
   "XBRUSD.DWX"
};

int g_slots[QM5_1188_SYMBOL_COUNT] = {0, 1};

datetime g_last_entry_signal_day = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1188_SYMBOL_COUNT; ++i)
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

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1188_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
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

bool Strategy_DailyReturn(const int shift, double &ret)
  {
   ret = 0.0;
   const double close_now = iClose(_Symbol, PERIOD_D1, shift);
   const double close_prev = iClose(_Symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   ret = (close_now / close_prev) - 1.0;
   return MathIsValidNumber(ret);
  }

bool Strategy_AtrPercent(const int shift, double &atr_pct)
  {
   atr_pct = 0.0;
   const double close_value = iClose(_Symbol, PERIOD_D1, shift);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
   if(close_value <= 0.0 || atr_value <= 0.0)
      return false;

   atr_pct = atr_value / close_value;
   return MathIsValidNumber(atr_pct);
  }

bool Strategy_AtrPercentileRank(const double current_atr_pct, double &rank)
  {
   rank = 0.0;
   if(current_atr_pct <= 0.0 || strategy_atr_percentile_bars <= 0)
      return false;

   int valid = 0;
   int less_or_equal = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_bars; ++shift)
     {
      double sample = 0.0;
      if(!Strategy_AtrPercent(shift, sample))
         continue;
      ++valid;
      if(sample <= current_atr_pct)
         ++less_or_equal;
     }

   if(valid < MathMin(strategy_atr_percentile_bars, 50))
      return false;

   rank = 100.0 * (double)less_or_equal / (double)valid;
   return MathIsValidNumber(rank);
  }

bool Strategy_SkipSignalDay(const datetime signal_day)
  {
   if(!strategy_skip_friday_signal)
      return false;

   MqlDateTime dt;
   TimeToStruct(signal_day, dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != g_slots[index])
      return true;
   if(strategy_atr_period <= 0 || strategy_shock_atr_mult <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(strategy_atr_percentile_bars < 50 || strategy_min_atr_percentile < 0.0 || strategy_min_atr_percentile > 100.0)
      return true;
   if(strategy_safety_hold_days < 1)
      return true;
   if(strategy_min_history_bars < strategy_atr_period + strategy_atr_percentile_bars + 3)
      return true;
   if(iBars(_Symbol, PERIOD_D1) < strategy_min_history_bars)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1188_OIL_NEGSHOCK_REBOUND";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_day <= 0 || g_last_entry_signal_day == signal_day)
      return false;
   g_last_entry_signal_day = signal_day;

   if(Strategy_SkipSignalDay(signal_day))
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   double daily_ret = 0.0;
   double atr_pct = 0.0;
   double atr_rank = 0.0;
   if(!Strategy_DailyReturn(1, daily_ret))
      return false;
   if(!Strategy_AtrPercent(1, atr_pct))
      return false;
   if(!Strategy_AtrPercentileRank(atr_pct, atr_rank))
      return false;

   const double shock_threshold = -strategy_shock_atr_mult * atr_pct;
   if(daily_ret > shock_threshold || atr_rank < strategy_min_atr_percentile)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_sl_atr_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   QM_LogEvent(QM_INFO, "OIL_NEGSHOCK_SIGNAL_ON",
               StringFormat("{\"signal_day\":%I64d,\"daily_ret\":%.6f,\"atr_pct\":%.6f,\"atr_rank\":%.2f,\"threshold\":%.6f}",
                            (long)signal_day, daily_ret, atr_pct, atr_rank, shock_threshold));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies only the initial ATR stop and a short scheduled exit.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
