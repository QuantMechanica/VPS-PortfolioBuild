#property strict
#property version   "5.0"
#property description "QM5_10638 Elite Trader RSI Bollinger Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10638;
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
input int    strategy_ema_period          = 50;
input int    strategy_rsi_period          = 8;
input int    strategy_rsi_bb_period       = 20;
input double strategy_rsi_bb_deviation    = 2.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 1.5;
input double strategy_atr_target_mult     = 1.0;
input int    strategy_atr_median_lookback = 20;
input int    strategy_trail_lookback      = 3;
input int    strategy_max_hold_bars       = 20;

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
  }

bool Strategy_HasOpenPositionOrPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_RsiBands(const int shift, double &rsi_value, double &lower, double &upper)
  {
   rsi_value = 0.0;
   lower = 0.0;
   upper = 0.0;

   if(strategy_rsi_period <= 0 || strategy_rsi_bb_period <= 1 || strategy_rsi_bb_deviation <= 0.0)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   for(int i = 0; i < strategy_rsi_bb_period; ++i)
     {
      const double r = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + i);
      if(r <= 0.0)
         return false;
      if(i == 0)
         rsi_value = r;
      sum += r;
      sum_sq += r * r;
     }

   const double mean = sum / (double)strategy_rsi_bb_period;
   double variance = (sum_sq / (double)strategy_rsi_bb_period) - (mean * mean);
   if(variance < 0.0)
      variance = 0.0;
   const double stdev = MathSqrt(variance);
   upper = mean + strategy_rsi_bb_deviation * stdev;
   lower = mean - strategy_rsi_bb_deviation * stdev;
   return true;
  }

bool Strategy_AtrMedian(double &atr_now, double &atr_median)
  {
   atr_now = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   atr_median = 0.0;
   if(strategy_atr_period <= 0 || strategy_atr_median_lookback <= 0 || atr_now <= 0.0)
      return false;

   double values[];
   ArrayResize(values, strategy_atr_median_lookback);
   for(int i = 0; i < strategy_atr_median_lookback; ++i)
     {
      values[i] = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, i + 1);
      if(values[i] <= 0.0)
         return false;
     }

   ArraySort(values);
   const int mid = strategy_atr_median_lookback / 2;
   if((strategy_atr_median_lookback % 2) == 0)
      atr_median = (values[mid - 1] + values[mid]) * 0.5;
   else
      atr_median = values[mid];
   return (atr_median > 0.0);
  }

bool Strategy_StructureExtremes(const int lookback, double &lowest, double &highest)
  {
   lowest = 0.0;
   highest = 0.0;
   return QM_StopRulesReadStructureExtremes(_Symbol, lookback, lowest, highest);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(_Period != PERIOD_D1)
      return false;
   if(Strategy_HasOpenPositionOrPendingOrder())
      return false;

   double setup_low = 0.0;
   double setup_high = 0.0;
   if(!Strategy_StructureExtremes(1, setup_low, setup_high))
      return false;

   const double setup_open = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, 0); // perf-allowed: card gap-open skip reads current session open once per closed-bar entry pass.
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   double rsi = 0.0;
   double rsi_lower = 0.0;
   double rsi_upper = 0.0;
   double atr = 0.0;
   double atr_median = 0.0;
   if(setup_open <= 0.0 || ema <= 0.0)
      return false;
   if(!Strategy_RsiBands(1, rsi, rsi_lower, rsi_upper))
      return false;
   if(!Strategy_AtrMedian(atr, atr_median))
      return false;
   if(atr < atr_median)
      return false;

   if(strategy_atr_stop_mult <= 0.0 || strategy_atr_target_mult <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(setup_low > ema && rsi < rsi_lower)
     {
      if(setup_open > setup_high)
         return false;
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(setup_high + point, _Digits);
      req.sl = NormalizeDouble(req.price - (atr * strategy_atr_stop_mult), _Digits);
      req.tp = 0.0;
      req.reason = "RSI_BB_LONG_BREAK";
      return (req.price > 0.0 && req.sl > 0.0 && req.sl < req.price);
     }

   if(setup_high < ema && rsi > rsi_upper)
     {
      if(setup_open < setup_low)
         return false;
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(setup_low - point, _Digits);
      req.sl = NormalizeDouble(req.price + (atr * strategy_atr_stop_mult), _Digits);
      req.tp = 0.0;
      req.reason = "RSI_BB_SHORT_BREAK";
      return (req.price > 0.0 && req.sl > req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_atr_stop_mult <= 0.0 || strategy_atr_target_mult <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0 || point <= 0.0)
         continue;

      const bool trail_armed = is_buy ? (current_sl >= open_price - point * 0.5)
                                      : (current_sl <= open_price + point * 0.5);
      bool target_touched = trail_armed;
      if(!target_touched)
        {
         const double entry_atr = MathAbs(open_price - current_sl) / strategy_atr_stop_mult;
         if(entry_atr <= 0.0)
            continue;

         const double target_distance = entry_atr * strategy_atr_target_mult;
         target_touched = is_buy ? (market >= open_price + target_distance)
                                 : (market <= open_price - target_distance);
         if(!target_touched)
            continue;
        }

      double trail_low = 0.0;
      double trail_high = 0.0;
      if(!Strategy_StructureExtremes(strategy_trail_lookback, trail_low, trail_high))
         continue;

      double target_sl = is_buy ? MathMax(open_price, trail_low)
                                : MathMin(open_price, trail_high);
      target_sl = NormalizeDouble(target_sl, _Digits);
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "target_touched_be_trail_3bar");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_max_hold_bars <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_open = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false);
      if(bars_since_open >= strategy_max_hold_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10638_et-rsi-bb-break\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
