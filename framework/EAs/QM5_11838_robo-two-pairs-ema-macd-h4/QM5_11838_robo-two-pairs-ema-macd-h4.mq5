#property strict
#property version   "5.0"
#property description "QM5_11838 robo-two-pairs-ema-macd-h4 — 4-EMA cascade + MACD trend (H4 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11838 robo-two-pairs-ema-macd-h4
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         page 92, "Two Pairs EMA + MACD".
// Card: artifacts/cards_approved/QM5_11838_robo-two-pairs-ema-macd-h4.md
//       (g0_status APPROVED).
//
// INTERPRETATION (flagged): "Two Pairs" = the source strategy deployed on two
// FX pairs INDEPENDENTLY (EURUSD.DWX, GBPUSD.DWX). Neither pair's signal
// references the other. This is kind:single — registered on both symbols, ONE
// position per magic per symbol, NO basket manifest, NO foreign-symbol reads.
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Cascade STATE (long) : EMA5 > EMA15 > EMA50 > EMA100  (full bullish stack).
//   Cascade STATE (short): EMA5 < EMA15 < EMA50 < EMA100  (full bearish stack).
//   Trigger EVENT (long) : MACD main crosses ABOVE signal (one event/bar).
//   Trigger EVENT (short): MACD main crosses BELOW signal (one event/bar).
//   Sign STATE filter    : optional — require MACD main on the correct side of 0
//                          (long: main>0, short: main<0) to match the card's
//                          "main line >0 / <0" confirmation.
//   Stop   : QM_StopATR( type, entry, atr_period, sl_atr_mult ).
//   Take   : QM_TakeRR( type, entry, sl, rr ) with rr = tp/sl mult ratio.
//   Defensive exit: EMA(5)/EMA(15) cross AGAINST the open position direction.
//
// Two-cross trap avoided: the EMA cascade is a STATE (currently-stacked), only
// the MACD signal cross is a fresh EVENT. We never require two simultaneous
// crossovers on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11838;
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
input int    strategy_ema1_period       = 5;     // fastest EMA (cascade head)
input int    strategy_ema2_period       = 15;    // fast EMA
input int    strategy_ema3_period       = 50;    // macro anchor (mid)
input int    strategy_ema4_period       = 100;   // macro anchor (slow)
input int    strategy_macd_fast         = 12;    // MACD fast EMA
input int    strategy_macd_slow         = 26;    // MACD slow EMA
input int    strategy_macd_signal       = 9;     // MACD signal SMA
input bool   strategy_require_macd_sign = true;  // also require MACD main on correct side of 0
input int    strategy_atr_period        = 14;    // ATR period (stop / target basis)
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;   // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — cascade/MACD work is in
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

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Four-EMA cascade STATE (closed bar, shift 1) ---
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema1_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema2_period, 1);
   const double ema3 = QM_EMA(_Symbol, _Period, strategy_ema3_period, 1);
   const double ema4 = QM_EMA(_Symbol, _Period, strategy_ema4_period, 1);
   if(ema1 <= 0.0 || ema2 <= 0.0 || ema3 <= 0.0 || ema4 <= 0.0)
      return false;

   const bool cascade_long  = (ema1 > ema2 && ema2 > ema3 && ema3 > ema4);
   const bool cascade_short = (ema1 < ema2 && ema2 < ema3 && ema3 < ema4);
   if(!cascade_long && !cascade_short)
      return false;

   // --- MACD trigger EVENT: signal-line cross (shift 2 -> shift 1) ---
   const double macd_main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                               strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_prev  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                               strategy_macd_slow, strategy_macd_signal, 2);

   const bool macd_cross_up   = (macd_main_prev <= macd_sig_prev && macd_main_now > macd_sig_now);
   const bool macd_cross_down = (macd_main_prev >= macd_sig_prev && macd_main_now < macd_sig_now);

   // Optional MACD-sign STATE filter (card: "main line > 0 / < 0").
   const bool sign_long_ok  = (!strategy_require_macd_sign || macd_main_now > 0.0);
   const bool sign_short_ok = (!strategy_require_macd_sign || macd_main_now < 0.0);

   bool go_long  = (cascade_long  && macd_cross_up   && sign_long_ok);
   bool go_short = (cascade_short && macd_cross_down && sign_short_ok);

   if(!go_long && !go_short)
      return false;

   // --- Stop / target from ATR. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;
   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, otype, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   const double rr = (strategy_sl_atr_mult > 0.0) ? (strategy_tp_atr_mult / strategy_sl_atr_mult) : 2.0;
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "ema_cascade_macd_long" : "ema_cascade_macd_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. The defensive
// EMA(5)/EMA(15) cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(5)/EMA(15) cross AGAINST the open position direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current open direction for this magic.
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
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double f_now  = QM_EMA(_Symbol, _Period, strategy_ema1_period, 1);
   const double s_now  = QM_EMA(_Symbol, _Period, strategy_ema2_period, 1);
   const double f_prev = QM_EMA(_Symbol, _Period, strategy_ema1_period, 2);
   const double s_prev = QM_EMA(_Symbol, _Period, strategy_ema2_period, 2);
   if(f_now <= 0.0 || s_now <= 0.0 || f_prev <= 0.0 || s_prev <= 0.0)
      return false;

   // Long position: exit when EMA5 crosses BELOW EMA15.
   if(is_long)
      return (f_prev >= s_prev && f_now < s_now);
   // Short position: exit when EMA5 crosses ABOVE EMA15.
   return (f_prev <= s_prev && f_now > s_now);
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
