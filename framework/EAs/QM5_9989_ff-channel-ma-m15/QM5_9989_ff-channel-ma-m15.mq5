#property strict
#property version   "5.0"
#property description "QM5_9989 ForexFactory Channel MA Short-Term System"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_9989_ff-channel-ma-m15
// Strategy Card: ForexFactory Channel MA Short-Term System, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9989;
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
input int    strategy_channel_ema_period       = 55;
input int    strategy_signal_ema_period        = 33;
input int    strategy_distance_threshold_pips  = 40;
input int    strategy_stop_pips                = 45;
input int    strategy_take_profit_pips         = 40;
input int    strategy_breakeven_trigger_pips   = 22;
input int    strategy_pending_expiry_bars      = 16;
input double strategy_max_spread_pips          = 2.5;
input double strategy_max_spread_stop_ratio    = 0.08;

double Strategy_PipsToPriceDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_CurrentSpreadDistance()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

double Strategy_MinStopDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double broker_min = (stops_level > 0) ? ((double)stops_level * point) : 0.0;
   return broker_min + Strategy_CurrentSpreadDistance();
  }

bool Strategy_SpreadAllowedForStop(const double stop_distance)
  {
   const double spread = Strategy_CurrentSpreadDistance();
   const double max_spread = Strategy_PipsToPriceDistance(strategy_max_spread_pips);
   if(spread <= 0.0 || max_spread <= 0.0)
      return false;
   if(spread > max_spread)
      return false;
   if(stop_distance > 0.0 && spread > stop_distance * strategy_max_spread_stop_ratio)
      return false;
   return true;
  }

int Strategy_SignalDirection()
  {
   if(strategy_channel_ema_period <= 0 || strategy_signal_ema_period <= 0)
      return 0;

   const double sig_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_signal_ema_period, 1, PRICE_CLOSE);
   const double sig_prev = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_signal_ema_period, 2, PRICE_CLOSE);
   const double upper_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_HIGH);
   const double upper_prev = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 2, PRICE_HIGH);
   const double lower_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_LOW);
   const double lower_prev = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 2, PRICE_LOW);
   if(sig_now <= 0.0 || sig_prev <= 0.0 || upper_now <= 0.0 || upper_prev <= 0.0 ||
      lower_now <= 0.0 || lower_prev <= 0.0)
      return 0;

   if(sig_prev <= upper_prev && sig_now > upper_now)
      return 1;
   if(sig_prev >= lower_prev && sig_now < lower_now)
      return -1;
   return 0;
  }

int Strategy_ActiveSide()
  {
   const double sig_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_signal_ema_period, 1, PRICE_CLOSE);
   const double upper_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_HIGH);
   const double lower_now = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_LOW);
   if(sig_now <= 0.0 || upper_now <= 0.0 || lower_now <= 0.0)
      return 0;
   if(sig_now > upper_now)
      return 1;
   if(sig_now < lower_now)
      return -1;
   return 0;
  }

bool Strategy_GetOurPositionSide(int &side)
  {
   side = 0;
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      side = (type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
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

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void Strategy_CancelInactivePendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int active_side = Strategy_ActiveSide();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const int order_side = (type == ORDER_TYPE_BUY_LIMIT) ? 1 : ((type == ORDER_TYPE_SELL_LIMIT) ? -1 : 0);
      if(order_side != 0 && order_side != active_side)
         QM_TM_RemovePendingOrder(ticket, "channel_side_inactive_or_opposite");
     }
  }

bool Strategy_BuildProtection(const QM_OrderType type,
                              const double entry_price,
                              double &out_sl,
                              double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;
   if(entry_price <= 0.0)
      return false;

   const double upper = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_HIGH);
   const double lower = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_LOW);
   if(upper <= 0.0 || lower <= 0.0)
      return false;

   const double fixed_sl = QM_StopFixedPips(_Symbol, type, entry_price, strategy_stop_pips);
   const double fixed_tp = QM_TakeFixedPips(_Symbol, type, entry_price, strategy_take_profit_pips);
   const double min_dist = Strategy_MinStopDistance();
   if(fixed_sl <= 0.0 || fixed_tp <= 0.0 || min_dist <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(type))
     {
      const double channel_sl = lower - min_dist;
      out_sl = MathMin(fixed_sl, channel_sl);
      if(entry_price - out_sl < min_dist)
         out_sl = entry_price - min_dist;
     }
   else
     {
      const double channel_sl = upper + min_dist;
      out_sl = MathMax(fixed_sl, channel_sl);
      if(out_sl - entry_price < min_dist)
         out_sl = entry_price + min_dist;
     }

   out_sl = QM_StopRulesNormalizePrice(_Symbol, out_sl);
   out_tp = fixed_tp;
   return (out_sl > 0.0 && out_tp > 0.0 && Strategy_SpreadAllowedForStop(MathAbs(entry_price - out_sl)));
  }

// Return TRUE to BLOCK trading this tick. This is the card's spread filter.
bool Strategy_NoTradeFilter()
  {
   return !Strategy_SpreadAllowedForStop(Strategy_PipsToPriceDistance(strategy_stop_pips));
  }

// Called once per closed M15 bar by the framework gate.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CancelInactivePendingOrders();
   if(Strategy_HasOurPendingOrder())
      return false;

   const int direction = Strategy_SignalDirection();
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double signal_price = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_signal_ema_period, 1, PRICE_CLOSE);
   const double upper = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_HIGH);
   const double lower = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_channel_ema_period, 1, PRICE_LOW);
   const double threshold = Strategy_PipsToPriceDistance(strategy_distance_threshold_pips);
   if(signal_price <= 0.0 || upper <= 0.0 || lower <= 0.0 || threshold <= 0.0)
      return false;

   double entry_price = 0.0;
   QM_OrderType order_type = QM_BUY;
   if(direction > 0)
     {
      entry_price = ask;
      order_type = (MathAbs(entry_price - lower) <= threshold) ? QM_BUY : QM_BUY_LIMIT;
      if(order_type == QM_BUY_LIMIT)
         entry_price = signal_price;
     }
   else
     {
      entry_price = bid;
      order_type = (MathAbs(upper - entry_price) <= threshold) ? QM_SELL : QM_SELL_LIMIT;
      if(order_type == QM_SELL_LIMIT)
         entry_price = signal_price;
     }

   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!Strategy_BuildProtection(order_type, entry_price, sl, tp))
      return false;

   req.type = order_type;
   req.price = (order_type == QM_BUY || order_type == QM_SELL) ? 0.0 : entry_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = (direction > 0) ? "ff_channel_ma_long" : "ff_channel_ma_short";
   if(order_type == QM_BUY_LIMIT || order_type == QM_SELL_LIMIT)
      req.expiration_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_M15);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   Strategy_CancelInactivePendingOrders();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_MoveToBreakEven(ticket, strategy_breakeven_trigger_pips, 0);
     }
  }

bool Strategy_ExitSignal()
  {
   int position_side = 0;
   if(!Strategy_GetOurPositionSide(position_side))
      return false;

   const int signal_direction = Strategy_SignalDirection();
   return (position_side > 0 && signal_direction < 0) ||
          (position_side < 0 && signal_direction > 0);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9989_ff-channel-ma-m15\"}");
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
