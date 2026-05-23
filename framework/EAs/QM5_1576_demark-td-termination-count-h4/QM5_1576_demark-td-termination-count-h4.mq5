#property strict
#property version   "5.0"
#property description "QM5_1576 DeMark TD Termination-Count H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 1576;
input int    qm_magic_slot_offset          = 0;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsMode qm_news_mode             = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Strategy"
input int    strategy_setup_bars           = 9;
input int    strategy_countdown_bars       = 13;
input int    strategy_setup_lookback       = 4;
input int    strategy_countdown_lookahead  = 2;
input int    strategy_max_countdown_bars   = 60;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 2.5;
input double strategy_atr_tp_mult          = 2.0;
input double strategy_max_spread_atr_mult  = 0.4;
input int    strategy_regime_sma_period    = 200;
input int    strategy_time_stop_h4_bars    = 21;
input int    strategy_scan_bars            = 160;

struct TDState
{
   bool   active;
   int    setup_count;
   int    countdown_count;
   int    bars_elapsed;
   double setup_anchor;
   double bar8_level;
};

bool HasOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double TrueHighAt(const int shift)
  {
   const double high = iHigh(_Symbol, PERIOD_H4, shift);
   const double prior_close = iClose(_Symbol, PERIOD_H4, shift + 1);
   if(high <= 0.0 || prior_close <= 0.0)
      return 0.0;
   return MathMax(high, prior_close);
  }

double TrueLowAt(const int shift)
  {
   const double low = iLow(_Symbol, PERIOD_H4, shift);
   const double prior_close = iClose(_Symbol, PERIOD_H4, shift + 1);
   if(low <= 0.0 || prior_close <= 0.0)
      return 0.0;
   return MathMin(low, prior_close);
  }

void ResetState(TDState &state)
  {
   state.active = false;
   state.setup_count = 0;
   state.countdown_count = 0;
   state.bars_elapsed = 0;
   state.setup_anchor = 0.0;
   state.bar8_level = 0.0;
  }

bool BuySetupCondition(const int shift)
  {
   const double c = iClose(_Symbol, PERIOD_H4, shift);
   const double c4 = iClose(_Symbol, PERIOD_H4, shift + strategy_setup_lookback);
   return (c > 0.0 && c4 > 0.0 && c < c4);
  }

bool SellSetupCondition(const int shift)
  {
   const double c = iClose(_Symbol, PERIOD_H4, shift);
   const double c4 = iClose(_Symbol, PERIOD_H4, shift + strategy_setup_lookback);
   return (c > 0.0 && c4 > 0.0 && c > c4);
  }

bool BuyCountdownCondition(const int shift)
  {
   const double c = iClose(_Symbol, PERIOD_H4, shift);
   const double l2 = iLow(_Symbol, PERIOD_H4, shift + strategy_countdown_lookahead);
   return (c > 0.0 && l2 > 0.0 && c <= l2);
  }

bool SellCountdownCondition(const int shift)
  {
   const double c = iClose(_Symbol, PERIOD_H4, shift);
   const double h2 = iHigh(_Symbol, PERIOD_H4, shift + strategy_countdown_lookahead);
   return (c > 0.0 && h2 > 0.0 && c >= h2);
  }

void AdvanceSetups(const int shift, int &buy_setup_count, int &sell_setup_count)
  {
   if(BuySetupCondition(shift))
      buy_setup_count++;
   else
      buy_setup_count = 0;

   if(SellSetupCondition(shift))
      sell_setup_count++;
   else
      sell_setup_count = 0;
  }

void StartCountdowns(const int shift,
                     const int buy_setup_count,
                     const int sell_setup_count,
                     TDState &buy_state,
                     TDState &sell_state)
  {
   if(buy_setup_count >= strategy_setup_bars && !buy_state.active)
     {
      ResetState(buy_state);
      buy_state.active = true;
      buy_state.setup_anchor = TrueHighAt(shift + strategy_setup_bars - 1);
     }

   if(sell_setup_count >= strategy_setup_bars && !sell_state.active)
     {
      ResetState(sell_state);
      sell_state.active = true;
      sell_state.setup_anchor = TrueLowAt(shift + strategy_setup_bars - 1);
     }
  }

int EvaluateTDTerminationAtLastClosedBar()
  {
   TDState buy_state;
   TDState sell_state;
   ResetState(buy_state);
   ResetState(sell_state);

   int buy_setup_count = 0;
   int sell_setup_count = 0;
   const int start_shift = MathMax(strategy_scan_bars, strategy_setup_lookback + strategy_countdown_lookahead + 80);

   for(int shift = start_shift; shift >= 1; --shift)
     {
      AdvanceSetups(shift, buy_setup_count, sell_setup_count);

      if(buy_state.active)
        {
         buy_state.bars_elapsed++;
         if((sell_setup_count >= strategy_setup_bars) ||
            (TrueHighAt(shift) > buy_state.setup_anchor) ||
            (buy_state.bars_elapsed > strategy_max_countdown_bars))
            ResetState(buy_state);
        }

      if(sell_state.active)
        {
         sell_state.bars_elapsed++;
         if((buy_setup_count >= strategy_setup_bars) ||
            (TrueLowAt(shift) < sell_state.setup_anchor) ||
            (sell_state.bars_elapsed > strategy_max_countdown_bars))
            ResetState(sell_state);
        }

      StartCountdowns(shift, buy_setup_count, sell_setup_count, buy_state, sell_state);

      if(buy_state.active && BuyCountdownCondition(shift))
        {
         buy_state.countdown_count++;
         if(buy_state.countdown_count == 8)
            buy_state.bar8_level = iLow(_Symbol, PERIOD_H4, shift);
         if(buy_state.countdown_count >= strategy_countdown_bars &&
            buy_state.bar8_level > 0.0 &&
            iClose(_Symbol, PERIOD_H4, shift) <= buy_state.bar8_level)
           {
            if(shift == 1)
               return 1;
            ResetState(buy_state);
           }
        }

      if(sell_state.active && SellCountdownCondition(shift))
        {
         sell_state.countdown_count++;
         if(sell_state.countdown_count == 8)
            sell_state.bar8_level = iHigh(_Symbol, PERIOD_H4, shift);
         if(sell_state.countdown_count >= strategy_countdown_bars &&
            sell_state.bar8_level > 0.0 &&
            iClose(_Symbol, PERIOD_H4, shift) >= sell_state.bar8_level)
           {
            if(shift == 1)
               return -1;
            ResetState(sell_state);
           }
        }
     }

   return 0;
  }

int OppositeSetupJustClosedForPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!HasOurPosition(ptype, open_time))
      return 0;

   bool buy_setup = true;
   bool sell_setup = true;
   for(int shift = 1; shift <= strategy_setup_bars; ++shift)
     {
      buy_setup = buy_setup && BuySetupCondition(shift);
      sell_setup = sell_setup && SellSetupCondition(shift);
     }

   if(ptype == POSITION_TYPE_BUY && sell_setup)
      return -1;
   if(ptype == POSITION_TYPE_SELL && buy_setup)
      return 1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   return ((ask - bid) > (strategy_max_spread_atr_mult * atr));
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(HasOurPosition(ptype, open_time))
      return false;

   const int signal = EvaluateTDTerminationAtLastClosedBar();
   if(signal == 0)
      return false;

   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   if(signal > 0 && d1_close <= d1_sma)
      return false;
   if(signal < 0 && d1_close >= d1_sma)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   const double tp = QM_TakeATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "TD_TERMINATION_BUY" : "TD_TERMINATION_SELL";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing, break-even, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   static datetime last_checked_bar = 0;
   const datetime bar_time = iTime(_Symbol, PERIOD_H4, 0);
   if(bar_time <= 0 || bar_time == last_checked_bar)
      return false;
   last_checked_bar = bar_time;

   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!HasOurPosition(ptype, open_time))
      return false;

   const int entry_shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   if(entry_shift >= strategy_time_stop_h4_bars)
      return true;

   return (OppositeSetupJustClosedForPosition() != 0);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1576\",\"ea\":\"demark-td-termination-count-h4\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
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
