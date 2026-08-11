#property strict
#property version   "5.0"
#property description "QM5_20090 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20090
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20090;
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
input int    strategy_session_start_hhmm       = 0000;
input int    strategy_session_end_hhmm         = 2359;
input int    strategy_atr_period               = 14;
input double strategy_bar_tr_atr_max           = 0.60;
input double strategy_envelope_atr_buffer      = 0.10;
input double strategy_d1_box_floor_atr         = 0.15;
input double strategy_spread_box_max           = 0.25;
input double strategy_buffer_atr_mult          = 0.05;
input int    strategy_max_signals_per_session  = 3;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int start_hour = strategy_session_start_hhmm / 100;
   const int start_min = strategy_session_start_hhmm % 100;
   const int end_hour = strategy_session_end_hhmm / 100;
   const int end_min = strategy_session_end_hhmm % 100;
   if(start_hour < 0 || start_hour > 23 || start_min < 0 || start_min > 59 ||
      end_hour < 0 || end_hour > 23 || end_min < 0 || end_min > 59)
      return false;

   const int session_start_minute = start_hour * 60 + start_min;
   const int session_end_minute = end_hour * 60 + end_min;
   if(session_start_minute >= session_end_minute || strategy_atr_period < 2 ||
      strategy_bar_tr_atr_max <= 0.0 || strategy_envelope_atr_buffer < 0.0 ||
      strategy_d1_box_floor_atr <= 0.0 || strategy_spread_box_max <= 0.0 ||
      strategy_max_signals_per_session < 1)
      return false;

   // Read M5 closed bars (shift 1 to 5)
   MqlRates bars[5];
   for(int i = 0; i < 5; ++i)
   {
      if(!QM_ReadBar(_Symbol, PERIOD_M5, i + 1, bars[i]))
         return false;
   }

   MqlDateTime bar_dt;
   TimeToStruct(bars[0].time, bar_dt);
   const int bar_minute = bar_dt.hour * 60 + bar_dt.min;
   if(bar_minute < session_start_minute || bar_minute >= session_end_minute)
      return false;

   const int session_key = bar_dt.year * 10000 + bar_dt.mon * 100 + bar_dt.day;
   static int cached_session_key = 0;
   static int signals_this_session = 0;

   if(cached_session_key != session_key)
   {
      cached_session_key = session_key;
      signals_this_session = 0;
   }

   // All four TTR bars must be part of the same configured cash session
   for(int i = 0; i < 4; ++i)
   {
      MqlDateTime member_dt;
      TimeToStruct(bars[i].time, member_dt);
      const int member_key = member_dt.year * 10000 + member_dt.mon * 100 + member_dt.day;
      const int member_minute = member_dt.hour * 60 + member_dt.min;
      if(member_key != session_key || member_minute < session_start_minute ||
         member_minute >= session_end_minute)
         return false;
   }

   // Do not scan/place new orders if we have open position or pending orders
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return false;
   }
   if(signals_this_session >= strategy_max_signals_per_session)
      return false;

   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_m5 <= 0.0 || atr_d1 <= 0.0)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int i = 0; i < 4; ++i)
   {
      if(bars[i].high <= 0.0 || bars[i].low <= 0.0 || bars[i].high < bars[i].low ||
         bars[i + 1].close <= 0.0)
         return false;
      const double true_range = MathMax(bars[i].high - bars[i].low,
                                        MathMax(MathAbs(bars[i].high - bars[i + 1].close),
                                                MathAbs(bars[i].low - bars[i + 1].close)));
      if(true_range > strategy_bar_tr_atr_max * atr_m5)
         return false;
      box_high = MathMax(box_high, bars[i].high);
      box_low = MathMin(box_low, bars[i].low);
   }

   // Non-expanding check: box range may extend no farther than envelope_buffer from oldest box member
   const double envelope_buffer = strategy_envelope_atr_buffer * atr_m5;
   if(box_high > bars[3].high + envelope_buffer ||
      box_low < bars[3].low - envelope_buffer)
      return false;

   const double box_range = box_high - box_low;
   if(box_range <= 0.0 || box_range < strategy_d1_box_floor_atr * atr_d1)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
      return false;
   if(tick.ask > tick.bid &&
      (tick.ask - tick.bid) > strategy_spread_box_max * box_range)
      return false;

   // Expiration of orders at session end
   MqlDateTime end_dt = bar_dt;
   end_dt.hour = end_hour;
   end_dt.min = end_min;
   end_dt.sec = 0;
   const datetime session_end = StructToTime(end_dt);
   const datetime broker_now = TimeCurrent();
   if(session_end <= broker_now)
      return false;
   const int expiry_seconds = (int)(session_end - broker_now);

   // Calculate stop/TP targets
   const double buffer = strategy_buffer_atr_mult * atr_m5;
   const double buy_price = QM_StopRulesNormalizePrice(_Symbol, box_high + buffer);
   const double buy_sl = QM_StopRulesNormalizePrice(_Symbol, box_low - buffer);
   const double buy_tp = QM_StopRulesNormalizePrice(_Symbol, buy_price + box_range);

   const double sell_price = QM_StopRulesNormalizePrice(_Symbol, box_low - buffer);
   const double sell_sl = QM_StopRulesNormalizePrice(_Symbol, box_high + buffer);
   const double sell_tp = QM_StopRulesNormalizePrice(_Symbol, sell_price - box_range);

   if(buy_price <= tick.ask || buy_sl <= 0.0 || buy_sl >= buy_price || buy_tp <= buy_price ||
      sell_price <= 0.0 || sell_price >= tick.bid || sell_sl <= sell_price || sell_tp <= 0.0 || sell_tp >= sell_price)
      return false;

   // Build Sell Stop Request
   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = sell_tp;
   req.reason = "PRICEBOB_TTR_BREAKOUT_SHORT";
   req.expiration_seconds = expiry_seconds;

   // Build Buy Stop Request
   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = buy_tp;
   buy_req.reason = "PRICEBOB_TTR_BREAKOUT_LONG";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiry_seconds;

   // Open Buy Stop manually
   ulong buy_ticket = 0;
   if(QM_TM_OpenPosition(buy_req, buy_ticket))
   {
      signals_this_session++;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_minute = now_dt.hour * 60 + now_dt.min;
   const int start_minute = (strategy_session_start_hhmm / 100) * 60 +
                            (strategy_session_start_hhmm % 100);
   const int end_minute = (strategy_session_end_hhmm / 100) * 60 +
                          (strategy_session_end_hhmm % 100);

   bool outside_session = (now_minute < start_minute || now_minute >= end_minute);
   bool has_pos = QM_EntryHasOpenPosition(magic, _Symbol);

   if(has_pos || outside_session)
   {
      // Cancel pending stop orders (OCO or end of session)
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
            QM_TM_RemovePendingOrder(ticket, has_pos ? "PRICEBOB_OCO_CANCEL" : "PRICEBOB_SESSION_END");
      }
   }
}

bool Strategy_ExitSignal()
{
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_minute = now_dt.hour * 60 + now_dt.min;
   const int start_minute = (strategy_session_start_hhmm / 100) * 60 +
                            (strategy_session_start_hhmm % 100);
   const int end_minute = (strategy_session_end_hhmm / 100) * 60 +
                          (strategy_session_end_hhmm % 100);
   return (now_minute < start_minute || now_minute >= end_minute);
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
