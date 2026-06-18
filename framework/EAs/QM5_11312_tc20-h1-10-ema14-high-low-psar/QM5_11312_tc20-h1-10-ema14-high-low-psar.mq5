#property strict
#property version   "5.0"
#property description "QM5_11312 tc20-h1-10-ema14-high-low-psar — EMA(14,High)/EMA(14,Low) channel + PSAR flip (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11312 tc20-h1-10-ema14-high-low-psar
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)" 2014,
// Strategy #10. Card: artifacts/cards_approved/
//   QM5_11312_tc20-h1-10-ema14-high-low-psar.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Channel STATE : EMA(14) applied to HIGH and EMA(14) applied to LOW form a
//                   smooth Donchian-style channel.
//                     LONG state  = close[1] > EMA14_high
//                     SHORT state = close[1] < EMA14_low
//   Direction STATE: Parabolic SAR(step, max) position relative to the candle.
//                     bullish = SAR below close ; bearish = SAR above close.
//   Trigger EVENT  : the PSAR FLIP is the single event. SAR was on the opposite
//                    side on the prior closed bar (shift 2) and flipped on the
//                    trigger bar (shift 1). The channel position is a STATE that
//                    must already hold — NOT a second simultaneous event (per the
//                    .DWX "don't require two events on one bar" invariant).
//   Stop           : ATR(14) * sl_atr_mult  (card P2: ATR(14) x 1.5).
//   Take profit    : fixed tp_pips (card: 60-100, P2 midpoint 80), pip-scaled
//                    via QM_StopRulesPipsToPriceDistance (5-digit / JPY safe).
//   Reverse exit   : close crosses back through the channel
//                     (LONG closed if close[1] < EMA14_high ; inverse for SHORT).
//   Spread guard   : skip only a genuinely wide spread > spread_pct_of_stop of
//                    the stop distance; fail-open on .DWX zero modeled spread.
//
// One position per magic. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11312;
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
input int    strategy_ema_period         = 14;    // EMA period for the High/Low channel
input double strategy_sar_step           = 0.02;  // Parabolic SAR acceleration step
input double strategy_sar_max            = 0.2;   // Parabolic SAR maximum acceleration
input double strategy_sl_atr_period      = 14;    // ATR period for the stop
input double strategy_sl_atr_mult        = 1.5;   // stop distance = mult * ATR (card P2)
input int    strategy_tp_pips            = 80;    // fixed take-profit, pips (card 60-100)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — channel/SAR work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const int atr_p = (int)strategy_sl_atr_period;
   const double atr_value = QM_ATR(_Symbol, _Period, atr_p, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Channel STATE: EMA(14) on HIGH and EMA(14) on LOW (closed bar) ---
   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_HIGH);
   const double ema_low  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_LOW);
   if(ema_high <= 0.0 || ema_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Direction STATE + FLIP EVENT: Parabolic SAR(step, max) ---
   // Card literal: SAR below the candle (SAR < Low) => bullish ; SAR above the
   // candle (SAR > High) => bearish. The FLIP (opposite side on shift 2, this
   // side on shift 1) is the single trigger event. The channel breakout is a
   // STATE that must already hold — never a second simultaneous event.
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double high1    = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1     = iLow (_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high2    = iHigh(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low2     = iLow (_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_now <= 0.0 || sar_prev <= 0.0 ||
      high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const bool sar_flip_bull = (sar_prev > high2 && sar_now < low1);  // bearish -> bullish
   const bool sar_flip_bear = (sar_prev < low2  && sar_now > high1); // bullish -> bearish

   const double atr_value = QM_ATR(_Symbol, _Period, (int)strategy_sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(tp_distance <= 0.0)
      return false;

   // --- LONG: bullish SAR flip while price is above the upper (High) EMA ---
   if(sar_flip_bull && close1 > ema_high)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_distance);
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_hl_channel_psar_long";
      return true;
     }

   // --- SHORT: bearish SAR flip while price is below the lower (Low) EMA ---
   if(sar_flip_bear && close1 < ema_low)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_distance);
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_hl_channel_psar_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / pip target. The
// reverse exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Reverse exit: price closes back through the EMA channel against the position.
// LONG closed when close[1] < EMA14_high ; SHORT closed when close[1] > EMA14_low.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_HIGH);
   const double ema_low  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_LOW);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_high <= 0.0 || ema_low <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the direction of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && close1 < ema_high)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ema_low)
         return true;
     }
   return false;
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
