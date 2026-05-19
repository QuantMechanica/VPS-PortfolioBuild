#property strict
#property version   "5.0"
#property description "QM5_1135 Quantpedia Asset Momentum Top 3"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1135;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_momentum_months    = 12;
input int    strategy_min_monthly_bars   = 13;
input int    strategy_top_n              = 3;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_max_spread_points  = 0;

const int STRATEGY_UNIVERSE_SIZE = 6;
string g_universe_symbols[6] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "XAUUSD.DWX"
  };
int g_universe_slots[6] = {0, 1, 2, 3, 4, 5};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
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

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime last_bar = iTime(_Symbol, _Period, 1);
   const datetime prev_bar = iTime(_Symbol, _Period, 2);
   if(last_bar <= 0 || prev_bar <= 0)
      return false;

   MqlDateTime last_dt;
   MqlDateTime prev_dt;
   TimeToStruct(last_bar, last_dt);
   TimeToStruct(prev_bar, prev_dt);
   return (last_dt.year != prev_dt.year || last_dt.mon != prev_dt.mon);
  }

double Strategy_Momentum12M(const string symbol)
  {
   if(strategy_momentum_months <= 0)
      return 0.0;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return 0.0;

   const double recent_close = iClose(symbol, PERIOD_MN1, 1);
   const double lookback_close = iClose(symbol, PERIOD_MN1, 1 + strategy_momentum_months);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0.0;

   return (recent_close / lookback_close) - 1.0;
  }

bool Strategy_IsSelectedTopMomentum()
  {
   const int own_index = Strategy_CurrentSymbolIndex();
   if(own_index < 0)
      return false;

   const double own_momentum = Strategy_Momentum12M(_Symbol);
   if(own_momentum <= 0.0)
      return false;

   int positive_count = 0;
   int better_count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      const double momentum = Strategy_Momentum12M(g_universe_symbols[i]);
      if(momentum <= 0.0)
         continue;
      positive_count++;
      if(momentum > own_momentum)
         better_count++;
     }

   const int selected_n = MathMin(MathMax(1, strategy_top_n), positive_count);
   return (selected_n > 0 && better_count < selected_n);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 && _Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1135_ASSET_MOM_TOP3";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, _Period, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsSelectedTopMomentum())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance exits plus hard ATR stop only.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, _Period, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   if(rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   return !Strategy_IsSelectedTopMomentum();
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1135_qp_asset_mom_top3\"}");
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
