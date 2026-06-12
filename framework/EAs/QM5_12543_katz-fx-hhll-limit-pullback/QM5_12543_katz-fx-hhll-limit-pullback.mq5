#property strict
#property version   "5.0"
#property description "QM5_12543 Katz FX HHLL limit pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: QM5_12543_katz-fx-hhll-limit-pullback
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12543;
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
input int    strategy_channel_bars      = 40;
input int    strategy_atr_period        = 50;
input double strategy_stop_atr_mult     = 1.0;
input double strategy_target_atr_mult   = 4.0;
input int    strategy_limit_valid_bars  = 5;
input int    strategy_max_hold_bars     = 10;

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session or spread filter. Framework news and Friday gates apply.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_channel_bars < 2 || strategy_atr_period < 2 ||
      strategy_stop_atr_mult <= 0.0 || strategy_target_atr_mult <= 0.0 ||
      strategy_limit_valid_bars < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         have_position = true;
         position_ticket = ticket;
         position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         break;
        }
     }

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return false;
     }

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 close, called only from the framework QM_IsNewBar-gated entry hook.
   if(close1 <= 0.0)
      return false;

   double highest_high = -DBL_MAX;
   double lowest_low = DBL_MAX;
   for(int shift = 2; shift <= strategy_channel_bars + 1; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded Donchian HHLL structural scan, called only from the framework QM_IsNewBar-gated entry hook.
      const double bar_low = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded Donchian HHLL structural scan, called only from the framework QM_IsNewBar-gated entry hook.
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return false;
      if(bar_high > highest_high)
         highest_high = bar_high;
      if(bar_low < lowest_low)
         lowest_low = bar_low;
     }

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int day_seconds = PeriodSeconds(PERIOD_D1);
   if(day_seconds <= 0)
      day_seconds = 86400;
   req.expiration_seconds = strategy_limit_valid_bars * day_seconds;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > highest_high && highest_high < ask)
     {
      if(have_position)
        {
         if(position_type == POSITION_TYPE_BUY)
            return false;
         if(!QM_TM_ClosePosition(position_ticket, QM_EXIT_OPPOSITE_SIGNAL))
            return false;
        }
      req.type = QM_BUY_LIMIT;
      req.price = highest_high;
      req.sl = req.price - (strategy_stop_atr_mult * atr);
      req.tp = req.price + (strategy_target_atr_mult * atr);
      req.reason = "KATZ_HHLL_LONG_LIMIT";
      return true;
     }

   if(close1 < lowest_low && lowest_low > bid)
     {
      if(have_position)
        {
         if(position_type == POSITION_TYPE_SELL)
            return false;
         if(!QM_TM_ClosePosition(position_ticket, QM_EXIT_OPPOSITE_SIGNAL))
            return false;
        }
      req.type = QM_SELL_LIMIT;
      req.price = lowest_low;
      req.sl = req.price + (strategy_stop_atr_mult * atr);
      req.tp = req.price - (strategy_target_atr_mult * atr);
      req.reason = "KATZ_HHLL_SHORT_LIMIT";
      return true;
     }

   return false;
  }

// Called every tick. The card has no trailing, partial, or break-even rule.
void Strategy_ManageOpenPosition()
  {
   if(strategy_limit_valid_bars < 1)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   int day_seconds = PeriodSeconds(PERIOD_D1);
   if(day_seconds <= 0)
      day_seconds = 86400;
   const int max_age_seconds = strategy_limit_valid_bars * day_seconds;
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
      if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age_seconds)
         QM_TM_RemovePendingOrder(ticket, "KATZ_LIMIT_EXPIRED");
     }
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   bool have_position = false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   int day_seconds = PeriodSeconds(PERIOD_D1);
   if(day_seconds <= 0)
      day_seconds = 86400;
   if(open_time > 0 && TimeCurrent() - open_time >= strategy_max_hold_bars * day_seconds)
      return true;

   // Opposite breakout reversal is evaluated inside Strategy_EntrySignal(),
   // which the framework calls only after QM_IsNewBar().
   return false;
  }

// P8 News Impact hook. Return false to defer to the central framework filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12543\",\"ea\":\"QM5_12543_katz_fx_hhll_limit_pullback\"}");
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
