#property strict
#property version   "5.0"
#property description "QM5_1052 Sidus EMA Method v2"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1052;
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
input int    strategy_wma_fast_period    = 5;
input int    strategy_wma_slow_period    = 8;
input int    strategy_ema_fast_period    = 18;
input int    strategy_ema_slow_period    = 28;
input int    strategy_sl_buffer_points   = 20;
input double strategy_rr_take_profit     = 1.5;
input bool   strategy_use_rr_tp          = true;
input int    strategy_max_spread_points  = 20;
input bool   strategy_session_filter_enabled = false;
input int    strategy_session_start_hour_broker = 13;
input int    strategy_session_end_hour_broker   = 17;

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from QM5_1052 Sidus Method v2.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): news is handled by Strategy_NewsFilterHook
// plus QM_NewsAllowsTrade in framework wiring; this hook adds spread/session gates.
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   if(strategy_session_filter_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour < strategy_session_start_hour_broker || dt.hour >= strategy_session_end_hour_broker)
         return true;
     }

   return false;
  }

// Trade Entry: WMA(5/8) closed-bar cross gated by EMA(18/28) tunnel.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double wma_fast_prev = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   const double wma_slow_prev = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   const double wma_fast_sig = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma_slow_sig = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(wma_fast_prev <= 0.0 || wma_slow_prev <= 0.0 ||
      wma_fast_sig <= 0.0 || wma_slow_sig <= 0.0 ||
      ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool bull_cross = (wma_fast_prev <= wma_slow_prev && wma_fast_sig > wma_slow_sig);
   const bool bear_cross = (wma_fast_prev >= wma_slow_prev && wma_fast_sig < wma_slow_sig);
   const double buffer = (double)strategy_sl_buffer_points * point;

   if(bull_cross &&
      wma_fast_sig > ema_fast && wma_fast_sig > ema_slow &&
      wma_slow_sig > ema_fast && wma_slow_sig > ema_slow &&
      ema_fast > ema_slow)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ema_slow - buffer, _Digits);
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_take_profit) : 0.0;
      req.reason = "SIDUS_WMA_CROSS_LONG";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   if(bear_cross &&
      wma_fast_sig < ema_fast && wma_fast_sig < ema_slow &&
      wma_slow_sig < ema_fast && wma_slow_sig < ema_slow &&
      ema_fast < ema_slow)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = NormalizeDouble(ema_slow + buffer, _Digits);
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_take_profit) : 0.0;
      req.reason = "SIDUS_WMA_CROSS_SHORT";
      return (entry > 0.0 && req.sl > entry);
     }

   return false;
  }

// Trade Management: card specifies no trailing, break-even, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: reverse WMA(5/8) cross closes the position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_buy = false;
   bool have_sell = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_buy = have_buy || (ptype == POSITION_TYPE_BUY);
      have_sell = have_sell || (ptype == POSITION_TYPE_SELL);
     }

   if(!have_buy && !have_sell)
      return false;

   const double wma_fast_prev = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   const double wma_slow_prev = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   const double wma_fast_sig = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma_slow_sig = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   if(wma_fast_prev <= 0.0 || wma_slow_prev <= 0.0 || wma_fast_sig <= 0.0 || wma_slow_sig <= 0.0)
      return false;

   const bool bull_cross = (wma_fast_prev <= wma_slow_prev && wma_fast_sig > wma_slow_sig);
   const bool bear_cross = (wma_fast_prev >= wma_slow_prev && wma_fast_sig < wma_slow_sig);
   return ((have_buy && bear_cross) || (have_sell && bull_cross));
  }

// News Filter Hook: P8-callable hook; default P2 behavior is no custom override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
