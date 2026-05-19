#property strict
#property version   "5.0"
#property description "QM5_1048 Estrada Lazy 6-Month Country-Index Rotation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1048;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.5;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_lookback_d1_bars   = 126;
input int    strategy_top_n              = 2;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 4.0;
input bool   strategy_absolute_momentum  = false;

const int STRATEGY_UNIVERSE_SIZE = 4;
string    g_universe_symbols[4] = {"NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"};
int       g_universe_slots[4]   = {0, 1, 2, 3};
int       g_last_entry_rebalance_key = 0;

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
   if(dt.mon != 6 && dt.mon != 12)
      return 0;
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsRebalanceClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);

   if(closed_dt.mon != 6 && closed_dt.mon != 12)
      return false;
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

double Strategy_TotalReturn6M(const string symbol)
  {
   if(strategy_lookback_d1_bars <= 0)
      return -DBL_MAX;

   SymbolSelect(symbol, true);
   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return -DBL_MAX;

   return (recent_close / lookback_close) - 1.0;
  }

bool Strategy_SymbolSelected(const string symbol)
  {
   double returns[4];
   int order[4];

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      returns[i] = Strategy_TotalReturn6M(g_universe_symbols[i]);
      order[i] = i;
     }

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
     {
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
        {
         if(returns[order[j]] > returns[order[i]])
           {
            const int tmp = order[i];
            order[i] = order[j];
            order[j] = tmp;
           }
        }
     }

   int top_n = strategy_top_n;
   if(top_n < 1)
      top_n = 1;
   if(top_n > STRATEGY_UNIVERSE_SIZE)
      top_n = STRATEGY_UNIVERSE_SIZE;

   for(int rank = 0; rank < top_n; ++rank)
     {
      const int idx = order[rank];
      if(g_universe_symbols[idx] != symbol)
         continue;
      if(returns[idx] <= -DBL_MAX / 2.0)
         return false;
      if(strategy_absolute_momentum && returns[idx] < 0.0)
         return false;
      return true;
     }

   return false;
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

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return (Strategy_CurrentSymbolIndex() < 0);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1048_SEMIANNUAL_TOP_HALF";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SymbolSelected(_Symbol))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no mid-cycle adjustments beyond the hard ATR stop.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsRebalanceClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   return !Strategy_SymbolSelected(_Symbol);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1048\",\"ea\":\"estrada-lazy-6m-rotation\"}");
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
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
