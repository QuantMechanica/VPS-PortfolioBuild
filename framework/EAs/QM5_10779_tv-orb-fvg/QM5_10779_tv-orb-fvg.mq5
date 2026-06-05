#property strict
#property version   "5.0"
#property description "QM5_10779 TradingView ORB with FVG filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10779;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_capture_start_hhmm  = 1630;  // 09:30 New York ported to DarwinexZero broker time.
input int    strategy_capture_minutes     = 5;
input int    strategy_trade_start_hhmm    = 1636;  // Source default 09:36 New York + 7h broker offset.
input int    strategy_trade_end_hhmm      = 1800;  // Source default 11:00 New York + 7h broker offset.
input bool   strategy_fvg_filter_enabled  = true;
input bool   strategy_fvg_edge_entry      = true;
input int    strategy_ema_period          = 0;      // 0=off, P3 ablation values 50/100.
input int    strategy_stop_mode           = 0;      // 0=breakout candle, 1=opposite OR side, 2=ATR.
input int    strategy_atr_period          = 14;
input double strategy_atr_buffer_mult     = 0.0;
input double strategy_atr_sl_mult         = 1.0;
input double strategy_rr_target           = 2.0;
input int    strategy_max_spread_points   = 0;      // 0 disables per-card; setfiles may constrain.

int BrokerHHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime BrokerDateAtHHMM(const datetime base_time, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(base_time, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsInsideTradingWindow(const datetime broker_time)
  {
   const int hhmm = BrokerHHMM(broker_time);
   return (hhmm >= strategy_trade_start_hhmm && hhmm < strategy_trade_end_hhmm);
  }

bool IsAtOrAfterTradingEnd(const datetime broker_time)
  {
   return (BrokerHHMM(broker_time) >= strategy_trade_end_hhmm);
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool HasOurPosition()
  {
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
      return true;
     }
   return false;
  }

bool IsOurPendingOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT ||
           order_type == ORDER_TYPE_SELL_LIMIT ||
           order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP);
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void RemoveOurPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool OpeningRange(double &range_high, double &range_low)
  {
   range_high = 0.0;
   range_low = 0.0;
   if(strategy_capture_minutes <= 0)
      return false;

   const datetime now = TimeCurrent();
   const datetime capture_start = BrokerDateAtHHMM(now, strategy_capture_start_hhmm);
   const datetime capture_end = capture_start + strategy_capture_minutes * 60;
   if(now < capture_end)
      return false;

   // perf-allowed: bespoke opening-range geometry, called only from the framework closed-bar gate.
   const int shift_start = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, capture_start, false); // perf-allowed
   const int shift_end = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, capture_end - 1, false); // perf-allowed
   if(shift_start < 1 || shift_end < 1)
      return false;

   const int first = MathMin(shift_start, shift_end);
   const int last = MathMax(shift_start, shift_end);
   if((last - first) > 60)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int shift = first; shift <= last; ++shift)
     {
      // perf-allowed: bounded OR scan over the configured capture window.
      const double h = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
      const double l = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
      if(h <= 0.0 || l <= 0.0)
         return false;
      hi = MathMax(hi, h);
      lo = MathMin(lo, l);
     }

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;
   range_high = hi;
   range_low = lo;
   return true;
  }

bool BullishFVG(double &edge_price)
  {
   edge_price = 0.0;
   // perf-allowed: fixed 3-candle fair-value-gap geometry on closed bars.
   const double low_1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
   const double high_3 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed
   if(low_1 <= 0.0 || high_3 <= 0.0)
      return false;
   if(low_1 <= high_3)
      return false;
   edge_price = low_1;
   return true;
  }

bool BearishFVG(double &edge_price)
  {
   edge_price = 0.0;
   // perf-allowed: fixed 3-candle fair-value-gap geometry on closed bars.
   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
   const double low_3 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed
   if(high_1 <= 0.0 || low_3 <= 0.0)
      return false;
   if(high_1 >= low_3)
      return false;
   edge_price = high_1;
   return true;
  }

bool EmaAllows(const QM_OrderType side, const double close_price)
  {
   if(strategy_ema_period <= 0)
      return true;
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   if(ema <= 0.0 || close_price <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side))
      return close_price > ema;
   return close_price < ema;
  }

double StopPrice(const QM_OrderType side,
                 const double entry_price,
                 const double range_high,
                 const double range_low)
  {
   if(entry_price <= 0.0)
      return 0.0;

   const double atr = (strategy_atr_period > 0) ? QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) : 0.0;
   const double buffer = (atr > 0.0 && strategy_atr_buffer_mult > 0.0) ? atr * strategy_atr_buffer_mult : 0.0;

   if(strategy_stop_mode == 2)
      return QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);

   if(strategy_stop_mode == 1)
     {
      if(QM_OrderTypeIsBuy(side))
         return NormalizeStrategyPrice(range_low - buffer);
      return NormalizeStrategyPrice(range_high + buffer);
     }

   // perf-allowed: breakout candle stop from the last closed candle.
   if(QM_OrderTypeIsBuy(side))
      return NormalizeStrategyPrice(iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1) - buffer); // perf-allowed
   return NormalizeStrategyPrice(iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1) + buffer); // perf-allowed
  }

int SecondsUntilTradingEnd(const datetime broker_time)
  {
   const datetime end_time = BrokerDateAtHHMM(broker_time, strategy_trade_end_hhmm);
   const int seconds = (int)(end_time - broker_time);
   return (seconds > 0) ? seconds : 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
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

   const datetime broker_now = TimeCurrent();
   if(!IsInsideTradingWindow(broker_now))
      return false;
   if(HasOurPosition() || HasOurPendingOrder())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!OpeningRange(range_high, range_low))
      return false;

   // perf-allowed: closed breakout candle values.
   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
   if(close_1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double fvg_edge = 0.0;
   if(close_1 > range_high)
     {
      if(strategy_fvg_filter_enabled && !BullishFVG(fvg_edge))
         return false;
      if(!EmaAllows(QM_BUY, close_1))
         return false;

      const double entry_price = strategy_fvg_edge_entry ? fvg_edge : ask;
      if(entry_price <= 0.0)
         return false;
      const double sl = StopPrice(QM_BUY, entry_price, range_high, range_low);
      if(sl <= 0.0 || sl >= entry_price)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry_price, sl, strategy_rr_target);
      if(tp <= 0.0)
         return false;

      req.type = strategy_fvg_edge_entry ? QM_BUY_LIMIT : QM_BUY;
      req.price = strategy_fvg_edge_entry ? NormalizeStrategyPrice(entry_price) : 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ORB_FVG_LONG";
      req.expiration_seconds = strategy_fvg_edge_entry ? SecondsUntilTradingEnd(broker_now) : 0;
      return (!strategy_fvg_edge_entry || req.expiration_seconds > 0);
     }

   if(close_1 < range_low)
     {
      if(strategy_fvg_filter_enabled && !BearishFVG(fvg_edge))
         return false;
      if(!EmaAllows(QM_SELL, close_1))
         return false;

      const double entry_price = strategy_fvg_edge_entry ? fvg_edge : bid;
      if(entry_price <= 0.0)
         return false;
      const double sl = StopPrice(QM_SELL, entry_price, range_high, range_low);
      if(sl <= 0.0 || sl <= entry_price)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry_price, sl, strategy_rr_target);
      if(tp <= 0.0)
         return false;

      req.type = strategy_fvg_edge_entry ? QM_SELL_LIMIT : QM_SELL;
      req.price = strategy_fvg_edge_entry ? NormalizeStrategyPrice(entry_price) : 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ORB_FVG_SHORT";
      req.expiration_seconds = strategy_fvg_edge_entry ? SecondsUntilTradingEnd(broker_now) : 0;
      return (!strategy_fvg_edge_entry || req.expiration_seconds > 0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(IsAtOrAfterTradingEnd(TimeCurrent()))
      RemoveOurPendingOrders("orb_window_end");
  }

bool Strategy_ExitSignal()
  {
   return (HasOurPosition() && IsAtOrAfterTradingEnd(TimeCurrent()));
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
