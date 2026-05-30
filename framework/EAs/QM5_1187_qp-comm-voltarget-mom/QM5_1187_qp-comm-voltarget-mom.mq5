#property strict
#property version   "5.0"
#property description "QM5_1187 Quantpedia Vol-Targeted Commodity Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1187;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.33;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_momentum_lookback_d1_bars = 252;
input int    strategy_realized_vol_d1_bars      = 63;
input int    strategy_min_history_d1_bars       = 270;
input int    strategy_top_n_normal              = 4;
input int    strategy_top_n_narrow              = 3;
input int    strategy_narrow_universe_threshold = 6;
input double strategy_floor_vol_annualized      = 0.10;
input int    strategy_atr_period                = 20;
input double strategy_atr_sl_mult               = 5.0;
input int    strategy_spread_median_days        = 20;
input double strategy_spread_mult               = 3.0;

#define QM5_1187_SYMBOL_COUNT 5

string g_symbols[QM5_1187_SYMBOL_COUNT] = {
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX",
   "XCUUSD.DWX"
};

int g_slots[QM5_1187_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1187_SYMBOL_COUNT; ++i)
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

bool Strategy_IsMonthEndClosedBar()
  {
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

int Strategy_RebalanceKey()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(closed_bar <= 0)
      return 0;

   MqlDateTime dt;
   TimeToStruct(closed_bar, dt);
   return dt.year * 100 + dt.mon;
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

bool Strategy_DailyReturnAtShift(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;
   const double close_now = iClose(symbol, PERIOD_D1, shift);
   const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   out_return = (close_now / close_prev) - 1.0;
   return true;
  }

bool Strategy_AnnualizedRealizedVol(const string symbol, double &out_vol)
  {
   out_vol = 0.0;
   const int bars = strategy_realized_vol_d1_bars;
   if(bars < 2 || bars > 512)
      return false;

   double values[512];
   double sum = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      double ret = 0.0;
      if(!Strategy_DailyReturnAtShift(symbol, i + 1, ret))
         return false;
      values[i] = ret;
      sum += ret;
     }

   const double mean = sum / bars;
   double variance = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double diff = values[i] - mean;
      variance += diff * diff;
     }

   if(variance <= 0.0)
      return false;

   out_vol = MathSqrt(variance / (bars - 1)) * MathSqrt(252.0);
   return (out_vol > 0.0);
  }

bool Strategy_SymbolScore(const string symbol, double &out_score)
  {
   out_score = 0.0;
   const int required = MathMax(strategy_min_history_d1_bars,
                                MathMax(strategy_momentum_lookback_d1_bars + 2,
                                        strategy_realized_vol_d1_bars + 2));
   if(required <= 0)
      return false;

   SymbolSelect(symbol, true);
   if(iBars(symbol, PERIOD_D1) < required)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_momentum_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   double vol = 0.0;
   if(!Strategy_AnnualizedRealizedVol(symbol, vol))
      return false;

   const double floor_vol = MathMax(strategy_floor_vol_annualized, 0.0001);
   const double roc = (recent_close / lookback_close) - 1.0;
   out_score = roc / MathMax(vol, floor_vol);
   return true;
  }

bool Strategy_IsSelected()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return false;

   double scores[QM5_1187_SYMBOL_COUNT];
   int indexes[QM5_1187_SYMBOL_COUNT];
   int count = 0;
   for(int i = 0; i < QM5_1187_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_SymbolScore(g_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count <= 0)
      return false;

   int selected_count = strategy_top_n_normal;
   if(count < strategy_narrow_universe_threshold)
      selected_count = strategy_top_n_narrow;
   selected_count = MathMin(selected_count, count);
   if(selected_count <= 0)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] > scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   for(int i = 0; i < selected_count; ++i)
      if(indexes[i] == current_index)
         return true;
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_momentum_lookback_d1_bars <= 0 || strategy_realized_vol_d1_bars < 2)
      return true;
   if(strategy_top_n_normal <= 0 || strategy_top_n_narrow <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1187_COMM_VOLTARGET_MOM";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_IsSelected())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = "QM5_1187_COMM_VOLTARGET_MOM_LONG_TOP";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance and no discretionary trailing management.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsMonthEndClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   return !Strategy_IsSelected();
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   for(int i = 0; i < QM5_1187_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1187\",\"ea\":\"qp-comm-voltarget-mom\"}");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
