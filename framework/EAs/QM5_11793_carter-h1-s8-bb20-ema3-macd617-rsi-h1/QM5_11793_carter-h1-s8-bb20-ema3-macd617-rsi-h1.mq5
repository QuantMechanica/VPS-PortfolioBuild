#property strict
#property version   "5.0"
#property description "QM5_11793 carter-h1-s8-bb20-ema3-macd617-rsi-h1 — BB/EMA/MACD/RSI confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11793 carter-h1-s8-bb20-ema3-macd617-rsi-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy S8, Scribd ~2014
//         (376863900-20-Forex-Trading-Strategies-Collection.pdf).
// Card: artifacts/cards_approved/QM5_11793_carter-h1-s8-bb20-ema3-macd617-rsi-h1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   The card describes a BB(20,3) band-touch reversal with EMA/MACD/RSI
//   confirmation. To avoid the two-cross-same-bar zero-trade trap, exactly ONE
//   indicator is the trigger EVENT; the remaining conditions are confirming
//   STATES observed on the same closed bar.
//
//   Trigger EVENT : EMA(3) crosses the Bollinger middle band (SMA20).
//                   LONG  = EMA3 crosses UP   over BB_mid (reversal up after a
//                           lower-band excursion).
//                   SHORT = EMA3 crosses DOWN under BB_mid.
//                   ONE cross event per direction — the MACD/RSI/BB conditions
//                   below are STATES, never second cross events.
//   Confirm STATE : BB position — price has recently visited the relevant band
//                   (long: low touched the lower band within bb_touch_lookback;
//                    short: high touched the upper band). This carries the
//                   card's "band-touch reversal" character without requiring a
//                   second same-bar cross.
//   Confirm STATE : MACD(6,17,1) main  > 0 (long)  / < 0 (short).
//   Confirm STATE : RSI(14) guard — long requires RSI < rsi_ob (not deeply
//                   overbought); short requires RSI > rsi_os (not deeply
//                   oversold). Card: "RSI < 70" long, "RSI > 30" short.
//   Stop          : 2 * ATR(14) from entry (card default).
//   Take profit   : 4 * ATR(14) from entry (card: BB middle band / 4xATR).
//   Spread guard  : block only a genuinely wide spread > spread_pct_of_stop of
//                   the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11793;
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
input int    strategy_bb_period          = 20;     // Bollinger period (middle = SMA20)
input double strategy_bb_deviation       = 3.0;    // Bollinger deviation (card BB(20,3))
input int    strategy_ema_period         = 3;      // fast EMA crossing the BB midline
input int    strategy_macd_fast          = 6;      // MACD fast EMA period
input int    strategy_macd_slow          = 17;     // MACD slow EMA period
input int    strategy_macd_signal        = 1;      // MACD signal period (1 = no smoothing)
input int    strategy_rsi_period         = 14;     // RSI lookback period
input double strategy_rsi_overbought     = 70.0;   // long guard: RSI must be below this
input double strategy_rsi_oversold       = 30.0;   // short guard: RSI must be above this
input int    strategy_bb_touch_lookback  = 6;      // bars to look back for the band touch
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// Regime/signal work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
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

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands (closed bar; deviation arg is MANDATORY) ---
   const double bb_mid_now   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_prev  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_mid_now <= 0.0 || bb_mid_prev <= 0.0)
      return false;

   // --- Trigger EVENT: EMA(3) cross of the BB middle band (one event/bar) ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return false;

   const bool crossed_up   = (ema_prev <= bb_mid_prev && ema_now >  bb_mid_now);
   const bool crossed_down = (ema_prev >= bb_mid_prev && ema_now <  bb_mid_now);
   if(!crossed_up && !crossed_down)
      return false; // no trigger this bar

   // --- Confirming STATES: MACD side + RSI guard (closed bar) ---
   const double macd = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                    strategy_macd_signal, 1);
   const double rsi  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   QM_OrderType dir;

   if(crossed_up)
     {
      // LONG confirmation: MACD main > 0 AND RSI not deeply overbought.
      if(!(macd > 0.0 && rsi < strategy_rsi_overbought))
         return false;

      // BB-position STATE: price recently touched the LOWER band (band-touch
      // reversal character). Scan the bars preceding the trigger bar.
      bool touched = false;
      for(int s = 1; s <= strategy_bb_touch_lookback; ++s)
        {
         const double bb_lower_s = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
         const double low_s      = iLow(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(bb_lower_s <= 0.0 || low_s <= 0.0)
            continue;
         if(low_s <= bb_lower_s)
           {
            touched = true;
            break;
           }
        }
      if(!touched)
         return false;

      dir = QM_BUY;
     }
   else // crossed_down
     {
      // SHORT confirmation: MACD main < 0 AND RSI not deeply oversold.
      if(!(macd < 0.0 && rsi > strategy_rsi_oversold))
         return false;

      // BB-position STATE: price recently touched the UPPER band.
      bool touched = false;
      for(int s = 1; s <= strategy_bb_touch_lookback; ++s)
        {
         const double bb_upper_s = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
         const double high_s     = iHigh(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(bb_upper_s <= 0.0 || high_s <= 0.0)
            continue;
         if(high_s >= bb_upper_s)
           {
            touched = true;
            break;
           }
        }
      if(!touched)
         return false;

      dir = QM_SELL;
     }

   // --- Entry price + ATR-based stop / target ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "carter_s8_bb_ema_long" : "carter_s8_bb_ema_short";
   return true;
  }

// Fixed ATR-based SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
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
