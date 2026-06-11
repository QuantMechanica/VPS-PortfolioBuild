#property strict
#property version   "5.0"
#property description "QM5_9959 ForexFactory Daily Wick High-Low D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9959;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_D1;
input int    strategy_atr_period                  = 14;
input double strategy_fx_entry_buffer_pips        = 5.0;
input double strategy_fx_sl_pips                  = 30.0;
input double strategy_fx_tp_pips                  = 100.0;
input double strategy_nonfx_entry_atr_mult        = 0.05;
input double strategy_sl_atr_mult                 = 0.8;
input double strategy_min_range_atr_mult          = 0.5;
input double strategy_rr_multiple                 = 2.0;
input double strategy_max_spread_stop_frac        = 0.10;
input int    strategy_pending_days                = 1;

bool Strategy_NoTradeFilter()
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
         return false;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return true;

   string base = _Symbol;
   const int dot_pos = StringFind(base, ".");
   if(dot_pos >= 0)
      base = StringSubstr(base, 0, dot_pos);
   const bool is_fx = (base == "EURUSD" || base == "GBPUSD" || base == "USDJPY");

   double stop_distance = strategy_sl_atr_mult * atr;
   if(is_fx)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
      const double fixed_stop = strategy_fx_sl_pips * pip;
      if(pip <= 0.0 || fixed_stop <= 0.0)
         return true;
      if(fixed_stop >= 0.4 * atr && fixed_stop <= 1.2 * atr)
         stop_distance = fixed_stop;
     }

   return (strategy_max_spread_stop_frac > 0.0 &&
           (ask - bid) > strategy_max_spread_stop_frac * stop_distance);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_pending_days) * 86400;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_timeframe != PERIOD_D1)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "new_d1_bar_reset");
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(strategy_atr_period <= 0 ||
      strategy_fx_entry_buffer_pips <= 0.0 ||
      strategy_nonfx_entry_atr_mult <= 0.0 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_rr_multiple <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double prev_open = iOpen(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed D1 OHLC read for wick geometry behind framework new-bar gate.
   const double prev_high = iHigh(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed D1 OHLC read for wick geometry behind framework new-bar gate.
   const double prev_low  = iLow(_Symbol, strategy_timeframe, 1);  // perf-allowed: single closed D1 OHLC read for wick geometry behind framework new-bar gate.
   if(prev_open <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low)
      return false;

   if((prev_high - prev_low) < strategy_min_range_atr_mult * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || point <= 0.0)
      return false;

   string base = _Symbol;
   const int dot_pos = StringFind(base, ".");
   if(dot_pos >= 0)
      base = StringSubstr(base, 0, dot_pos);
   const bool is_fx = (base == "EURUSD" || base == "GBPUSD" || base == "USDJPY");

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   double stop_distance = strategy_sl_atr_mult * atr;
   if(is_fx)
     {
      const double fixed_stop = strategy_fx_sl_pips * pip;
      if(fixed_stop <= 0.0)
         return false;
      if(fixed_stop >= 0.4 * atr && fixed_stop <= 1.2 * atr)
         stop_distance = fixed_stop;
     }
   if(stop_distance <= 0.0)
      return false;

   if(strategy_max_spread_stop_frac > 0.0 &&
      (ask - bid) > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const double buffer = is_fx ? strategy_fx_entry_buffer_pips * pip
                               : strategy_nonfx_entry_atr_mult * atr;
   if(buffer <= 0.0)
      return false;

   const double rr_tp_distance = strategy_rr_multiple * stop_distance;
   double tp_distance = rr_tp_distance;
   if(is_fx && strategy_fx_tp_pips > 0.0)
      tp_distance = MathMin(strategy_fx_tp_pips * pip, rr_tp_distance);
   if(tp_distance <= 0.0)
      return false;

   const double min_dist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double wick_buy = prev_open - prev_low;
   const double wick_sell = prev_high - prev_open;

   if(wick_buy > wick_sell)
     {
      const double entry = prev_high + buffer;
      if(entry <= ask + min_dist || stop_distance <= min_dist || tp_distance <= min_dist)
         return false;
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry - stop_distance, _Digits);
      req.tp = NormalizeDouble(entry + tp_distance, _Digits);
      req.reason = "FF_DAILY_WICK_BUY_STOP";
      return (req.sl < req.price && req.tp > req.price);
     }

   if(wick_sell > wick_buy)
     {
      const double entry = prev_low - buffer;
      if(entry >= bid - min_dist || stop_distance <= min_dist || tp_distance <= min_dist)
         return false;
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry + stop_distance, _Digits);
      req.tp = NormalizeDouble(entry - tp_distance, _Digits);
      req.reason = "FF_DAILY_WICK_SELL_STOP";
      return (req.sl > req.price && req.tp < req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_position = true;
         break;
        }
     }
   if(!has_position)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "position_open_cancel_stale_pending");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime current_d1_open = iTime(_Symbol, strategy_timeframe, 0); // perf-allowed: current D1 open read for card time-stop check only.
   if(current_d1_open <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && current_d1_open > opened_at)
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
