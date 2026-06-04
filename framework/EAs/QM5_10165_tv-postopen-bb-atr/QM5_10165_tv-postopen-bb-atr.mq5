#property strict
#property version   "5.0"
#property description "QM5_10165 TradingView post-open BB ATR breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10165;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_bb_period           = 14;
input double strategy_bb_deviation        = 1.5;
input double strategy_bb_near_basis_frac  = 0.50;
input int    strategy_ema_fast_period     = 10;
input int    strategy_ema_slow_period     = 200;
input int    strategy_rsi_period          = 7;
input double strategy_rsi_min             = 30.0;
input int    strategy_adx_period          = 7;
input double strategy_adx_min             = 10.0;
input int    strategy_resistance_bars     = 20;
input int    strategy_resistance_touches  = 2;
input double strategy_touch_tolerance_atr = 0.20;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_atr_tp_mult         = 4.0;
input double strategy_max_spread_sl_frac  = 0.15;
input int    strategy_de_open_start_hhmm  = 800;
input int    strategy_de_open_end_hhmm    = 1200;
input int    strategy_us_open_start_hhmm  = 1530;
input int    strategy_us_open_end_hhmm    = 1900;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

bool Strategy_InWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool Strategy_InTradingWindow(const datetime t)
  {
   const int hhmm = Strategy_Hhmm(t);
   return (Strategy_InWindow(hhmm, strategy_de_open_start_hhmm, strategy_de_open_end_hhmm) ||
           Strategy_InWindow(hhmm, strategy_us_open_start_hhmm, strategy_us_open_end_hhmm));
  }

bool Strategy_IsBearishCandle(const int shift)
  {
   const double open = iOpen(_Symbol, _Period, shift); // perf-allowed: bounded bespoke candle-colour check
   const double close = iClose(_Symbol, _Period, shift); // perf-allowed: bounded bespoke candle-colour check
   return (open > 0.0 && close > 0.0 && close < open);
  }

bool Strategy_FindResistance(double &resistance, int &touch_count)
  {
   resistance = 0.0;
   touch_count = 0;

   if(strategy_resistance_bars < 2 || strategy_resistance_touches < 1)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double tolerance = MathMax(point, atr * strategy_touch_tolerance_atr);
   for(int candidate_shift = 2; candidate_shift < 2 + strategy_resistance_bars; ++candidate_shift)
     {
      const double candidate = iHigh(_Symbol, _Period, candidate_shift); // perf-allowed: bounded two-touch resistance scan
      if(candidate <= 0.0)
         return false;

      int candidate_touches = 0;
      for(int touch_shift = 2; touch_shift < 2 + strategy_resistance_bars; ++touch_shift)
        {
         const double high = iHigh(_Symbol, _Period, touch_shift); // perf-allowed: bounded two-touch resistance scan
         if(high <= 0.0)
            return false;
         if(MathAbs(high - candidate) <= tolerance)
            candidate_touches++;
        }

      if(candidate_touches >= strategy_resistance_touches && candidate > resistance)
        {
         resistance = candidate;
         touch_count = candidate_touches;
        }
     }

   return (touch_count >= strategy_resistance_touches);
  }

bool Strategy_PriceNearBasis(const int shift)
  {
   const double close_price = iClose(_Symbol, _Period, shift); // perf-allowed: setup-bar BB lateralization check
   const double middle = QM_BB_Middle(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double upper = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(close_price <= 0.0 || middle <= 0.0 || upper <= lower)
      return false;

   const double half_width = (upper - lower) * 0.5;
   if(half_width <= 0.0)
      return false;

   return (MathAbs(close_price - middle) <= half_width * strategy_bb_near_basis_frac);
  }

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_InTradingWindow(broker_now))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0)
      return true;

   return ((ask - bid) > stop_distance * strategy_max_spread_sl_frac);
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

   // perf-allowed: closed breakout-bar session check
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed
   if(bar_time <= 0 || !Strategy_InTradingWindow(bar_time))
      return false;

   if(!Strategy_PriceNearBasis(2))
      return false;

   // perf-allowed: closed-bar resistance confirmation
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: closed setup-bar resistance confirmation
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   if(close1 <= ema_fast || close1 <= ema_slow)
      return false;

   if(QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1) <= strategy_rsi_min)
      return false;

   if(QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1) <= strategy_adx_min)
      return false;

   if(!Strategy_IsBearishCandle(2))
      return false;

   if(Strategy_IsBearishCandle(2) && Strategy_IsBearishCandle(3))
      return false;

   double resistance = 0.0;
   int touches = 0;
   if(!Strategy_FindResistance(resistance, touches))
      return false;

   if(close1 <= resistance || close2 > resistance)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "POST_OPEN_BB_ATR_BREAKOUT_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR SL/TP only; no trailing, partial, or break-even move.
  }

bool Strategy_ExitSignal()
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

      if(!Strategy_InTradingWindow(TimeCurrent()))
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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10165\",\"ea\":\"QM5_10165_tv_postopen_bb_atr\"}");
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
