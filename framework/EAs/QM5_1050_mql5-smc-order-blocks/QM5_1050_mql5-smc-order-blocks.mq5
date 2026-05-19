#property strict
#property version   "5.0"
#property description "QM5_1050 SMC Order Blocks + Break of Structure + Inducement"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1050;
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
input ENUM_TIMEFRAMES strategy_trend_tf      = PERIOD_H4;
input int             strategy_ob_lookback   = 20;
input int             strategy_bos_lookback  = 10;
input int             strategy_atr_period    = 14;
input double          strategy_impulse_atr_mult = 1.5;
input int             strategy_sl_offset_points = 10;
input double          strategy_rr            = 4.0;
input int             strategy_session_start_hour = 7;
input int             strategy_session_end_hour   = 17;
input int             strategy_max_spread_points  = 20;
input bool            strategy_move_be_after_1r   = true;
input int             strategy_state_max_age_bars = 48;

struct SMC_OrderBlock
  {
   bool     valid;
   bool     bullish;
   double   high;
   double   low;
   datetime time;
  };

datetime       g_last_advanced_bar = 0;
int            g_cached_trend = 0;
bool           g_cached_bos_up = false;
bool           g_cached_bos_down = false;
bool           g_cached_induce_up = false;
bool           g_cached_induce_down = false;
datetime       g_cached_bos_up_time = 0;
datetime       g_cached_bos_down_time = 0;
datetime       g_cached_induce_up_time = 0;
datetime       g_cached_induce_down_time = 0;
SMC_OrderBlock g_cached_bullish_ob;
SMC_OrderBlock g_cached_bearish_ob;

int HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

double HighestHighTF(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   double hi = -DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double v = iHigh(_Symbol, tf, i);
      if(v <= 0.0)
         return 0.0;
      hi = MathMax(hi, v);
     }
   return hi;
  }

double LowestLowTF(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars)
  {
   double lo = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double v = iLow(_Symbol, tf, i);
      if(v <= 0.0)
         return 0.0;
      lo = MathMin(lo, v);
     }
   return lo;
  }

void ClearCachedState()
  {
   g_cached_trend = 0;
   g_cached_bos_up = false;
   g_cached_bos_down = false;
   g_cached_induce_up = false;
   g_cached_induce_down = false;
   g_cached_bos_up_time = 0;
   g_cached_bos_down_time = 0;
   g_cached_induce_up_time = 0;
   g_cached_induce_down_time = 0;
   g_cached_bullish_ob.valid = false;
   g_cached_bearish_ob.valid = false;
  }

bool StateExpired(const datetime state_time)
  {
   if(state_time <= 0)
      return true;

   const int max_age = MathMax(1, strategy_state_max_age_bars);
   const int shift = iBarShift(_Symbol, _Period, state_time, true);
   return (shift < 0 || shift > max_age);
  }

void PruneCachedState()
  {
   if(g_cached_bos_up && StateExpired(g_cached_bos_up_time))
      g_cached_bos_up = false;
   if(g_cached_bos_down && StateExpired(g_cached_bos_down_time))
      g_cached_bos_down = false;
   if(g_cached_induce_up && StateExpired(g_cached_induce_up_time))
      g_cached_induce_up = false;
   if(g_cached_induce_down && StateExpired(g_cached_induce_down_time))
      g_cached_induce_down = false;
   if(g_cached_bullish_ob.valid && StateExpired(g_cached_bullish_ob.time))
      g_cached_bullish_ob.valid = false;
   if(g_cached_bearish_ob.valid && StateExpired(g_cached_bearish_ob.time))
      g_cached_bearish_ob.valid = false;
  }

int CachedTrendDirection()
  {
   const int n = MathMax(3, strategy_bos_lookback);
   const double recent_high = HighestHighTF(strategy_trend_tf, 1, n);
   const double prior_high = HighestHighTF(strategy_trend_tf, 1 + n, n);
   const double recent_low = LowestLowTF(strategy_trend_tf, 1, n);
   const double prior_low = LowestLowTF(strategy_trend_tf, 1 + n, n);

   if(recent_high <= 0.0 || prior_high <= 0.0 || recent_low <= 0.0 || prior_low <= 0.0)
      return 0;
   if(recent_high > prior_high && recent_low > prior_low)
      return 1;
   if(recent_high < prior_high && recent_low < prior_low)
      return -1;
   return 0;
  }

bool FindOrderBlock(const bool bullish, SMC_OrderBlock &ob)
  {
   ob.valid = false;
   ob.bullish = bullish;
   ob.high = 0.0;
   ob.low = 0.0;
   ob.time = 0;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int lookback = MathMax(3, strategy_ob_lookback);
   for(int i = 2; i <= lookback; ++i)
     {
      const double open = iOpen(_Symbol, _Period, i);
      const double close = iClose(_Symbol, _Period, i);
      const double high = iHigh(_Symbol, _Period, i);
      const double low = iLow(_Symbol, _Period, i);
      const double impulse_open = iOpen(_Symbol, _Period, i - 1);
      const double impulse_close = iClose(_Symbol, _Period, i - 1);
      const double impulse_high = iHigh(_Symbol, _Period, i - 1);
      const double impulse_low = iLow(_Symbol, _Period, i - 1);
      if(open <= 0.0 || close <= 0.0 || high <= 0.0 || low <= 0.0 ||
         impulse_open <= 0.0 || impulse_close <= 0.0 || impulse_high <= 0.0 || impulse_low <= 0.0)
         continue;

      if((impulse_high - impulse_low) < atr * strategy_impulse_atr_mult)
         continue;

      if(bullish && close < open && impulse_close > impulse_open && impulse_close > high)
        {
         ob.valid = true;
         ob.bullish = true;
         ob.high = high;
         ob.low = low;
         ob.time = iTime(_Symbol, _Period, i);
         return true;
        }

      if(!bullish && close > open && impulse_close < impulse_open && impulse_close < low)
        {
         ob.valid = true;
         ob.bullish = false;
         ob.high = high;
         ob.low = low;
         ob.time = iTime(_Symbol, _Period, i);
         return true;
        }
     }

   return false;
  }

void AdvanceState_OnNewBar()
  {
   const datetime closed_bar = iTime(_Symbol, _Period, 1);
   if(closed_bar <= 0 || closed_bar == g_last_advanced_bar)
      return;

   g_last_advanced_bar = closed_bar;
   PruneCachedState();

   const int n = MathMax(3, strategy_bos_lookback);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double prior_high = HighestHighTF((ENUM_TIMEFRAMES)_Period, 2, n);
   const double prior_low = LowestLowTF((ENUM_TIMEFRAMES)_Period, 2, n);
   if(close1 <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return;

   g_cached_trend = CachedTrendDirection();
   if(close1 > prior_high)
     {
      g_cached_bos_up = true;
      g_cached_bos_down = false;
      g_cached_bos_up_time = closed_bar;
      g_cached_bos_down_time = 0;
     }
   else if(close1 < prior_low)
     {
      g_cached_bos_down = true;
      g_cached_bos_up = false;
      g_cached_bos_down_time = closed_bar;
      g_cached_bos_up_time = 0;
     }

   const int induce_lookback = MathMax(3, MathMin(strategy_bos_lookback, strategy_ob_lookback));
   const double low2 = iLow(_Symbol, _Period, 2);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double induce_low = LowestLowTF((ENUM_TIMEFRAMES)_Period, 3, induce_lookback);
   const double induce_high = HighestHighTF((ENUM_TIMEFRAMES)_Period, 3, induce_lookback);
   if(induce_low > 0.0 && low2 < induce_low && close2 > induce_low)
     {
      g_cached_induce_up = true;
      g_cached_induce_down = false;
      g_cached_induce_up_time = iTime(_Symbol, _Period, 2);
      g_cached_induce_down_time = 0;
     }
   else if(induce_high > 0.0 && high2 > induce_high && close2 < induce_high)
     {
      g_cached_induce_down = true;
      g_cached_induce_up = false;
      g_cached_induce_down_time = iTime(_Symbol, _Period, 2);
      g_cached_induce_up_time = 0;
     }

   SMC_OrderBlock bullish_ob;
   SMC_OrderBlock bearish_ob;
   if(FindOrderBlock(true, bullish_ob))
      g_cached_bullish_ob = bullish_ob;
   if(FindOrderBlock(false, bearish_ob))
      g_cached_bearish_ob = bearish_ob;
  }

bool GetOurPosition(ulong &ticket, double &open_price, double &sl, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   open_price = 0.0;
   sl = 0.0;
   ptype = POSITION_TYPE_BUY;

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

      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int hour = HourOf(TimeCurrent());
   if(hour < strategy_session_start_hour || hour >= strategy_session_end_hour)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > strategy_max_spread_points)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   AdvanceState_OnNewBar();

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || close1 <= 0.0 || close2 <= 0.0 || strategy_rr <= 0.0)
      return false;

   if(g_cached_trend > 0 && g_cached_bos_up && g_cached_induce_up && g_cached_bullish_ob.valid)
     {
      if(close2 >= g_cached_bullish_ob.low && close2 <= g_cached_bullish_ob.high && close1 > g_cached_bullish_ob.high)
        {
         req.type = QM_BUY;
         req.price = ask;
         req.sl = g_cached_bullish_ob.low - (strategy_sl_offset_points * point);
         req.tp = ask + ((ask - req.sl) * strategy_rr);
         req.reason = "SMC_BULLISH_OB_BOS_INDUCEMENT";
         return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
        }
     }

   if(g_cached_trend < 0 && g_cached_bos_down && g_cached_induce_down && g_cached_bearish_ob.valid)
     {
      if(close2 <= g_cached_bearish_ob.high && close2 >= g_cached_bearish_ob.low && close1 < g_cached_bearish_ob.low)
        {
         req.type = QM_SELL;
         req.price = bid;
         req.sl = g_cached_bearish_ob.high + (strategy_sl_offset_points * point);
         req.tp = bid - ((req.sl - bid) * strategy_rr);
         req.reason = "SMC_BEARISH_OB_BOS_INDUCEMENT";
         return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
        }
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_move_be_after_1r)
      return;

   ulong ticket = 0;
   double open_price = 0.0;
   double sl = 0.0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!GetOurPosition(ticket, open_price, sl, ptype))
      return;
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double risk = open_price - sl;
      if(risk > 0.0 && bid >= open_price + risk && sl < open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price + point, _Digits), "move_be_after_1r");
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk = sl - open_price;
      if(risk > 0.0 && ask <= open_price - risk && sl > open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price - point, _Digits), "move_be_after_1r");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1050\",\"ea\":\"mql5_smc_order_blocks\"}");
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
