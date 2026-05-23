#property strict
#property version   "5.0"
#property description "QM5_10050 ForexFactory correlation triad H1 MA cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10050;
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
input int    strategy_fast_sma_period    = 15;
input int    strategy_slow_sma_period    = 30;
input int    strategy_atr_period         = 10;
input double strategy_sl_atr_mult        = 3.0;
input double strategy_tp_atr_mult        = 1.0;
input int    strategy_max_spread_points  = 0;

const string STRATEGY_EXEC_SYMBOL = "EURUSD.DWX";
const string STRATEGY_CONFIRM_EURCHF = "EURCHF.DWX";
const string STRATEGY_CONFIRM_USDCHF = "USDCHF.DWX";
const ENUM_TIMEFRAMES STRATEGY_TF = PERIOD_H1;

bool IsSynchronizedClosedBar(const string symbol, const datetime decision_bar_time)
  {
   return (iTime(symbol, STRATEGY_TF, 1) == decision_bar_time);
  }

int SmaCrossSignal(const string symbol)
  {
   const double fast_1 = QM_SMA(symbol, STRATEGY_TF, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_SMA(symbol, STRATEGY_TF, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(symbol, STRATEGY_TF, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_SMA(symbol, STRATEGY_TF, strategy_slow_sma_period, 2, PRICE_CLOSE);

   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      return 1;
   if(fast_2 >= slow_2 && fast_1 < slow_1)
      return -1;
   return 0;
  }

bool HasOurOpenPosition()
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

int TriadSignal()
  {
   const datetime decision_bar_time = iTime(STRATEGY_EXEC_SYMBOL, STRATEGY_TF, 1);
   if(decision_bar_time <= 0)
      return 0;
   if(!IsSynchronizedClosedBar(STRATEGY_CONFIRM_EURCHF, decision_bar_time))
      return 0;
   if(!IsSynchronizedClosedBar(STRATEGY_CONFIRM_USDCHF, decision_bar_time))
      return 0;

   const int eurusd = SmaCrossSignal(STRATEGY_EXEC_SYMBOL);
   const int eurchf = SmaCrossSignal(STRATEGY_CONFIRM_EURCHF);
   const int usdchf = SmaCrossSignal(STRATEGY_CONFIRM_USDCHF);

   if(eurusd > 0 && eurchf > 0 && usdchf < 0)
      return 1;
   if(eurusd < 0 && eurchf < 0 && usdchf > 0)
      return -1;
   return 0;
  }

// No Trade Filter: framework handles news and Friday close; this hook enforces
// the card symbol and an optional spread ceiling without adding a session rule.
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_EXEC_SYMBOL)
      return true;
   if(_Period != STRATEGY_TF)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Trade Entry: completed-H1 triad SMA cross concurrence, market entry at the
// next H1 open, with ATR(10) SL/TP on EURUSD.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return false;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return false;
   if(HasOurOpenPosition())
      return false;

   const int signal = TriadSignal();
   if(signal == 0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, STRATEGY_TF, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_sl_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry_price, atr, strategy_tp_atr_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (signal > 0) ? "FF_CORR_TRIAD_LONG" : "FF_CORR_TRIAD_SHORT";
   return true;
  }

// Trade Management: card baseline uses one full-size position, no partials or
// trailing; TP/SL are placed at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: exit early on the opposite triad signal before TP/SL.
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const int signal = TriadSignal();
   if(signal == 0)
      return false;

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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(type == POSITION_TYPE_SELL && signal > 0)
         return true;
     }
   return false;
  }

// News Filter Hook: no card-specific event handling; central framework news
// mode remains the source of truth for P8.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10050\",\"ea\":\"ff-corr-triad-h1\"}");
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
