#property strict
#property version   "5.0"
#property description "QM5_11618 robo-lwma-low-macd1526-m30 — LWMA-Low band + MACD(15,26,1) zero-cross (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11618 robo-lwma-low-macd1526-m30
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         page 54, strategy "LWMA + MACD".
// Card: artifacts/cards_approved/QM5_11618_robo-lwma-low-macd1526-m30.md
//       (g0_status APPROVED). Source id ed246754-1f4d-5bed-8dd3-3b5cbf1b420d.
//
// Mechanics (closed-bar reads at shift 1; M30):
//   Three LWMAs applied to the LOW price form a dynamic support band:
//     wma_outer = WMA(85, Low), wma_mid = WMA(75, Low), wma_fast = WMA(5, Low).
//
//   Trend STATE (long):
//     close(1) > wma_mid  AND  close(1) > wma_outer  (price above the band)
//     AND wma_fast > wma_mid                         (fast Low-WMA above slow)
//   Trend STATE (short):
//     close(1) < wma_mid                             (price below the band)
//     AND wma_fast < wma_mid                         (fast Low-WMA below slow)
//
//   Trigger EVENT (the single fresh cross — avoids the two-cross trap):
//     MACD(15,26,1) main line crosses ABOVE zero  -> long candidate
//     MACD(15,26,1) main line crosses BELOW zero  -> short candidate
//   With signal period = 1 the MACD signal line equals the main line, so the
//   card's "signal line crosses zero" reduces to a single MACD-main zero-cross.
//   We use ONE event (the MACD zero-cross); the WMA-band relations are STATES.
//
//   Stop loss : longs use WMA(85,Low); shorts use sl_atr_mult * ATR(atr_period).
//   Take prof.: entry +/- tp_atr_mult * ATR(atr_period)   (same ATR value).
//   Exit      : managed by SL / TP only; one position per magic.
//   Spread    : block only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11618;
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
input int    strategy_wma_fast_period   = 5;     // inner Low-WMA (fast)
input int    strategy_wma_mid_period    = 75;    // middle Low-WMA (slow structure)
input int    strategy_wma_outer_period  = 85;    // outer Low-WMA (band floor)
input int    strategy_macd_fast         = 15;    // MACD fast EMA
input int    strategy_macd_slow         = 26;    // MACD slow EMA
input int    strategy_macd_signal       = 1;     // MACD signal SMA (1 -> main=signal)
input int    strategy_atr_period        = 14;    // ATR period (stop / target)
input double strategy_short_sl_atr_mult = 2.0;   // short stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;   // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_short_sl_atr_mult * atr_value;
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

   // --- LWMA-Low band (closed bar, shift 1) ---
   const double wma_fast  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period,  1, PRICE_LOW);
   const double wma_mid   = QM_WMA(_Symbol, _Period, strategy_wma_mid_period,   1, PRICE_LOW);
   const double wma_outer = QM_WMA(_Symbol, _Period, strategy_wma_outer_period, 1, PRICE_LOW);
   if(wma_fast <= 0.0 || wma_mid <= 0.0 || wma_outer <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- ATR for stop/target sizing ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Trigger EVENT: MACD(15,26,1) main line zero-cross (one event/bar) ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 2);

   const bool macd_cross_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool macd_cross_down = (macd_prev >= 0.0 && macd_now < 0.0);

   // --- Trend STATE filters around the Low-WMA band ---
   const bool long_state  = (close1 > wma_mid && close1 > wma_outer && wma_fast > wma_mid);
   const bool short_state = (close1 < wma_mid && wma_fast < wma_mid);

   QM_OrderType dir;
   if(macd_cross_up && long_state)
      dir = QM_BUY;
   else if(macd_cross_down && short_state)
      dir = QM_SELL;
   else
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(dir == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, wma_outer);
   else
      sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_short_sl_atr_mult);

   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if((dir == QM_BUY && sl >= entry) || (dir == QM_SELL && sl <= entry))
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "lwma_low_macd_long" : "lwma_low_macd_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP only — no discretionary exit.
bool Strategy_ExitSignal()
  {
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
