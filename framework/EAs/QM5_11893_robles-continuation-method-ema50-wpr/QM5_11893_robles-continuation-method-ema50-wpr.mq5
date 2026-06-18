#property strict
#property version   "5.0"
#property description "QM5_11893 robles-continuation-method-ema50-wpr — EMA50 H1 trend + Williams %R pullback continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11893 robles-continuation-method-ema50-wpr
// -----------------------------------------------------------------------------
// Source: Cecil Robles, "The Continuation Method", TradingPub "6 Simple
//   Strategies for Trading Forex" (~2015), pages 35-54, URL https://tradingpub.com.
// Card: artifacts/cards_approved/QM5_11893_robles-continuation-method-ema50-wpr.md
//   (g0_status APPROVED; R1 PARTIAL — named author + TradingPub chapter).
//
// Single-timeframe (H1) trend-pullback continuation. Sibling of QM5_11464
// (which splits bias=D1 / trigger=H4); THIS card is the H1 native version.
//
//   TREND STATE (H1, EMA50) — defines the bias direction:
//       LONG  bias: EMA50(H1,1) > EMA50(H1, 1+slope_lag)  (slope up over ~10 bars)
//       SHORT bias: EMA50(H1,1) < EMA50(H1, 1+slope_lag)  (slope down)
//
//   PULLBACK-VISIT STATE (H1) — the trend must have been pulled back into:
//       LONG : at least one of the last N bars closed BELOW EMA50 (wrong side).
//       SHORT: at least one of the last N bars closed ABOVE EMA50.
//     (Card Entry rule 3: close on the opposite side of the 50 EMA within last 20.)
//
//   EXTREME-VISIT STATE (H1, Williams %R) — the pullback overextended:
//       LONG : WPR reached <= -OS_level within the last N bars.
//       SHORT: WPR reached >= -OB_level within the last N bars.
//     (Card Entry rule 4.)
//
//   TRIGGER EVENT (H1, Williams %R) — the ONE event that fires the entry on the
//   just-closed bar: %R exits the extreme zone in the bias direction.
//       LONG : WPR(2) < -OS_level AND WPR(1) >= -OS_level   (crosses up out of OS)
//       SHORT: WPR(2) > -OB_level AND WPR(1) <= -OB_level   (crosses down out of OB)
//     MT5 iWPR scale is [-100, 0]; -80 = oversold, -20 = overbought (card).
//
//   The %R cross is the single trigger EVENT; the EMA50 slope, the pullback
//   visit and the extreme visit are STATE filters — none are required to occur
//   on the same bar as the trigger (the two-cross-same-bar zero-trade trap is
//   avoided). The visit states are scanned once per closed bar over a bounded
//   lookback window.
//
//   Stop   : QM_StopStructure on H1 — below the lowest low / above the highest
//            high of the last `strategy_struct_lookback` bars (card: last 10),
//            with the framework's structural buffer. Falls back to an ATR stop
//            if structure is unavailable.
//   Target : QM_TakeRR at strategy_tp_rr (Robles 2:1 baseline) off the stop.
//   Exit   : defensive — EMA50 slope bias flips against the open position.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX 0).
//
// Card buy-stop/sell-stop pending orders and the 5-SMA "Money Line Close"
// trailing exit are realised within the V5 single-entry/market-fill corset as a
// closed-bar market entry on the confirmed trigger plus a structural stop and an
// RR target; the SMA5 trail is approximated by the RR target + bias-flip exit.
// Flagged in open_questions.
//
// Symbols (card R3, all present in dwx_symbol_matrix.csv): EURUSD, GBPUSD,
//   USDJPY, USDCAD, USDCHF, AUDUSD, NZDUSD, EURJPY, GBPJPY, AUDJPY (.DWX).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11893;
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
input int    strategy_ema_bias_period    = 50;    // H1 EMA defining the trend bias
input int    strategy_ema_slope_lag      = 10;    // bars back for the EMA slope read (card: EMA[0]>EMA[10])
input int    strategy_pullback_lookback  = 20;    // bars to scan for a wrong-side close (card rule 3)
input int    strategy_extreme_lookback   = 20;    // bars to scan for the %R OB/OS visit (card rule 4)
input int    strategy_wpr_period         = 14;    // Williams %R period (card)
input double strategy_wpr_os_level       = 80.0;  // oversold magnitude (level = -80)
input double strategy_wpr_ob_level       = 20.0;  // overbought magnitude (level = -20)
input int    strategy_struct_lookback    = 10;    // bars for the swing stop (card: last 10 lows/highs)
input int    strategy_atr_period         = 14;    // ATR period for the fallback stop
input double strategy_sl_atr_mult        = 2.0;   // fallback stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;   // take-profit at this R:R (Robles 2:1)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

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

// Entry. Caller guarantees QM_IsNewBar() == true on the H1 chart.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- TREND STATE (H1): EMA50 slope over ~10 bars ---
   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double ema_lag = QM_EMA(_Symbol, _Period, strategy_ema_bias_period,
                                 1 + strategy_ema_slope_lag);
   if(ema_now <= 0.0 || ema_lag <= 0.0)
      return false;

   const bool long_bias  = (ema_now > ema_lag);
   const bool short_bias = (ema_now < ema_lag);
   if(!long_bias && !short_bias)
      return false;

   // --- PULLBACK-VISIT STATE (H1): a recent close on the wrong side of EMA50 ---
   // Bounded single-pass scan over closed bars; uses pooled QM_EMA reads and a
   // perf-allowed single-shift close read per bar.
   bool pullback_seen = false;
   const int pb_lookback = (strategy_pullback_lookback < 1) ? 1 : strategy_pullback_lookback;
   for(int s = 1; s <= pb_lookback && !pullback_seen; ++s)
     {
      const double c   = iClose(_Symbol, _Period, s);            // perf-allowed: single closed-bar read
      const double ema = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, s);
      if(c <= 0.0 || ema <= 0.0)
         continue;
      if(long_bias && c < ema)   pullback_seen = true;  // dipped below the EMA in an uptrend
      if(short_bias && c > ema)  pullback_seen = true;  // popped above the EMA in a downtrend
     }
   if(!pullback_seen)
      return false;

   // --- WPR validity + levels ---
   const double os_level = -strategy_wpr_os_level;   // e.g. -80
   const double ob_level = -strategy_wpr_ob_level;   // e.g. -20

   // --- EXTREME-VISIT STATE (H1): %R reached the OB/OS zone recently ---
   bool extreme_seen = false;
   const int ex_lookback = (strategy_extreme_lookback < 2) ? 2 : strategy_extreme_lookback;
   for(int s = 1; s <= ex_lookback && !extreme_seen; ++s)
     {
      const double w = QM_WPR(_Symbol, _Period, strategy_wpr_period, s);
      if(w > 0.0 || w < -100.0)
         continue;  // out-of-band read — ignore
      if(long_bias && w <= os_level)   extreme_seen = true;  // visited oversold
      if(short_bias && w >= ob_level)  extreme_seen = true;  // visited overbought
     }
   if(!extreme_seen)
      return false;

   // --- TRIGGER EVENT (H1): %R exits the extreme zone in the bias direction ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // iWPR is bounded [-100, 0]; require strictly in-band values before a cross.
   if(wpr_now > 0.0 || wpr_prev > 0.0 || wpr_now < -100.0 || wpr_prev < -100.0)
      return false;

   // Long: %R was below -80 and crossed back up through -80 on the closed bar.
   const bool long_trigger  = long_bias &&
                              (wpr_prev <  os_level) && (wpr_now >= os_level);
   // Short: %R was above -20 and crossed back down through -20 on the closed bar.
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

   // Structural swing stop (card: lowest low / highest high of last 10 bars),
   // with an ATR stop fallback if structure is unavailable.
   double sl = QM_StopStructure(_Symbol, otype, entry, strategy_struct_lookback);
   if(sl <= 0.0)
      sl = QM_StopATR(_Symbol, otype, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_trigger ? "robles_cont_long" : "robles_cont_short";
   return true;
  }

// Fixed structural stop + RR target carry the trade; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA50 H1 slope bias flips against the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double ema_lag = QM_EMA(_Symbol, _Period, strategy_ema_bias_period,
                                 1 + strategy_ema_slope_lag);
   if(ema_now <= 0.0 || ema_lag <= 0.0)
      return false;

   const bool long_bias  = (ema_now > ema_lag);
   const bool short_bias = (ema_now < ema_lag);

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && !long_bias)
         return true;   // long held but H1 bias no longer up
      if(ptype == POSITION_TYPE_SELL && !short_bias)
         return true;   // short held but H1 bias no longer down
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
