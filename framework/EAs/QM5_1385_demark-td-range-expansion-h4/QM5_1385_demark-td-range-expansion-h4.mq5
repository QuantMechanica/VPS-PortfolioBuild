#property strict
#property version   "5.0"
#property description "QM5_1385 DeMark TD Range Expansion H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1385;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_tr_lookback        = 10;
input double strategy_expansion_min      = 1.50;
input double strategy_expansion_max      = 4.00;
input double strategy_close_strength     = 0.70;
input double strategy_body_ratio_min     = 0.55;
input int    strategy_breakout_bars      = 5;
input int    strategy_sma_period         = 50;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_buffer      = 0.30;
input double strategy_sl_atr_cap         = 2.50;
input double strategy_tp_range_mult      = 1.50;
input double strategy_be_range_mult      = 0.75;
input double strategy_trail_atr_buffer   = 0.50;
input int    strategy_time_stop_bars     = 18;
input int    strategy_fade_bars          = 4;
input int    strategy_cooldown_bars      = 12;
input int    strategy_session_start_hr   = 6;
input int    strategy_session_end_hr     = 22;
input double strategy_spread_atr_mult    = 0.40;

datetime g_last_sl_time = 0;

double TrueRangeAt(const int shift)
  {
   const double high = iHigh(_Symbol, PERIOD_H4, shift);
   const double low = iLow(_Symbol, PERIOD_H4, shift);
   const double prev_close = iClose(_Symbol, PERIOD_H4, shift + 1);
   if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
      return 0.0;
   return MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
  }

double ExpansionRatioAt(const int shift)
  {
   const double tr = TrueRangeAt(shift);
   if(tr <= 0.0 || strategy_tr_lookback <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift + 1; i <= shift + strategy_tr_lookback; ++i)
     {
      const double prior_tr = TrueRangeAt(i);
      if(prior_tr <= 0.0)
         return 0.0;
      sum += prior_tr;
     }

   const double avg_tr = sum / (double)strategy_tr_lookback;
   return (avg_tr > 0.0) ? (tr / avg_tr) : 0.0;
  }

bool IsTdRangeExpansion(const int shift, int &direction)
  {
   direction = 0;
   const double open = iOpen(_Symbol, PERIOD_H4, shift);
   const double high = iHigh(_Symbol, PERIOD_H4, shift);
   const double low = iLow(_Symbol, PERIOD_H4, shift);
   const double close = iClose(_Symbol, PERIOD_H4, shift);
   if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
      return false;

   const double range = high - low;
   const double body_ratio = MathAbs(close - open) / range;
   const double expansion_ratio = ExpansionRatioAt(shift);
   if(expansion_ratio < strategy_expansion_min || expansion_ratio > strategy_expansion_max)
      return false;
   if(body_ratio < strategy_body_ratio_min)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, shift);
   if(sma <= 0.0)
      return false;

   bool new_high = true;
   bool new_low = true;
   for(int i = shift + 1; i <= shift + strategy_breakout_bars; ++i)
     {
      const double prior_high = iHigh(_Symbol, PERIOD_H4, i);
      const double prior_low = iLow(_Symbol, PERIOD_H4, i);
      if(prior_high <= 0.0 || prior_low <= 0.0)
         return false;
      if(close <= prior_high)
         new_high = false;
      if(close >= prior_low)
         new_low = false;
     }

   if(close > open && close > (open + range * strategy_close_strength) && new_high && close > sma)
     {
      direction = 1;
      return true;
     }

   if(close < open && close < (open + range * (1.0 - strategy_close_strength)) && new_low && close < sma)
     {
      direction = -1;
      return true;
     }

   return false;
  }

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int BarsSincePositionOpen(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

bool GetExpansionBarForPosition(const datetime open_time, int &expansion_shift)
  {
   expansion_shift = BarsSincePositionOpen(open_time) + 1;
   return (iTime(_Symbol, PERIOD_H4, expansion_shift) > 0);
  }

void RefreshLastStopLossTime()
  {
   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 86400 * 90, now))
      return;

   const int magic = QM_FrameworkMagic();
   datetime latest = g_last_sl_time;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_SL)
         continue;

      const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(deal_time > latest)
         latest = deal_time;
     }
   g_last_sl_time = latest;
  }

bool CooldownActive()
  {
   RefreshLastStopLossTime();
   if(g_last_sl_time <= 0)
      return false;
   const int shift = iBarShift(_Symbol, PERIOD_H4, g_last_sl_time, false);
   return (shift >= 0 && shift < strategy_cooldown_bars);
  }

bool Strategy_NoTradeFilter()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_session_end_hr || dt.hour < strategy_session_start_hr)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0.0 && ask > bid && (ask - bid) >= atr * strategy_spread_atr_mult)
      return true;

   return false;
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

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;
   if(CooldownActive())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_session_end_hr || dt.hour < strategy_session_start_hr)
      return false;

   if(ExpansionRatioAt(2) >= strategy_expansion_min)
      return false;

   int direction = 0;
   if(!IsTdRangeExpansion(1, direction) || direction == 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if((ask - bid) >= atr * strategy_spread_atr_mult)
      return false;

   const double high1 = iHigh(_Symbol, PERIOD_H4, 1);
   const double low1 = iLow(_Symbol, PERIOD_H4, 1);
   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   const double entry = (direction > 0) ? ask : bid;
   const double max_sl_distance = strategy_sl_atr_cap * atr;
   double sl = 0.0;
   if(direction > 0)
     {
      req.type = QM_BUY;
      sl = low1 - strategy_sl_atr_buffer * atr;
      if((entry - sl) > max_sl_distance)
         sl = entry - max_sl_distance;
      req.tp = entry + strategy_tp_range_mult * range1;
      req.reason = "TD_RE_BUY";
     }
   else
     {
      req.type = QM_SELL;
      sl = high1 + strategy_sl_atr_buffer * atr;
      if((sl - entry) > max_sl_distance)
         sl = entry + max_sl_distance;
      req.tp = entry - strategy_tp_range_mult * range1;
      req.reason = "TD_RE_SELL";
     }

   if(sl <= 0.0 || MathAbs(entry - sl) < point)
      return false;
   req.sl = sl;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!GetOurPosition(ticket, position_type, open_price, open_time))
      return;

   int expansion_shift = 0;
   if(!GetExpansionBarForPosition(open_time, expansion_shift))
      return;

   const double high_exp = iHigh(_Symbol, PERIOD_H4, expansion_shift);
   const double low_exp = iLow(_Symbol, PERIOD_H4, expansion_shift);
   const double expansion_range = high_exp - low_exp;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(expansion_range <= 0.0 || atr <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved < strategy_be_range_mult * expansion_range)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   if(point <= 0.0)
      return;

   const bool be_improves = (current_sl <= 0.0) ||
                            (is_buy ? (open_price > current_sl + point * 0.5)
                                    : (open_price < current_sl - point * 0.5));
   if(be_improves)
      QM_TM_MoveSL(ticket, open_price, "td_re_break_even");

   const double prior_low = iLow(_Symbol, PERIOD_H4, 1);
   const double prior_high = iHigh(_Symbol, PERIOD_H4, 1);
   const double trail_sl = is_buy ? (prior_low - strategy_trail_atr_buffer * atr)
                                  : (prior_high + strategy_trail_atr_buffer * atr);
   if(trail_sl <= 0.0)
      return;

   const double refreshed_sl = PositionGetDouble(POSITION_SL);
   const bool trail_improves = (refreshed_sl <= 0.0) ||
                               (is_buy ? (trail_sl > refreshed_sl + point * 0.5 && trail_sl >= open_price)
                                       : (trail_sl < refreshed_sl - point * 0.5 && trail_sl <= open_price));
   if(trail_improves)
      QM_TM_MoveSL(ticket, trail_sl, "td_re_prior_bar_trail");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   const int bars_since = BarsSincePositionOpen(open_time);
   if(bars_since >= strategy_time_stop_bars)
      return true;

   if(bars_since <= strategy_fade_bars)
     {
      int expansion_shift = 0;
      if(!GetExpansionBarForPosition(open_time, expansion_shift))
         return false;
      const double exp_open = iOpen(_Symbol, PERIOD_H4, expansion_shift);
      const double exp_high = iHigh(_Symbol, PERIOD_H4, expansion_shift);
      const double exp_low = iLow(_Symbol, PERIOD_H4, expansion_shift);
      const double range = exp_high - exp_low;
      const double close1 = iClose(_Symbol, PERIOD_H4, 1);
      if(exp_open <= 0.0 || range <= 0.0 || close1 <= 0.0)
         return false;

      if(position_type == POSITION_TYPE_BUY && close1 < (exp_open - range))
         return true;
      if(position_type == POSITION_TYPE_SELL && close1 > (exp_open + range))
         return true;
     }

   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1385\",\"strategy\":\"td_range_expansion_h4\"}");
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
