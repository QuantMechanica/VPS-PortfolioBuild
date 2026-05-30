#property strict
#property version   "5.0"
#property description "QM5_10439 MQL5 ASQ Seven-Condition Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10439;
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
input int    strategy_fast_ema_period       = 150;
input int    strategy_slow_ema_period       = 510;
input int    strategy_atr_period            = 14;
input double strategy_ema_sep_atr_mult      = 0.50;
input int    strategy_breakout_lookback     = 20;
input double strategy_breakout_atr_buffer   = 0.25;
input int    strategy_rsi_period            = 14;
input double strategy_long_rsi_min          = 40.0;
input double strategy_long_rsi_max          = 65.0;
input double strategy_short_rsi_min         = 35.0;
input double strategy_short_rsi_max         = 60.0;
input bool   strategy_use_h1_filter         = true;
input int    strategy_h1_fast_ema_period    = 50;
input int    strategy_h1_slow_ema_period    = 200;
input double strategy_sl_atr_mult           = 1.20;
input double strategy_h1_sl_cap_atr_mult    = 3.00;
input double strategy_tp_rr                 = 2.00;
input int    strategy_session_start_hour    = 8;
input int    strategy_session_end_hour      = 20;
input int    strategy_friday_cutoff_hour    = 16;
input double strategy_max_spread_atr_frac   = 0.15;
input int    strategy_max_trades_per_day    = 3;
input int    strategy_breakeven_buffer_pips = 0;

int g_trade_day_key = 0;
int g_trades_today = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_ResetDailyCounterIfNeeded(const datetime t)
  {
   const int key = Strategy_DayKey(t);
   if(key != g_trade_day_key)
     {
      g_trade_day_key = key;
      g_trades_today = 0;
     }
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

double Strategy_HighestPriorHigh(const int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_M5, shift);
      if(high <= 0.0)
         return 0.0;
      highest = MathMax(highest, high);
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

double Strategy_LowestPriorLow(const int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double low = iLow(_Symbol, PERIOD_M5, shift);
      if(low <= 0.0)
         return 0.0;
      lowest = MathMin(lowest, low);
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double Strategy_StopByAtrCap(const QM_OrderType side, const double entry)
  {
   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_m5 <= 0.0 || atr_h1 <= 0.0 || entry <= 0.0)
      return 0.0;

   double sl_distance = atr_m5 * strategy_sl_atr_mult;
   const double cap_distance = atr_h1 * strategy_h1_sl_cap_atr_mult;
   if(cap_distance > 0.0)
      sl_distance = MathMin(sl_distance, cap_distance);

   const double raw_sl = QM_OrderTypeIsBuy(side) ? (entry - sl_distance) : (entry + sl_distance);
   return NormalizeDouble(raw_sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_ResetDailyCounterIfNeeded(broker_now);

   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return true;
   if(strategy_max_trades_per_day > 0 && g_trades_today >= strategy_max_trades_per_day)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   if((ask - bid) > atr * strategy_max_spread_atr_frac)
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

   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_breakout_lookback <= 0 || strategy_atr_period <= 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   const double close2 = iClose(_Symbol, PERIOD_M5, 2);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double ema_fast = QM_EMA(_Symbol, PERIOD_M5, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_M5, strategy_slow_ema_period, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || atr <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 || rsi <= 0.0)
      return false;
   if(MathAbs(ema_fast - ema_slow) <= atr * strategy_ema_sep_atr_mult)
      return false;

   if(strategy_use_h1_filter)
     {
      const double h1_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_fast_ema_period, 1);
      const double h1_slow = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_slow_ema_period, 1);
      if(h1_fast <= 0.0 || h1_slow <= 0.0)
         return false;

      if(ema_fast > ema_slow && h1_fast <= h1_slow)
         return false;
      if(ema_fast < ema_slow && h1_fast >= h1_slow)
         return false;
     }

   const double highest = Strategy_HighestPriorHigh(strategy_breakout_lookback);
   const double lowest = Strategy_LowestPriorLow(strategy_breakout_lookback);
   if(highest <= 0.0 || lowest <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buffer = atr * strategy_breakout_atr_buffer;

   if(ema_fast > ema_slow &&
      close1 > ema_fast && close1 > ema_slow &&
      close1 > highest + buffer &&
      rsi >= strategy_long_rsi_min && rsi <= strategy_long_rsi_max &&
      close1 > close2 &&
      ask > 0.0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = Strategy_StopByAtrCap(QM_BUY, ask);
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_tp_rr);
      req.reason = "ASQ_SEVEN_CONDITION_LONG";
     }
   else if(ema_fast < ema_slow &&
           close1 < ema_fast && close1 < ema_slow &&
           close1 < lowest - buffer &&
           rsi >= strategy_short_rsi_min && rsi <= strategy_short_rsi_max &&
           close1 < close2 &&
           bid > 0.0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = Strategy_StopByAtrCap(QM_SELL, bid);
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_tp_rr);
      req.reason = "ASQ_SEVEN_CONDITION_SHORT";
     }
   else
      return false;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   g_trades_today++;
   return true;
  }

void Strategy_ManageOpenPosition()
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

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || sl <= 0.0 || point <= 0.0)
         continue;

      const int trigger_pips = (int)MathMax(1.0, MathRound(MathAbs(open_price - sl) / point));
      QM_TM_MoveToBreakEven(ticket, trigger_pips, strategy_breakeven_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
