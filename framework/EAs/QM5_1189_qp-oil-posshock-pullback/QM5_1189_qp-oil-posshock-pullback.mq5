#property strict
#property version   "5.0"
#property description "QM5_1189 Quantpedia Oil Positive-Shock Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1189;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 20;
input double strategy_return_atr_mult    = 2.0;
input int    strategy_atr_percentile_lookback = 252;
input double strategy_atr_percentile_min = 70.0;
input double strategy_atr_sl_mult        = 1.0;
input int    strategy_max_hold_d1_bars   = 1;
input int    strategy_min_history_d1_bars = 280;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 3.0;
input double strategy_abnormal_range_atr_mult = 4.0;
input double strategy_abnormal_gap_atr_mult   = 3.0;

#define QM5_1189_SYMBOL_COUNT 2

string g_symbols[QM5_1189_SYMBOL_COUNT] = {"XTIUSD.DWX", "XBRUSD.DWX"};
int    g_slots[QM5_1189_SYMBOL_COUNT] = {0, 1};

datetime g_last_entry_signal_bar = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1189_SYMBOL_COUNT; ++i)
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
   for(int i = 0; i < QM5_1189_SYMBOL_COUNT; ++i)
      if(!SymbolSelect(g_symbols[i], true))
         return false;
   return true;
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

bool Strategy_DailyReturn(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;
   const double close_now = iClose(symbol, PERIOD_D1, shift);
   const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   out_return = (close_now / close_prev) - 1.0;
   return MathIsValidNumber(out_return);
  }

bool Strategy_ATRPercent(const string symbol, const int shift, double &out_atr_pct)
  {
   out_atr_pct = 0.0;
   const double close_value = iClose(symbol, PERIOD_D1, shift);
   const double atr_value = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, shift);
   if(close_value <= 0.0 || atr_value <= 0.0)
      return false;

   out_atr_pct = atr_value / close_value;
   return MathIsValidNumber(out_atr_pct);
  }

bool Strategy_ATRPercentileRank(const string symbol, const double current_atr_pct, double &out_rank)
  {
   out_rank = 0.0;
   const int lookback = strategy_atr_percentile_lookback;
   if(lookback < 20 || lookback > 512)
      return false;

   int valid = 0;
   int below_or_equal = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      double value = 0.0;
      if(!Strategy_ATRPercent(symbol, shift, value))
         return false;
      ++valid;
      if(value <= current_atr_pct)
         ++below_or_equal;
     }

   if(valid <= 0)
      return false;

   out_rank = 100.0 * (double)below_or_equal / (double)valid;
   return MathIsValidNumber(out_rank);
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

bool Strategy_BarQualityAllowsEntry(const double atr_value)
  {
   if(atr_value <= 0.0)
      return false;

   const double high_value = iHigh(_Symbol, PERIOD_D1, 1);
   const double low_value = iLow(_Symbol, PERIOD_D1, 1);
   const double open_value = iOpen(_Symbol, PERIOD_D1, 1);
   const double prior_close = iClose(_Symbol, PERIOD_D1, 2);
   if(high_value <= 0.0 || low_value <= 0.0 || open_value <= 0.0 || prior_close <= 0.0)
      return false;

   const double range = high_value - low_value;
   const double gap = MathAbs(open_value - prior_close);
   if(strategy_abnormal_range_atr_mult > 0.0 && range > atr_value * strategy_abnormal_range_atr_mult)
      return false;
   if(strategy_abnormal_gap_atr_mult > 0.0 && gap > atr_value * strategy_abnormal_gap_atr_mult)
      return false;
   return true;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(sl - entry) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != Strategy_SlotForCurrentSymbol())
      return true;
   if(strategy_atr_period <= 0 || strategy_return_atr_mult <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_atr_percentile_min < 0.0 || strategy_atr_percentile_min > 100.0)
      return true;
   if(strategy_max_hold_d1_bars < 1 || strategy_max_hold_d1_bars > 2)
      return true;
   if(iBars(_Symbol, PERIOD_D1) < strategy_min_history_d1_bars)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1189_OIL_POS_SHOCK_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || g_last_entry_signal_bar == signal_bar)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   double daily_return = 0.0;
   double atr_pct = 0.0;
   if(!Strategy_DailyReturn(_Symbol, 1, daily_return) || !Strategy_ATRPercent(_Symbol, 1, atr_pct))
      return false;

   double atr_percentile = 0.0;
   if(!Strategy_ATRPercentileRank(_Symbol, atr_pct, atr_percentile))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(!Strategy_BarQualityAllowsEntry(atr_value))
      return false;

   if(daily_return < strategy_return_atr_mult * atr_pct)
      return false;
   if(atr_percentile < strategy_atr_percentile_min)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   g_last_entry_signal_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies an initial ATR stop and scheduled next-D1-close exit only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || opened_at <= 0)
      return false;

   const int seconds_per_d1 = 86400;
   const datetime earliest_exit_bar = opened_at + strategy_max_hold_d1_bars * seconds_per_d1;
   return (current_d1 >= earliest_exit_bar);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1189\",\"strategy\":\"qp-oil-posshock-pullback\"}");
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
