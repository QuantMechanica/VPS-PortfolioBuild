#property strict
#property version   "5.0"
#property description "QM5_12545 Katz SMA Support/Resistance Stop Entry D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12545 — katz-sma-support-resistance-stop-d1
//
// Source: Katz & McCormick (2000), The Encyclopedia of Trading Strategies,
// McGraw-Hill, Ch.6 (Moving Average Models), pp. 139-146.
//
// Algorithm: D1 SMA support/resistance touch with slope confirmation. A rising
// SMA plus close-cross down through the average stages a buy stop one tick above
// the touch bar high. A falling SMA plus mirror cross stages a sell stop one tick
// below the touch bar low. SES exit: 1x ATR(50) stop, 4x ATR(50) target, 10-bar
// time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12545;
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
input int    strategy_sma_period          = 25;  // Katz default P=25; P3 sweep 15/25/35.
input int    strategy_atr_period          = 50;  // Katz SES ATR period.
input double strategy_stop_atr_mult       = 1.0; // SL = entry +/- 1.0 x ATR(50).
input double strategy_target_atr_mult     = 4.0; // TP = entry +/- 4.0 x ATR(50).
input int    strategy_pending_valid_bars  = 3;   // Stop order valid for 3 D1 bars.
input int    strategy_max_hold_bars       = 10;  // Time exit after 10 D1 bars.

int  g_cross_lock_direction = 0;
bool g_had_filled_position = false;

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Card declares no additional time or spread filter. Framework news and
   // Friday-close gates remain active.
   return false;
  }

int Strategy_SlopeDirection()
  {
   if(strategy_sma_period < 2)
      return 0;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2, PRICE_CLOSE);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return 0;
   if(sma_now > sma_prev)
      return 1;
   if(sma_now < sma_prev)
      return -1;
   return 0;
  }

bool Strategy_HasWorkingStopOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
         return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_TickSize()
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size > 0.0)
      return tick_size;
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

int Strategy_D1Seconds()
  {
   int seconds = PeriodSeconds(PERIOD_D1);
   if(seconds <= 0)
      seconds = 86400;
   return seconds;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_period < 2 || strategy_atr_period < 2 ||
      strategy_stop_atr_mult <= 0.0 || strategy_target_atr_mult <= 0.0 ||
      strategy_pending_valid_bars < 1)
      return false;

   const int slope_dir = Strategy_SlopeDirection();
   if(slope_dir == 0)
      return false;

   if(g_cross_lock_direction != 0 && slope_dir != g_cross_lock_direction &&
      !Strategy_HasWorkingStopOrder() && !Strategy_HasOpenPosition())
      g_cross_lock_direction = 0;

   if(g_cross_lock_direction == slope_dir)
      return false;

   if(Strategy_HasWorkingStopOrder() || Strategy_HasOpenPosition())
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2, PRICE_CLOSE);
   const double close_now = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double close_prev = QM_SMA(_Symbol, PERIOD_D1, 1, 2, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double tick = Strategy_TickSize();
   if(sma_now <= 0.0 || sma_prev <= 0.0 || close_now <= 0.0 || close_prev <= 0.0 ||
      atr <= 0.0 || tick <= 0.0)
      return false;

   const double high_now = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: signal-bar stop level, called only from QM_IsNewBar-gated entry hook.
   const double low_now = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: signal-bar stop level, called only from QM_IsNewBar-gated entry hook.
   if(high_now <= 0.0 || low_now <= 0.0)
      return false;

   const bool long_touch = (slope_dir > 0 && close_prev >= sma_prev && close_now <= sma_now);
   const bool short_touch = (slope_dir < 0 && close_prev <= sma_prev && close_now >= sma_now);
   const int expiry_seconds = strategy_pending_valid_bars * Strategy_D1Seconds();

   if(long_touch)
     {
      const double entry = high_now + tick;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = entry - (strategy_stop_atr_mult * atr);
      req.tp = entry + (strategy_target_atr_mult * atr);
      req.reason = "KATZ_SMA_SR_LONG_STOP";
      req.expiration_seconds = expiry_seconds;
      g_cross_lock_direction = 1;
      return true;
     }

   if(short_touch)
     {
      const double entry = low_now - tick;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = entry + (strategy_stop_atr_mult * atr);
      req.tp = entry - (strategy_target_atr_mult * atr);
      req.reason = "KATZ_SMA_SR_SHORT_STOP";
      req.expiration_seconds = expiry_seconds;
      g_cross_lock_direction = -1;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const bool has_position = Strategy_HasOpenPosition();
   if(has_position)
      g_had_filled_position = true;
   else if(g_had_filled_position && !Strategy_HasWorkingStopOrder())
     {
      g_cross_lock_direction = 0;
      g_had_filled_position = false;
     }

   if(strategy_pending_valid_bars < 1)
      return;

   const int max_age_seconds = strategy_pending_valid_bars * Strategy_D1Seconds();
   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age_seconds)
         QM_TM_RemovePendingOrder(ticket, "KATZ_SMA_SR_STOP_EXPIRED");
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const long hold_seconds = (long)strategy_max_hold_bars * (long)Strategy_D1Seconds();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (long)(now - open_time) >= hold_seconds)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0) return false; // suppress unused-param warning
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12545\",\"ea\":\"QM5_12545_katz_sma_support_resistance_stop_d1\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
