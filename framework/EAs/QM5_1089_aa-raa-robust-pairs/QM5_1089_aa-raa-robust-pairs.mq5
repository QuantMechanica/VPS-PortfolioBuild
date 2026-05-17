#property strict
#property version   "5.0"
#property description "QM5_1089 Alpha Architect RAA Robust Pairs"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1089;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_lookback_months     = 12;
input double strategy_cash_12m_return     = 0.0;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_max_spread_points   = 5000;

const int STRATEGY_UNIVERSE_SIZE = 8;
string    g_universe_symbols[8] =
  {
   "SP500.DWX", "GDAXI.DWX", "XAUUSD.DWX", "XTIUSD.DWX",
   "EURUSD.DWX", "USDJPY.DWX", "NDX.DWX", "WS30.DWX"
  };
int       g_universe_slots[8] = {0, 1, 2, 3, 4, 5, 6, 7};

int       g_last_entry_rebalance_key = 0;
int       g_last_exit_rebalance_key  = 0;
int       g_last_partial_key         = 0;
double    g_position_target_exposure = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, _Period, 1);
   const datetime current_bar = iTime(_Symbol, _Period, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);

   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

double Strategy_TargetExposure()
  {
   if(strategy_lookback_months <= 0)
      return 0.0;

   const int recent_shift = 1;
   const int lookback_shift = recent_shift + strategy_lookback_months;
   const double recent_close = iClose(_Symbol, PERIOD_MN1, recent_shift);
   const double lookback_close = iClose(_Symbol, PERIOD_MN1, lookback_shift);
   const double sma = QM_SMA(_Symbol, PERIOD_MN1, strategy_lookback_months, recent_shift);
   if(recent_close <= 0.0 || lookback_close <= 0.0 || sma <= 0.0)
      return 0.0;

   const double total_return = (recent_close / lookback_close) - 1.0;
   const bool tmom_positive = (total_return > strategy_cash_12m_return);
   const bool ma_positive = (recent_close > sma);

   if(tmom_positive && ma_positive)
      return 1.0;
   if(tmom_positive || ma_positive)
      return 0.5;
   return 0.0;
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

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;
   if(qm_magic_slot_offset != g_universe_slots[idx])
      return true;
   if(!Strategy_SpreadAllowsEntry())
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
   req.reason = "QM5_1089_RAA_ROBUST_PAIRS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_MN1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const double target_exposure = Strategy_TargetExposure();
   if(target_exposure <= 0.0)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   g_last_entry_rebalance_key = rebalance_key;
   g_position_target_exposure = (target_exposure < 1.0) ? 0.5 : 1.0;
   req.reason = (target_exposure >= 1.0) ? "QM5_1089_RAA_FULL" : "QM5_1089_RAA_HALF";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!Strategy_IsMonthlyRebalanceClosedBar())
      return;
   if(!Strategy_HasOpenPosition())
      return;

   const double target_exposure = Strategy_TargetExposure();
   if(target_exposure > 0.51)
      return;
   if(g_position_target_exposure <= 0.51)
      return;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_MN1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_partial_key)
      return;

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

      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(volume <= 0.0)
         continue;

      if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
        {
         g_last_partial_key = rebalance_key;
         g_position_target_exposure = 0.5;
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_H1)
      return false;
   if(!Strategy_IsMonthlyRebalanceClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_MN1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;

   const double target_exposure = Strategy_TargetExposure();
   if(target_exposure <= 0.0)
     {
      g_last_exit_rebalance_key = rebalance_key;
      g_position_target_exposure = 0.0;
      return true;
     }

   if(target_exposure > g_position_target_exposure && g_position_target_exposure > 0.0)
     {
      g_last_exit_rebalance_key = rebalance_key;
      g_position_target_exposure = 0.0;
      return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1089\",\"ea\":\"aa-raa-robust-pairs\"}");
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
