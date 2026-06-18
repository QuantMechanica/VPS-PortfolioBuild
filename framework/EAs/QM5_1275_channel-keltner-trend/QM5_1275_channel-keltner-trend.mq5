#property strict
#property version   "5.0"
#property description "QM5_1275 channel-keltner-trend — Keltner channel trend-breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1275 channel-keltner-trend
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading Systems "Channel-Trading-System" (Keltner
//   variant). Keltner envelope = Chester Keltner (1960), popularised by Linda
//   Bradford Raschke ("Street Smarts" 1996). Card source_id 6e967762.
// Card: artifacts/cards_approved/QM5_1275_channel-keltner-trend.md (APPROVED).
//
// Keltner channel (closed-bar reads at shift 1, H1):
//   midline  = EMA(kc_ema_period)                 (channel midline)
//   width    = ATR(kc_atr_period)
//   upperKC  = midline + kc_atr_mult * width
//   lowerKC  = midline - kc_atr_mult * width
//   macro EMA= EMA(trend_ema_period)              (regime filter, STATE)
//
// Mechanics:
//   Trigger EVENT (ONE band cross): closed bar broke beyond the band for the
//     first time in the last two bars —
//       LONG : Close[1] > upperKC[1]  AND  Close[2] <= upperKC[2]
//       SHORT: Close[1] < lowerKC[1]  AND  Close[2] >= lowerKC[2]
//     This is the single modeled cross. The mid/macro relationship is a STATE,
//     NOT a second cross event (avoids the two-cross-same-bar zero-trade trap).
//   Regime STATE: EMA(20)[1] > EMA(200)[1] for longs (mirror for shorts).
//   Stop  : opposite channel boundary at signal time (LONG lowerKC[1]; SHORT
//           upperKC[1]), floored to >= kc_atr_mult_sl_floor * ATR so a
//           near-mid-channel touch can't produce a micro-stop.
//   Take  : fixed RR multiple of the (floored) stop distance.
//   Exit  : (a) price closes back to the midline EMA on a closed bar, or
//           (b) opposite-channel break (trend reversal). Both close manually.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX zero
//           modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1275;
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
input int    strategy_kc_ema_period       = 20;    // Keltner midline EMA period
input int    strategy_kc_atr_period       = 10;    // Keltner width ATR period
input double strategy_kc_atr_mult         = 2.0;   // Keltner band multiplier
input int    strategy_trend_ema_period    = 200;   // macro trend EMA (regime STATE)
input double strategy_sl_atr_floor_mult   = 1.5;   // min SL distance = mult * ATR
input double strategy_tp_rr               = 2.0;   // take-profit RR multiple of stop
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers — Keltner band reconstruction from QM_EMA + QM_ATR (no QM_Keltner).
// -----------------------------------------------------------------------------

double KC_Mid(const int shift)
  {
   return QM_EMA(_Symbol, _Period, strategy_kc_ema_period, shift);
  }

double KC_Upper(const int shift)
  {
   const double mid = QM_EMA(_Symbol, _Period, strategy_kc_ema_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return 0.0;
   return mid + strategy_kc_atr_mult * atr;
  }

double KC_Lower(const int shift)
  {
   const double mid = QM_EMA(_Symbol, _Period, strategy_kc_ema_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return 0.0;
   return mid - strategy_kc_atr_mult * atr;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/regime work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap. ATR-floored stop distance so
   // the cap scales with the symbol's volatility.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_floor_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Trend-breakout entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Keltner bands at the trigger bar [1] and the prior bar [2]. ---
   const double upper1 = KC_Upper(1);
   const double upper2 = KC_Upper(2);
   const double lower1 = KC_Lower(1);
   const double lower2 = KC_Lower(2);
   if(upper1 <= 0.0 || upper2 <= 0.0 || lower1 <= 0.0 || lower2 <= 0.0)
      return false;

   // --- Macro trend EMA regime STATE (closed bar). ---
   const double trend_ema = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1);
   const double mid1       = KC_Mid(1);
   if(trend_ema <= 0.0 || mid1 <= 0.0)
      return false;

   // --- Closed-bar closes for the cross EVENT. perf-allowed single reads. ---
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // first-break of the upper band (ONE cross event). Regime = mid above macro.
   const bool long_break  = (close1 > upper1 && close2 <= upper2);
   const bool long_regime = (mid1 > trend_ema);

   // first-break of the lower band (ONE cross event). Regime = mid below macro.
   const bool short_break  = (close1 < lower1 && close2 >= lower2);
   const bool short_regime = (mid1 < trend_ema);

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double sl_floor = strategy_sl_atr_floor_mult * atr_value;

   if(long_break && long_regime)
     {
      // Initial SL = lower channel boundary, floored to >= sl_floor below entry.
      double sl = lower1;
      if(entry - sl < sl_floor)
         sl = entry - sl_floor;
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "kc_trend_break_long";
      return true;
     }

   if(short_break && short_regime)
     {
      // Initial SL = upper channel boundary, floored to >= sl_floor above entry.
      // Short entry fills at bid.
      double sl = upper1;
      if(sl - bid < sl_floor)
         sl = bid + sl_floor;
      if(sl <= bid)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "kc_trend_break_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed stop/target. Midline + reversal
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: (a) close back through the midline EMA against the trade,
// or (b) opposite-channel break (trend reversal). Evaluated per closed bar via
// the framework gate in OnTick.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double mid1   = KC_Mid(1);
   const double upper1 = KC_Upper(1);
   const double lower1 = KC_Lower(1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(mid1 <= 0.0 || upper1 <= 0.0 || lower1 <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the side of this EA's open position.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   if(is_long)
     {
      // Midline pulse exhausted: close back below midline. Or reversal: break
      // below lower band.
      if(close1 <= mid1 || close1 < lower1)
         return true;
     }
   else // is_short
     {
      if(close1 >= mid1 || close1 > upper1)
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return;
     }

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
