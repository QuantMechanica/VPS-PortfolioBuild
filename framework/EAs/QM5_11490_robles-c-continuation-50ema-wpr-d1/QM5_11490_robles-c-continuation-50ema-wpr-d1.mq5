#property strict
#property version   "5.0"
#property description "QM5_11490 robles-c-continuation-50ema-wpr-d1 — EMA50 trend-bias + Williams %R D1 pullback continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11490 robles-c-continuation-50ema-wpr-d1
// -----------------------------------------------------------------------------
// Source: Cecil Robles, "The Continuation Method", TradingPub 6 Simple
//   Strategies for Trading Forex (2014). YourForexMentor.com.
// Card: artifacts/cards_approved/QM5_11490_robles-c-continuation-50ema-wpr-d1.md
//   (g0_status APPROVED, R1 CONDITIONAL — named author/PDF).
//
// D1-native trend-continuation variant (entry TF = D1; bias TFs = W1 + D1).
// This is the single-timeframe-entry sibling of QM5_11464 (which entered on H4).
//
//   BIAS STATE (slow-change trend filter) — the trade only fires while bias
//   agrees. Two state legs, NEITHER is the trigger event:
//       Trend leg  (W1, EMA50 slope): LONG  EMA50(W1) sloping up; SHORT down.
//       Pullback side (D1, EMA50):    LONG  close(D1,1) < EMA50(D1)  (price has
//                                     pulled back below the D1 50 EMA — a
//                                     discounted continuation entry);
//                                     SHORT close(D1,1) > EMA50(D1).
//     The card models a "just-crossed" D1 EMA cross AND a %R extreme on the same
//     bar. Two fresh events on one bar is the .DWX two-cross zero-trade trap, so
//     the D1-EMA pullback is treated as a STATE (price currently on the pullback
//     side of the 50 EMA), and the %R exit is the single TRIGGER EVENT below.
//
//   TRIGGER EVENT (D1, Williams %R) — ONE event drives the entry: the %R exits
//   the extreme zone in the bias direction on the closed D1 bar (the flush is
//   exhausted and the trend resumes):
//       LONG : WPR(D1,2) <  -OS_level AND WPR(D1,1) >= -OS_level  (exits OS up)
//       SHORT: WPR(D1,2) >  -OB_level AND WPR(D1,1) <= -OB_level  (exits OB down)
//   MT5 iWPR scale is [-100, 0]; card oversold -70, overbought -30.
//
//   Stop   : QM_StopATR on D1 (atr_period, sl_atr_mult). Card pivot-low SL with
//            an 80-pip P2 cap maps to an ATR-scaled structural stop here (the
//            framework has no per-EA pivot scanner; ATR(14)*2 ~ a swing distance
//            and is volatility-correct across the FX basket). Flagged below.
//   Target : QM_TakeRR at tp_rr (Robles 2:1 baseline) off the realised stop.
//            Card's 5-SMA-trail-after-2R is approximated by the fixed 2R target
//            (the framework single-entry path has no multi-bar trail-state hook);
//            flagged below.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX 0).
//   No-Friday-entry: card filter — block new entries on broker Friday.
//
// Symbols (card R3, all present in dwx_symbol_matrix.csv): EURUSD, GBPUSD,
//   USDJPY, AUDUSD, USDCAD (.DWX). The build prompt's GER40->GDAXI / OIL->XTIUSD
//   porting hints are NOT card symbols and are not registered here.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11490;
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
input int    strategy_ema_bias_period   = 50;     // EMA period defining the trend bias
input int    strategy_w1_slope_lag      = 10;     // bars back on W1 for the EMA50 slope read
input int    strategy_wpr_period        = 14;     // Williams %R period on D1
input double strategy_wpr_os_level      = 70.0;   // oversold magnitude (level = -70, card)
input double strategy_wpr_ob_level      = 30.0;   // overbought magnitude (level = -30, card)
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR (D1)
input double strategy_tp_rr             = 2.0;    // take-profit at this R:R (Robles 2:1)
input bool   strategy_no_friday_entry   = true;   // card: no new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// Trend-bias TF is W1 (slow slope filter); pullback/trigger TF is the chart
// period (D1 per the setfile).
#define QM11490_TREND_TF PERIOD_W1

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — bias/signal work lives in
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

// Entry. Caller guarantees QM_IsNewBar() == true on the entry (D1) chart.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- No-Friday-entry filter (card). Broker-time weekday of the new bar. ---
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- TREND STATE (W1, EMA50 slope): slow-change directional filter ---
   const double ema_w1_now = QM_EMA(_Symbol, QM11490_TREND_TF, strategy_ema_bias_period, 1);
   const double ema_w1_lag = QM_EMA(_Symbol, QM11490_TREND_TF, strategy_ema_bias_period,
                                    1 + strategy_w1_slope_lag);
   if(ema_w1_now <= 0.0 || ema_w1_lag <= 0.0)
      return false;
   const bool w1_up   = (ema_w1_now > ema_w1_lag);
   const bool w1_down = (ema_w1_now < ema_w1_lag);
   if(!w1_up && !w1_down)
      return false;

   // --- PULLBACK STATE (D1, EMA50 side): price discounted vs the D1 50 EMA ---
   const double ema_d1 = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double close_d1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_d1 <= 0.0 || close_d1 <= 0.0)
      return false;
   // LONG bias: W1 up AND D1 price pulled BELOW the 50 EMA (discount entry).
   // SHORT bias: W1 down AND D1 price pulled ABOVE the 50 EMA.
   const bool long_bias  = w1_up   && (close_d1 < ema_d1);
   const bool short_bias = w1_down && (close_d1 > ema_d1);
   if(!long_bias && !short_bias)
      return false;

   // --- TRIGGER EVENT (D1, Williams %R): %R exits the extreme in bias dir ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // iWPR is bounded [-100, 0]; reject suspect out-of-band reads before a cross.
   if(wpr_now > 0.0 || wpr_prev > 0.0 || wpr_now < -100.0 || wpr_prev < -100.0)
      return false;

   const double os_level = -strategy_wpr_os_level;   // e.g. -70
   const double ob_level = -strategy_wpr_ob_level;   // e.g. -30

   // Long: %R was oversold (below -70) and crossed back up through -70.
   const bool long_trigger  = long_bias &&
                              (wpr_prev <  os_level) && (wpr_now >= os_level);
   // Short: %R was overbought (above -30) and crossed back down through -30.
   const bool short_trigger = short_bias &&
                              (wpr_prev >  ob_level) && (wpr_now <= ob_level);

   if(!long_trigger && !short_trigger)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = long_trigger ? QM_BUY : QM_SELL;
   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, otype, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_trigger ? "robles_c_cont_long" : "robles_c_cont_short";
   return true;
  }

// Fixed ATR stop + RR target carry the trade; no active management beyond that.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: W1 EMA50 trend bias flips against the open position. One
// event, read on the closed W1 bar via explicit-TF helpers.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_w1_now = QM_EMA(_Symbol, QM11490_TREND_TF, strategy_ema_bias_period, 1);
   const double ema_w1_lag = QM_EMA(_Symbol, QM11490_TREND_TF, strategy_ema_bias_period,
                                    1 + strategy_w1_slope_lag);
   if(ema_w1_now <= 0.0 || ema_w1_lag <= 0.0)
      return false;

   const bool w1_up   = (ema_w1_now > ema_w1_lag);
   const bool w1_down = (ema_w1_now < ema_w1_lag);

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && !w1_up)
         return true;   // long held but W1 trend no longer up
      if(ptype == POSITION_TYPE_SELL && !w1_down)
         return true;   // short held but W1 trend no longer down
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
