#property strict
#property version   "5.0"
#property description "QM5_1005 Davey World Cup X-bar Breakout (SRC01_S05)"
// Strategy Card: SRC01_S05 (davey-worldcup), CEO G0 APPROVED 2026-04-27.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

//--- Framework inputs --------------------------------------------------------

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1005;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    breakout_lookback            = 48;    // Card S4: X-bar high/low close trigger
input int    rsi_period                   = 30;    // Card S4: 30-bar RSI lookback
input int    rsi_threshold                = 50;    // Card S4: RSI gate (long > 50, short < 50)
input double fixed_dollar_stop            = 1000.0; // Card S5 Layer 1: fixed dollar stop per contract
input int    strategy_atr_period          = 14;    // Card S5: ATR period for trailing and target
input double atr_trail_mult               = 3.0;   // Card S5 Layer 2: Y * ATR trailing stop (S8 default)
input double atr_target_mult              = 5.0;   // Card S5 Layer 3: Z * ATR profit target (S8 default)
input int    wait_after_loser             = 5;     // Card S4: bars to wait after losing trade
input int    wait_after_winner            = 20;    // Card S4: bars to wait after winning trade

//--- Globals -----------------------------------------------------------------

CTrade   g_trade;
datetime g_last_bar_time = 0;
int      g_rsi_handle = INVALID_HANDLE;
bool     g_had_position = false;
datetime g_last_trade_close_time = 0;
bool     g_last_trade_was_winner = false;
bool     g_wait_state_initialized = false;

//--- Utility -----------------------------------------------------------------

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

double TickValuePriceDistancePerLot(const double dollars)
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(dollars <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return (dollars * tick_size / tick_value);
  }

//--- Position helpers --------------------------------------------------------

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = t;
      return true;
     }

   return false;
  }

//--- Inter-trade wait logic (Card S4) ----------------------------------------

void RefreshWaitState()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   if(!HistorySelect(0, TimeCurrent()))
      return;

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_OUT_BY)
         continue;

      g_last_trade_close_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      g_last_trade_was_winner = (HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) > 0.0);
      g_wait_state_initialized = true;
      return;
     }
  }

int BarsSinceTime(const datetime t)
  {
   if(t <= 0)
      return 999;

   for(int i = 0; i < 200; ++i)
     {
      if(iTime(_Symbol, _Period, i) <= t)
         return i;
     }
   return 999;
  }

bool InterTradeWaitSatisfied()
  {
   if(!g_wait_state_initialized)
      return true;

   const int bars_elapsed = BarsSinceTime(g_last_trade_close_time);
   const int required = g_last_trade_was_winner ? wait_after_winner : wait_after_loser;
   return (bars_elapsed >= required);
  }

//--- RSI helper (Card S4) ---------------------------------------------------

double GetRSI()
  {
   if(g_rsi_handle == INVALID_HANDLE)
      return -1.0;

   double values[];
   ArraySetAsSeries(values, true);
   if(CopyBuffer(g_rsi_handle, 0, 1, 1, values) != 1)
      return -1.0;
   return values[0];
  }

//--- Stop/TP computation (Card S5) -------------------------------------------

double FixedDollarStopDistance()
  {
   return TickValuePriceDistancePerLot(fixed_dollar_stop);
  }

double ATRTrailDistance()
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value))
      return 0.0;
   return atr_value * atr_trail_mult;
  }

double ATRTargetDistance()
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value))
      return 0.0;
   return atr_value * atr_target_mult;
  }

//--- Entry signal (Card S4) --------------------------------------------------

bool HasHighCloseBreakout()
  {
   if(breakout_lookback < 2)
      return false;

   // Card S4: close = highest(close, X)
   const double trigger_close = iClose(_Symbol, _Period, 1);
   if(trigger_close <= 0.0)
      return false;

   for(int i = 2; i <= breakout_lookback; ++i)
     {
      const double c = iClose(_Symbol, _Period, i);
      if(c <= 0.0)
         return false;
      if(c > trigger_close)
         return false;
     }
   return true;
  }

bool HasLowCloseBreakout()
  {
   if(breakout_lookback < 2)
      return false;

   // Card S4: close = lowest(close, X)
   const double trigger_close = iClose(_Symbol, _Period, 1);
   if(trigger_close <= 0.0)
      return false;

   for(int i = 2; i <= breakout_lookback; ++i)
     {
      const double c = iClose(_Symbol, _Period, i);
      if(c <= 0.0)
         return false;
      if(c < trigger_close)
         return false;
     }
   return true;
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

   // Card S4: inter-trade wait rules (5 bars after loser, 20 after winner)
   if(!InterTradeWaitSatisfied())
      return false;

   // Card S4: RSI momentum gate
   const double rsi = GetRSI();
   if(rsi < 0.0)
      return false;

   // Card S5: initial SL = tighter of fixed dollar and ATR trail from entry
   const double fixed_dist = FixedDollarStopDistance();
   const double atr_trail_dist = ATRTrailDistance();
   double stop_distance = 0.0;
   if(fixed_dist > 0.0 && atr_trail_dist > 0.0)
      stop_distance = MathMin(fixed_dist, atr_trail_dist);
   else if(fixed_dist > 0.0)
      stop_distance = fixed_dist;
   else if(atr_trail_dist > 0.0)
      stop_distance = atr_trail_dist;
   if(stop_distance <= 0.0)
      return false;

   // Card S5 Layer 3: Z * ATR profit target
   const double tp_distance = ATRTargetDistance();

   // Card S4: buy next bar at market after X-bar high close + RSI > threshold
   if(HasHighCloseBreakout() && rsi > (double)rsi_threshold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      if(tp_distance > 0.0)
         req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry, tp_distance);
      req.reason = "SRC01_S05_LONG_BREAKOUT";
      return (req.sl > 0.0);
     }

   // Card S4: short next bar at market after X-bar low close + RSI < threshold
   if(HasLowCloseBreakout() && rsi < (double)rsi_threshold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      if(tp_distance > 0.0)
         req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, entry, tp_distance);
      req.reason = "SRC01_S05_SHORT_BREAKOUT";
      return (req.sl > 0.0);
     }

   return false;
  }

//--- Trade management (Card S7) ----------------------------------------------

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   ulong ticket;
   if(!GetOurPosition(ptype, price_open, ticket))
      return;

   // Card S7: multi-layer trailing stop with fixed dollar floor
   const double atr_trail_dist = ATRTrailDistance();
   const double fixed_dist = FixedDollarStopDistance();
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   double new_sl = current_sl;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // Card S5 Layer 2: ATR trailing stop from current price
      if(atr_trail_dist > 0.0)
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, bid - atr_trail_dist);
         if(trail_sl > new_sl)
            new_sl = trail_sl;
        }
      // Card S5 Layer 1: fixed dollar floor from entry
      if(fixed_dist > 0.0)
        {
         const double fixed_sl = QM_StopRulesNormalizePrice(_Symbol, price_open - fixed_dist);
         if(new_sl < fixed_sl)
            new_sl = fixed_sl;
        }
      // Ratchet: only move SL toward profit
      if(new_sl <= current_sl)
         return;
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // Card S5 Layer 2: ATR trailing stop from current price
      if(atr_trail_dist > 0.0)
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, ask + atr_trail_dist);
         if(trail_sl > 0.0 && (new_sl <= 0.0 || trail_sl < new_sl))
            new_sl = trail_sl;
        }
      // Card S5 Layer 1: fixed dollar floor from entry
      if(fixed_dist > 0.0)
        {
         const double fixed_sl = QM_StopRulesNormalizePrice(_Symbol, price_open + fixed_dist);
         if(new_sl <= 0.0 || new_sl > fixed_sl)
            new_sl = fixed_sl;
        }
      // Ratchet: only move SL toward profit
      if(current_sl > 0.0 && new_sl >= current_sl)
         return;
     }

   if(new_sl > 0.0 && MathAbs(new_sl - current_sl) > 2.0 * point)
     {
      g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
      g_trade.PositionModify(_Symbol, new_sl, current_tp);
     }
  }

//--- Exit signal (Card S5) ---------------------------------------------------

bool Strategy_ExitSignal()
  {
   // Card S5: no standalone exit; governed by SL/TP layers only
   return false;
  }

//--- Entry execution ---------------------------------------------------------

bool ExecuteEntrySignal(const QM_EntryRequest &req)
  {
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - req.sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(req.type == QM_BUY)
      return g_trade.Buy(lots, _Symbol, 0.0, req.sl, req.tp, req.reason);
   return g_trade.Sell(lots, _Symbol, 0.0, req.sl, req.tp, req.reason);
  }

//--- Event handlers ----------------------------------------------------------

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

   // Card S4: RSI indicator for momentum gate
   g_rsi_handle = iRSI(_Symbol, _Period, rsi_period, PRICE_CLOSE);
   if(g_rsi_handle == INVALID_HANDLE)
     {
      QM_LogEvent(QM_ERROR, "RSI_HANDLE_FAILED", "{}");
      return INIT_FAILED;
     }

   // Card S4 lines 101-103: recover wait state from deal history on restart
   RefreshWaitState();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S05\",\"ea\":\"QM5_1005_davey_worldcup\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_rsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rsi_handle);
      g_rsi_handle = INVALID_HANDLE;
     }
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Card S4: detect position close to refresh inter-trade wait state
   ENUM_POSITION_TYPE ptype;
   double price_open;
   ulong ticket;
   const bool have_position = GetOurPosition(ptype, price_open, ticket);
   if(g_had_position && !have_position)
      RefreshWaitState();
   g_had_position = have_position;

   if(!IsNewBar())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
      return;

   // Card S7: one position per instrument; no pyramiding
   if(have_position)
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      ExecuteEntrySignal(req);
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
