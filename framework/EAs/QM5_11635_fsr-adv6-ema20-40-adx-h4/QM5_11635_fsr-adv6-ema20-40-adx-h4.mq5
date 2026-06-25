#property strict
#property version   "5.0"
#property description "QM5_11635 fsr-adv6-ema20-40-adx-h4 — FSR Advanced System #6 EMA(20/40) pullback + ADX trend (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11635 fsr-adv6-ema20-40-adx-h4
// -----------------------------------------------------------------------------
// Source: forex-strategies-revealed.com, "Advanced System #6 (EMA Bounce)",
//   anonymous community contribution (source_id 5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d).
// Card: artifacts/cards_approved/QM5_11635_fsr-adv6-ema20-40-adx-h4.md (g0_status APPROVED).
//
// Mechanics (H4 default; framework calls entry once per new bar):
//   Trend STATE : ADX(14) > adx_threshold and current price on the trade side of
//                 EMA(40). LONG = price > EMA40; SHORT = price < EMA40.
//   Entry       : place a pending limit order at EMA(20): BUY_LIMIT in an uptrend,
//                 SELL_LIMIT in a downtrend. Pending orders expire after one H4
//                 bar by default so the next bar can refresh the EMA20 level.
//   Stop        : EMA(40) at signal time +/- a buffer, with a minimum stop-distance
//                 floor of 20 pips by default.
//   Take profit : none fixed; structural EMA(40)-based stop + ADX exit only.
//   Exit        : ADX(14) < adx_exit_threshold (trend weakens) -> close manually.
//   Spread guard : block only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread).
//
// Only the five Strategy_* hooks and the Strategy inputs are EA-specific;
// everything else is framework wiring.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11635;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period   = 20;     // pullback EMA (fast); entry reference
input int    strategy_ema_slow_period   = 40;     // trend EMA (slow); SL boundary
input int    strategy_adx_period        = 14;     // ADX period
input double strategy_adx_threshold     = 30.0;   // trend STATE: ADX must exceed this to enter
input double strategy_adx_exit_threshold = 30.0;  // exit: close when ADX falls below this
input int    strategy_sl_buffer_pips    = 10;     // buffer beyond EMA(40) for the stop
input int    strategy_sl_min_floor_pips = 20;     // minimum stop distance (pips)
input int    strategy_pending_expiration_hours = 4; // H4 default: refresh limit after one bar
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap = EMA(40)-based stop floor.
   double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_min_floor_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: place one pending limit at EMA(20) inside an ADX-confirmed trend.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return false;
     }

   // --- Trend STATE: ADX above threshold ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(adx <= strategy_adx_threshold)
      return false;

   // --- EMA levels at signal time ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 0);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 0);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool uptrend   = (ask > ema_slow);
   const bool downtrend = (bid < ema_slow);
   if(!uptrend && !downtrend)
      return false;

   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double sl_floor  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_floor_pips);
   if(sl_buffer <= 0.0 || sl_floor <= 0.0)
      return false;

   if(uptrend)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_fast);
      if(entry <= 0.0 || entry >= ask)
         return false;

      double sl = ema_slow - sl_buffer;
      if(entry - sl < sl_floor)
         sl = entry - sl_floor;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY_LIMIT;
      req.price  = entry;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "fsr_adv6_ema20_limit_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = ((strategy_pending_expiration_hours > 1) ? strategy_pending_expiration_hours : 1) * 3600;
      return true;
     }
   else // downtrend
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_fast);
      if(entry <= 0.0 || entry <= bid)
         return false;

      double sl = ema_slow + sl_buffer;
      if(sl - entry < sl_floor)
         sl = entry + sl_floor;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= entry)
         return false;

      req.type   = QM_SELL_LIMIT;
      req.price  = entry;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "fsr_adv6_ema20_limit_short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = ((strategy_pending_expiration_hours > 1) ? strategy_pending_expiration_hours : 1) * 3600;
      return true;
     }
  }

// No active management beyond the EMA(40)-based stop. The ADX-weakening exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: ADX falls below the exit threshold (trend weakens). The
// position then closes regardless of direction.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false; // no ADX yet — do not force-close on a bad read

   return (adx < strategy_adx_exit_threshold);
  }

// Defer to the central news filter.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
