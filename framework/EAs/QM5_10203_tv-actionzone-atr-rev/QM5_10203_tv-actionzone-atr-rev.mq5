#property strict
#property version   "5.0"
#property description "QM5_10203 TradingView ActionZone ATR Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10203;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ema_period      = 9;
input int    strategy_slow_ema_period      = 21;
input int    strategy_atr_period           = 14;
input double strategy_atr_stop_mult        = 1.5;
input int    strategy_rsi_period           = 14;
input double strategy_rsi_overbought       = 70.0;
input double strategy_rsi_oversold         = 30.0;
input int    strategy_min_hold_bars        = 3;
input double strategy_max_spread_stop_frac = 0.15;

int      g_pending_reversal_dir = 0;
datetime g_reversal_signal_bar = 0;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_GetPosition(ulong &ticket, ENUM_POSITION_TYPE &type, datetime &open_time)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int Strategy_EmaCrossSignal()
  {
   if(strategy_fast_ema_period <= 0 || strategy_slow_ema_period <= strategy_fast_ema_period)
      return 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      return 1;
   if(fast_2 >= slow_2 && fast_1 < slow_1)
      return -1;
   return 0;
  }

int Strategy_HeldClosedBars(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false);
   if(shift < 0)
      return 0;
   return shift;
  }

double Strategy_StopForSide(const QM_OrderType side)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_ema = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(fast_ema <= 0.0 || atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return 0.0;

   double stop = 0.0;
   if(side == QM_BUY)
     {
      stop = fast_ema - strategy_atr_stop_mult * atr;
      const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
      const double low_1 = iLow(_Symbol, tf, 1);
      if(rsi > strategy_rsi_overbought && low_1 > 0.0)
         stop = MathMax(stop, low_1);
     }
   else
     {
      stop = fast_ema + strategy_atr_stop_mult * atr;
      const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
      const double high_1 = iHigh(_Symbol, tf, 1);
      if(rsi < strategy_rsi_oversold && high_1 > 0.0)
         stop = MathMin(stop, high_1);
     }

   return Strategy_NormalizePrice(stop);
  }

bool Strategy_SpreadFilterPasses(const double entry, const double stop)
  {
   if(strategy_max_spread_stop_frac <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_distance = MathAbs(entry - stop);
   if(ask <= 0.0 || bid <= 0.0 || stop_distance <= 0.0)
      return false;
   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_frac);
  }

bool Strategy_BuildRequest(const int direction, QM_EntryRequest &req)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "ACTIONZONE_ATR_LONG" : "ACTIONZONE_ATR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = QM_EntryMarketPrice(req.type);
   const double stop = Strategy_StopForSide(req.type);
   if(entry <= 0.0 || stop <= 0.0)
      return false;
   if(direction > 0 && stop >= entry)
      return false;
   if(direction < 0 && stop <= entry)
      return false;
   if(!Strategy_SpreadFilterPasses(entry, stop))
      return false;

   req.sl = stop;
   return true;
  }

// No Trade Filter: framework handles time, news, kill-switch, and Friday close;
// this hook enforces the card's spread-vs-stop filter at entry time.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: H1 baseline fast/slow EMA cross when flat, plus next-bar
// reversal after an opposite cross closed the prior position.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_rsi_period <= 0 || strategy_min_hold_bars < 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime signal_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   if(g_pending_reversal_dir != 0 && signal_bar > g_reversal_signal_bar)
     {
      const int dir = g_pending_reversal_dir;
      if(Strategy_BuildRequest(dir, req))
        {
         req.reason = (dir > 0) ? "ACTIONZONE_ATR_REV_LONG" : "ACTIONZONE_ATR_REV_SHORT";
         g_pending_reversal_dir = 0;
         g_reversal_signal_bar = 0;
         return true;
        }
     }

   const int cross = Strategy_EmaCrossSignal();
   if(cross == 0)
      return false;
   return Strategy_BuildRequest(cross, req);
  }

// Trade Management: card stop rule trails only in the favorable direction, with
// RSI tightening to the overbought/oversold bar extreme.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   datetime open_time;
   if(!Strategy_GetPosition(ticket, type, open_time))
      return;

   const QM_OrderType side = (type == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
   const double candidate = Strategy_StopForSide(side);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(candidate <= 0.0 || point <= 0.0)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(candidate < bid && (current_sl <= 0.0 || candidate > current_sl + point * 0.5))
         QM_TM_MoveSL(ticket, candidate, "actionzone_atr_stop_raise");
     }
   else if(type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(candidate > ask && (current_sl <= 0.0 || candidate < current_sl - point * 0.5))
         QM_TM_MoveSL(ticket, candidate, "actionzone_atr_stop_lower");
     }
  }

// Trade Close: opposite EMA cross closes only after the minimum hold; ATR stop
// is enforced by broker SL and can close before the minimum hold.
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   datetime open_time;
   if(!Strategy_GetPosition(ticket, type, open_time))
      return false;

   const int cross = Strategy_EmaCrossSignal();
   if(cross == 0)
      return false;
   if(type == POSITION_TYPE_BUY && cross >= 0)
      return false;
   if(type == POSITION_TYPE_SELL && cross <= 0)
      return false;
   if(Strategy_HeldClosedBars(open_time) < strategy_min_hold_bars)
      return false;

   g_pending_reversal_dir = cross;
   g_reversal_signal_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   return true;
  }

// News Filter Hook: no card-specific override; P8 uses the central framework
// news filter callable through this hook path.
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10203\",\"ea\":\"tv-actionzone-atr-rev\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
