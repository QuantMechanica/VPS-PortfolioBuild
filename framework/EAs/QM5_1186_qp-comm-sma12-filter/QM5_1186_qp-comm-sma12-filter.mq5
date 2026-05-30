#property strict
#property version   "5.0"
#property description "QM5_1186 Quantpedia Commodity 12M SMA Filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1186;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.20;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_sma_months         = 12;
input int    strategy_min_history_months = 14;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 6.0;
input int    strategy_max_spread_points  = 0;

#define QM5_1186_SYMBOL_COUNT 5

string g_symbols[QM5_1186_SYMBOL_COUNT] = {
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX",
   "XCUUSD.DWX"
};

int g_slots[QM5_1186_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1186_SYMBOL_COUNT; ++i)
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

bool Strategy_IsFirstTradableDayOfMonth()
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
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar <= 0)
      return 0;

   MqlDateTime dt;
   TimeToStruct(current_bar, dt);
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return true;
   return (spread <= strategy_max_spread_points);
  }

bool Strategy_HasMonthlyHistory()
  {
   const int required = MathMax(strategy_min_history_months, strategy_sma_months + 2);
   return (iBars(_Symbol, PERIOD_MN1) >= required);
  }

bool Strategy_MonthlySmaSignal(bool &out_long_signal)
  {
   out_long_signal = false;
   if(strategy_sma_months <= 1 || !Strategy_HasMonthlyHistory())
      return false;

   const double last_month_close = iClose(_Symbol, PERIOD_MN1, 1);
   if(last_month_close <= 0.0)
      return false;

   double sum = 0.0;
   for(int shift = 1; shift <= strategy_sma_months; ++shift)
     {
      const double close_value = iClose(_Symbol, PERIOD_MN1, shift);
      if(close_value <= 0.0)
         return false;
      sum += close_value;
     }

   const double sma = sum / strategy_sma_months;
   if(sma <= 0.0)
      return false;

   out_long_signal = (last_month_close > sma);
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_sma_months <= 1 || strategy_min_history_months < strategy_sma_months)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1186_COMM_SMA12";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_IsFirstTradableDayOfMonth())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   bool long_signal = false;
   if(!Strategy_MonthlySmaSignal(long_signal) || !long_signal)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance exits; ATR stop is only for V5 risk sizing.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsFirstTradableDayOfMonth())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   bool long_signal = false;
   if(!Strategy_MonthlySmaSignal(long_signal))
      return false;
   if(long_signal)
      return false;

   g_last_exit_rebalance_key = rebalance_key;
   return true;
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

   for(int i = 0; i < QM5_1186_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1186\",\"ea\":\"qp-comm-sma12-filter\"}");
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
