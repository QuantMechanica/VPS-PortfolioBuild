#property strict
#property version   "5.0"
#property description "QM5_2013 NNFX V2 Carry Momentum Filter _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_2013_v2
// Logic: NNFX-style EMA baseline with MACD confirmer. 
// Long: D1/H4 EMA trend + MACD cross.
// Short: D1 Momentum + H4 EMA + MACD cross + SSL bear filter.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2013;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 1.0;
input double RISK_FIXED                 = 0.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_d1_ema_period      = 100;
input int    strategy_h4_ema_period      = 55;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_ssl_period         = 10;
input int    strategy_momentum_bars_d1   = 60;
input double strategy_short_momentum_max = -4.0;
input int    strategy_min_flat_h4_bars   = 8;
input int    strategy_atr_period         = 14;
input double strategy_initial_atr_mult   = 2.5;
input double strategy_trail_atr_mult     = 3.0;
input double strategy_be_trigger_r       = 1.0;
input double strategy_trail_trigger_r    = 2.0;
input int    strategy_max_hold_h4_bars   = 60;

// Internal state
int g_flat_h4_bars = 9999;

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
     }
   return false;
  }

void UpdateFlatBarCount()
  {
   if(HasOurPosition())
      g_flat_h4_bars = 0;
   else if(g_flat_h4_bars < 1000000)
      g_flat_h4_bars++;
  }

double D1MomentumPct(const int shift)
  {
   const int lookback_shift = shift + strategy_momentum_bars_d1;
   const double now_close = iClose(_Symbol, PERIOD_D1, shift);
   const double then_close = iClose(_Symbol, PERIOD_D1, lookback_shift);
   if(now_close <= 0.0 || then_close <= 0.0)
      return 0.0;
   return 100.0 * (now_close - then_close) / then_close;
  }

bool SSLBearish(const int shift)
  {
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double ssl_low = QM_SMA(_Symbol, PERIOD_H4, strategy_ssl_period, shift, PRICE_LOW);
   if(h4_close <= 0.0 || ssl_low <= 0.0) return false;
   return (h4_close < ssl_low);
  }

bool LongSetup(const int shift)
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, shift);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, shift);
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, shift);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);

   if(d1_close <= 0.0 || d1_ema <= 0.0 || h4_close <= 0.0 || h4_ema <= 0.0 || macd_main == EMPTY_VALUE || macd_signal == EMPTY_VALUE)
      return false;

   return (d1_close > d1_ema && h4_close > h4_ema && macd_main > macd_signal);
  }

bool ShortSetup(const int shift)
  {
   const double momentum = D1MomentumPct(shift);
   const double h4_close = iClose(_Symbol, PERIOD_H4, shift);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, shift);
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);

   if(h4_close <= 0.0 || h4_ema <= 0.0 || macd_main == EMPTY_VALUE || macd_signal == EMPTY_VALUE)
      return false;

   return (momentum < strategy_short_momentum_max &&
           h4_close < h4_ema &&
           macd_main < macd_signal &&
           SSLBearish(shift));
  }

// -----------------------------------------------------------------------------
// Framework Hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateFlatBarCount();
   if(g_flat_h4_bars < strategy_min_flat_h4_bars)
      return false;

   if(HasOurPosition())
      return false;

   const bool long_now = LongSetup(1);
   const bool long_prev = LongSetup(2);
   const bool short_now = ShortSetup(1);
   const bool short_prev = ShortSetup(2);

   QM_OrderType side = QM_BUY;
   bool entry_signal = false;

   if(long_now && !long_prev)
     {
      side = QM_BUY;
      entry_signal = true;
     }
   else if(short_now && !short_prev)
     {
      side = QM_SELL;
      entry_signal = true;
     }

   if(!entry_signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_initial_atr_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.reason = (side == QM_BUY) ? "NNFX_V2_LONG" : "NNFX_V2_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            const double market = (ptype == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
            if(atr <= 0.0) return;
            const double risk_dist = atr * strategy_initial_atr_mult;
            if(risk_dist <= 0.0) return;

            const double moved = (ptype == POSITION_TYPE_BUY) ? (market - open_price) : (open_price - market);
            
            if(moved >= risk_dist * strategy_be_trigger_r)
               QM_TM_MoveSL(ticket, open_price, "BE_1R");
            
            if(moved >= risk_dist * strategy_trail_trigger_r)
               QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
            
            break;
           }
        }
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   const int magic = QM_FrameworkMagic();
   datetime open_time = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   bool found = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            open_time = (datetime)PositionGetInteger(POSITION_TIME);
            found = true;
            break;
           }
        }
     }

   if(!found) return false;

   const double h4_close = iClose(_Symbol, PERIOD_H4, 1);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_ema_period, 1);
   if(h4_close <= 0.0 || h4_ema <= 0.0) return false;

   // Exit on baseline cross
   if(ptype == POSITION_TYPE_BUY && h4_close < h4_ema) return true;
   if(ptype == POSITION_TYPE_SELL && h4_close > h4_ema) return true;

   // Exit on momentum reversal
   const double momentum = D1MomentumPct(1);
   if(ptype == POSITION_TYPE_BUY && momentum < 0.0) return true;
   if(ptype == POSITION_TYPE_SELL && momentum >= 0.0) return true;

   // Time stop
   const int open_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(open_shift >= strategy_max_hold_h4_bars) return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework Wiring
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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }
