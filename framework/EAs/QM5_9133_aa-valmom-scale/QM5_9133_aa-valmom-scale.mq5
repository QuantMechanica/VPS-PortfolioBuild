#property strict
#property version   "5.0"
#property description "QM5_9133 Alpha Architect Value Momentum Asset Class Scaling"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9133;
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
input int    strategy_momentum_months    = 12;
input int    strategy_min_monthly_bars   = 14;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_max_spread_points  = 0;
input double strategy_min_slot_weight    = 0.01;
input double strategy_value_center       = 0.0;
input double strategy_value_threshold    = 0.01;
input bool   strategy_valuation_data_approved = false;
input double strategy_baseline_ndx       = 0.16666667;
input double strategy_baseline_ws30      = 0.16666667;
input double strategy_baseline_gdaxi     = 0.16666667;
input double strategy_baseline_xauusd    = 0.16666667;
input double strategy_baseline_xtiusd    = 0.16666667;
input double strategy_baseline_sp500     = 0.16666667;
input double strategy_value_ndx          = 0.0;
input double strategy_value_ws30         = 0.0;
input double strategy_value_gdaxi        = 0.0;
input double strategy_value_xauusd       = 0.0;
input double strategy_value_xtiusd       = 0.0;
input double strategy_value_sp500        = 0.0;

const int STRATEGY_SYMBOL_COUNT = 6;
string g_strategy_symbols[6] =
  {
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX", "XTIUSD.DWX", "SP500.DWX"
  };
int g_strategy_slots[6] = {0, 1, 2, 3, 4, 5};
int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsFirstH1BarOfMonth()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_H1, 0);
   const datetime prior_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return (Strategy_MonthKey(current_bar) != Strategy_MonthKey(prior_bar));
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

double Strategy_BaselineWeight(const int index)
  {
   switch(index)
     {
      case 0: return strategy_baseline_ndx;
      case 1: return strategy_baseline_ws30;
      case 2: return strategy_baseline_gdaxi;
      case 3: return strategy_baseline_xauusd;
      case 4: return strategy_baseline_xtiusd;
      case 5: return strategy_baseline_sp500;
     }
   return 0.0;
  }

double Strategy_ValuationScore(const int index)
  {
   switch(index)
     {
      case 0: return strategy_value_ndx;
      case 1: return strategy_value_ws30;
      case 2: return strategy_value_gdaxi;
      case 3: return strategy_value_xauusd;
      case 4: return strategy_value_xtiusd;
      case 5: return strategy_value_sp500;
     }
   return strategy_value_center;
  }

double Strategy_ValuationFactor(const int index)
  {
   const double score = Strategy_ValuationScore(index);
   if(score <= strategy_value_center - strategy_value_threshold)
      return 1.5;
   if(score >= strategy_value_center + strategy_value_threshold)
      return 0.5;
   return 1.0;
  }

bool Strategy_MomentumPositive(const string symbol)
  {
   if(strategy_momentum_months <= 0 || strategy_min_monthly_bars < strategy_momentum_months + 2)
      return false;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, 1);
   const double past_close = iClose(symbol, PERIOD_MN1, 1 + strategy_momentum_months);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;
   return (recent_close > past_close);
  }

double Strategy_RawWeight(const int index)
  {
   if(index < 0 || index >= STRATEGY_SYMBOL_COUNT)
      return 0.0;

   const double baseline = MathMax(0.0, Strategy_BaselineWeight(index));
   if(baseline <= 0.0)
      return 0.0;

   const double valuation_adjusted = baseline * Strategy_ValuationFactor(index);
   const double momentum_factor = Strategy_MomentumPositive(g_strategy_symbols[index]) ? 1.5 : 0.5;
   return valuation_adjusted * momentum_factor;
  }

double Strategy_NormalizedWeight(const int index)
  {
   double total = 0.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      total += Strategy_RawWeight(i);
   if(total <= 0.0)
      return 0.0;
   return Strategy_RawWeight(index) / total;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!strategy_valuation_data_approved)
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_9133_VALMOM_SCALE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsFirstH1BarOfMonth())
      return false;

   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   const int rebalance_key = Strategy_MonthKey(current_month);
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;

   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return false;
   if(Strategy_NormalizedWeight(index) < strategy_min_slot_weight)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = "QM5_9133_MONTHLY_VALUE_MOMENTUM_WEIGHT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card uses monthly rebalance exits; V5 ATR emergency stop is placed at entry.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsFirstH1BarOfMonth())
      return false;

   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   const int rebalance_key = Strategy_MonthKey(current_month);
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   return (Strategy_NormalizedWeight(index) < strategy_min_slot_weight);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9133\",\"ea\":\"aa-valmom-scale\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
