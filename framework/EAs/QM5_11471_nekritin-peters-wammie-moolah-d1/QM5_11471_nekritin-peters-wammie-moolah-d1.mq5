#property strict
#property version   "5.0"
#property description "QM5_11471 Wammie Moolah D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11471;
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
input int    strategy_zone_lookback_bars      = 50;
input int    strategy_zone_exclude_recent     = 5;
input double strategy_zone_buffer_pips        = 10.0;
input double strategy_min_rally_pips          = 30.0;
input int    strategy_max_pattern_bars        = 20;
input int    strategy_min_touch_gap_bars      = 3;
input double strategy_catalyst_body_ratio     = 0.50;
input double strategy_entry_offset_pips       = 1.0;
input int    strategy_pending_bars            = 3;
input double strategy_max_sl_pips             = 120.0;
input int    strategy_tp_scan_bars            = 60;
input double strategy_spread_cap_pips         = 25.0;

// No Trade Filter: timeframe and spread guard. News is handled by the framework
// and Strategy_NewsFilterHook below.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (StringFind(_Symbol, "JPY") >= 0) ? 0.01 : ((digits == 3 || digits == 5) ? point * 10.0 : point);
   if(point <= 0.0 || pip <= 0.0 || strategy_spread_cap_pips <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / pip > strategy_spread_cap_pips);
  }

// Trade Entry: Wammie long at support and Moolah short at resistance.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_zone_lookback_bars <= 0 ||
      strategy_zone_exclude_recent < 2 ||
      strategy_zone_buffer_pips <= 0.0 ||
      strategy_min_rally_pips <= 0.0 ||
      strategy_max_pattern_bars <= strategy_min_touch_gap_bars ||
      strategy_min_touch_gap_bars < 1 ||
      strategy_catalyst_body_ratio <= 0.0 ||
      strategy_entry_offset_pips <= 0.0 ||
      strategy_pending_bars <= 0 ||
      strategy_max_sl_pips <= 0.0 ||
      strategy_tp_scan_bars < 3)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (StringFind(_Symbol, "JPY") >= 0) ? 0.01 : ((digits == 3 || digits == 5) ? point * 10.0 : point);
   if(point <= 0.0 || pip <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const int bars_needed = strategy_zone_exclude_recent + strategy_zone_lookback_bars + strategy_tp_scan_bars + 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, bars_needed, rates); // perf-allowed: one bounded D1 OHLC snapshot inside the framework new-bar gate for bespoke S/R structure.
   if(copied <= strategy_zone_exclude_recent + strategy_zone_lookback_bars + 2)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double second_open = rates[1].open;
   const double second_high = rates[1].high;
   const double second_low = rates[1].low;
   const double second_close = rates[1].close;
   const double second_range = second_high - second_low;
   const double second_body = MathAbs(second_close - second_open);
   if(second_open <= 0.0 || second_high <= 0.0 || second_low <= 0.0 || second_close <= 0.0 || second_range <= 0.0)
      return false;

   double support_zone = DBL_MAX;
   double resistance_zone = -DBL_MAX;
   const int zone_end = strategy_zone_exclude_recent + strategy_zone_lookback_bars - 1;
   for(int s = strategy_zone_exclude_recent; s <= zone_end && s < copied; ++s)
     {
      support_zone = MathMin(support_zone, rates[s].low);
      resistance_zone = MathMax(resistance_zone, rates[s].high);
     }
   if(support_zone == DBL_MAX || resistance_zone == -DBL_MAX)
      return false;

   const double buffer = strategy_zone_buffer_pips * pip;
   const double min_rally = strategy_min_rally_pips * pip;
   const double entry_offset = strategy_entry_offset_pips * pip;
   const double max_sl = strategy_max_sl_pips * pip;
   const int first_min_shift = strategy_min_touch_gap_bars + 1;
   const int first_max_shift = MathMin(strategy_max_pattern_bars, copied - 2);

   if(second_close > second_open && second_body > strategy_catalyst_body_ratio * second_range &&
      MathAbs(second_low - support_zone) <= buffer)
     {
      for(int first_shift = first_min_shift; first_shift <= first_max_shift; ++first_shift)
        {
         if(MathAbs(rates[first_shift].low - support_zone) > buffer)
            continue;

         double rally_high = -DBL_MAX;
         for(int s = 2; s < first_shift; ++s)
            rally_high = MathMax(rally_high, rates[s].high);
         if(rally_high == -DBL_MAX || rally_high - support_zone < min_rally)
            continue;

         const double entry = QM_TM_NormalizePrice(_Symbol, second_high + entry_offset);
         const double sl = QM_TM_NormalizePrice(_Symbol, MathMin(rates[first_shift].low, second_low) - entry_offset);
         if(entry <= ask || sl <= 0.0 || entry <= sl || entry - sl > max_sl)
            continue;

         double tp = 0.0;
         const int scan_end = MathMin(strategy_tp_scan_bars, copied - 2);
         for(int s = 2; s <= scan_end; ++s)
           {
            const double swing_high = rates[s].high;
            if(swing_high > entry && swing_high > rates[s - 1].high && swing_high > rates[s + 1].high)
              {
               if(tp <= 0.0 || swing_high < tp)
                  tp = swing_high;
              }
           }
         tp = QM_TM_NormalizePrice(_Symbol, tp);
         if(tp <= entry)
            continue;

         req.type = QM_BUY_STOP;
         req.price = entry;
         req.sl = sl;
         req.tp = tp;
         req.reason = "QM5_11471_WAMMIE_BUY_STOP";
         req.expiration_seconds = strategy_pending_bars * PeriodSeconds(PERIOD_D1);
         return (req.expiration_seconds > 0);
        }
     }

   if(second_close < second_open && second_body > strategy_catalyst_body_ratio * second_range &&
      MathAbs(second_high - resistance_zone) <= buffer)
     {
      for(int first_shift = first_min_shift; first_shift <= first_max_shift; ++first_shift)
        {
         if(MathAbs(rates[first_shift].high - resistance_zone) > buffer)
            continue;

         double selloff_low = DBL_MAX;
         for(int s = 2; s < first_shift; ++s)
            selloff_low = MathMin(selloff_low, rates[s].low);
         if(selloff_low == DBL_MAX || resistance_zone - selloff_low < min_rally)
            continue;

         const double entry = QM_TM_NormalizePrice(_Symbol, second_low - entry_offset);
         const double sl = QM_TM_NormalizePrice(_Symbol, MathMax(rates[first_shift].high, second_high) + entry_offset);
         if(entry >= bid || sl <= 0.0 || sl <= entry || sl - entry > max_sl)
            continue;

         double tp = 0.0;
         const int scan_end = MathMin(strategy_tp_scan_bars, copied - 2);
         for(int s = 2; s <= scan_end; ++s)
           {
            const double swing_low = rates[s].low;
            if(swing_low < entry && swing_low < rates[s - 1].low && swing_low < rates[s + 1].low)
              {
               if(tp <= 0.0 || swing_low > tp)
                  tp = swing_low;
              }
           }
         tp = QM_TM_NormalizePrice(_Symbol, tp);
         if(tp <= 0.0 || tp >= entry)
            continue;

         req.type = QM_SELL_STOP;
         req.price = entry;
         req.sl = sl;
         req.tp = tp;
         req.reason = "QM5_11471_MOOLAH_SELL_STOP";
         req.expiration_seconds = strategy_pending_bars * PeriodSeconds(PERIOD_D1);
         return (req.expiration_seconds > 0);
        }
     }

   return false;
  }

// Trade Management: pending stop expiry is handled through ORDER_TIME_SPECIFIED.
void Strategy_ManageOpenPosition()
  {
   if(strategy_pending_bars <= 0)
      return;

   const int expiry_seconds = strategy_pending_bars * PeriodSeconds(PERIOD_D1);
   if(expiry_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "QM5_11471_PENDING_EXPIRED");
     }
  }

// Trade Close: card exits via SL/TP, plus framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no strategy-specific override beyond framework news mode.
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
