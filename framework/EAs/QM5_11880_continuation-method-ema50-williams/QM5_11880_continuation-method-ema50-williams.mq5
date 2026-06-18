#property strict
#property version   "5.0"
#property description "QM5_11880 continuation-method-ema50-williams — EMA50 H4-bias + Williams %R H1 pullback continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11880 continuation-method-ema50-williams
// -----------------------------------------------------------------------------
// Source: Unknown author, "The Secret to Winning Forex Trades — Continuation
//   Method" (~2012, local PDF archive). source_id f0c55de1-dfde-56a4-b052-
//   3f37e36ed1 (per card frontmatter).
// Card: artifacts/cards_approved/QM5_11880_continuation-method-ema50-williams.md
//   (g0_status APPROVED; R2/R3/R4 PASS).
//
// Multi-timeframe trend-continuation. Entry TF = H1 (chart period per setfile);
// bias TF = H4. Sibling of QM5_11464 (same Williams %R continuation family);
// THIS card adds an H4 bias TF (not D1), a 10-bar EMA50 slope read with a flat
// deadband, and an H1-EMA50 pullback STATE precondition before the %R trigger.
//
//   BIAS STATE (H4, EMA50) — the higher TF defines the trend direction. Slope
//   is read as EMA50(H4,1) vs EMA50(H4,1+slope_lag). A flat slope (|delta| <=
//   flat_deadband_pips) yields NO bias → no signal (card: "No signal if EMA50
//   is flat (values within 5 pips)"):
//       LONG  bias: EMA50(H4) sloping up   beyond the deadband
//       SHORT bias: EMA50(H4) sloping down beyond the deadband
//
//   PULLBACK STATE (H1, EMA50) — price must have pulled back into the trend on
//   the entry TF before the trigger. Detected on the trigger-precursor bar
//   (shift 2, i.e. the bar before the %R-exit bar) so the pullback is observed
//   BEFORE the trigger event, never on the same bar:
//       LONG : close(H1,2) < EMA50(H1,2)   (pulled below the H1 EMA in an uptrend)
//       SHORT: close(H1,2) > EMA50(H1,2)   (pulled above the H1 EMA in a downtrend)
//
//   TRIGGER EVENT (H1, Williams %R) — ONE event drives the entry: the %R exits
//   its extreme zone in the bias direction on the closed H1 bar. MT5 iWPR is
//   bounded [-100, 0]; -80 = oversold, -20 = overbought (card):
//       LONG : WPR(H1,2) < -OS_level AND WPR(H1,1) >= -OS_level  (exits OS up)
//       SHORT: WPR(H1,2) > -OB_level AND WPR(H1,1) <= -OB_level  (exits OB down)
//
//   The %R cross is the single trigger EVENT; the EMA50 H4 stack and the H1
//   pullback are STATE filters — they are NEVER required to coincide as fresh
//   crosses on the same bar (two-cross trap avoided).
//
//   Stop   : QM_StopStructure on H1 — swing low (long) / swing high (short)
//            over the last sl_swing_lookback closed bars (card: lowest low /
//            highest high of the last 5 bars before signal).
//   Target : QM_TakeRR at tp_rr (card 2:1) off the realised structure stop.
//   Exit   : defensive SMA(5) trailing close once 2:1 R:R is reached — two
//            consecutive H1 closes below SMA5 (long) / above SMA5 (short).
//            The hard structure SL and 2:1 TP remain active throughout.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX 0).
//
// Symbols (card R3, all present in dwx_symbol_matrix.csv): EURUSD, GBPUSD,
//   USDJPY, AUDUSD (.DWX). GER40→GDAXI / OIL→XTIUSD porting hints from the
//   build prompt are NOT card symbols and are not used here.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11880;
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
input int    strategy_ema_bias_period   = 50;    // EMA defining the trend bias (H4)
input int    strategy_ema_slope_lag     = 10;    // bars back on H4 for the EMA50 slope read (card: 10)
input double strategy_flat_deadband_pips = 5.0;  // EMA50 slope deadband (card: flat within 5 pips)
input int    strategy_ema_pullback_period = 50;  // EMA pullback reference on the entry TF (H1)
input int    strategy_wpr_period        = 14;    // Williams %R period on H1
input double strategy_wpr_os_level      = 80.0;  // oversold magnitude (level = -80)
input double strategy_wpr_ob_level      = 20.0;  // overbought magnitude (level = -20)
input int    strategy_sl_swing_lookback = 5;     // swing-structure stop lookback (H1 bars)
input double strategy_tp_rr             = 2.0;   // take-profit at this R:R (card 2:1)
input int    strategy_exit_sma_period   = 5;     // trailing-exit SMA period (H1)
input int    strategy_exit_sma_closes   = 2;     // consecutive closes beyond SMA to exit
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// Bias TF is fixed H4; entry TF is the chart period (H1 per the setfile).
#define QM11880_BIAS_TF PERIOD_H4

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

   // Structure-stop distance reference for the spread cap, at the current ask.
   const double swing_stop = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_sl_swing_lookback);
   if(swing_stop <= 0.0 || swing_stop >= ask)
      return false; // no usable structure stop yet — defer, do not block here

   const double stop_distance = ask - swing_stop;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true on the entry (H1) chart.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- BIAS STATE (H4): EMA50 slope beyond the flat deadband ---
   const double ema_h4_now = QM_EMA(_Symbol, QM11880_BIAS_TF, strategy_ema_bias_period, 1);
   const double ema_h4_lag = QM_EMA(_Symbol, QM11880_BIAS_TF, strategy_ema_bias_period,
                                    1 + strategy_ema_slope_lag);
   if(ema_h4_now <= 0.0 || ema_h4_lag <= 0.0)
      return false;

   const double deadband = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_flat_deadband_pips);
   const double slope = ema_h4_now - ema_h4_lag;
   const bool long_bias  = (slope >  deadband);
   const bool short_bias = (slope < -deadband);
   if(!long_bias && !short_bias)
      return false; // flat EMA50 → no signal

   // --- PULLBACK STATE (H1): price pulled back into the trend on the bar that
   //     PRECEDES the trigger bar (shift 2), so it is observed before the %R
   //     trigger event — never on the same bar. ---
   const double ema_h1_2  = QM_EMA(_Symbol, _Period, strategy_ema_pullback_period, 2);
   const double close_h1_2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(ema_h1_2 <= 0.0 || close_h1_2 <= 0.0)
      return false;
   const bool long_pullback  = (close_h1_2 < ema_h1_2);  // dipped below H1 EMA in uptrend
   const bool short_pullback = (close_h1_2 > ema_h1_2);  // popped above H1 EMA in downtrend

   // --- TRIGGER EVENT (H1, Williams %R): %R exits the extreme in bias dir ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // iWPR is bounded [-100, 0]; reject degenerate reads before trusting a cross.
   if(wpr_now > 0.0 || wpr_prev > 0.0 || wpr_now < -100.0 || wpr_prev < -100.0)
      return false;

   const double os_level = -strategy_wpr_os_level;   // e.g. -80
   const double ob_level = -strategy_wpr_ob_level;   // e.g. -20

   // Long: bias up, pulled back, %R was oversold (below -80) and crossed up.
   const bool long_trigger  = long_bias && long_pullback &&
                              (wpr_prev <  os_level) && (wpr_now >= os_level);
   // Short: bias down, pulled back, %R was overbought (above -20) and crossed down.
   const bool short_trigger = short_bias && short_pullback &&
                              (wpr_prev >  ob_level) && (wpr_now <= ob_level);

   if(!long_trigger && !short_trigger)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = long_trigger ? QM_BUY : QM_SELL;
   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop = nearest swing low (long) / swing high (short) over the lookback.
   const double sl = QM_StopStructure(_Symbol, otype, entry, strategy_sl_swing_lookback);
   if(sl <= 0.0)
      return false;
   // Stop must sit on the correct side of entry to give a real risk distance.
   if(otype == QM_BUY  && !(sl < entry))
      return false;
   if(otype == QM_SELL && !(sl > entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_trigger ? "cont_ema50_wpr_long" : "cont_ema50_wpr_short";
   return true;
  }

// Fixed structure stop + 2:1 RR target carry the trade; the SMA5 trailing exit
// (in Strategy_ExitSignal) provides the post-2:1 defensive close. No SL/TP
// modification here.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: once the trade has reached 2:1 R:R, close on `exit_sma_closes`
// consecutive H1 closes beyond SMA(5) against the position (card trailing rule).
// The hard structure SL and the 2:1 TP remain active independently.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve the open position for this magic.
   double open_price = 0.0;
   double pos_sl     = 0.0;
   long   ptype      = -1;
   bool   found      = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      pos_sl     = PositionGetDouble(POSITION_SL);
      ptype      = PositionGetInteger(POSITION_TYPE);
      found      = true;
      break;
     }
   if(!found || open_price <= 0.0)
      return false;

   // Only arm the SMA5 trail after 2:1 R:R is reached. Risk distance derives
   // from the position's own stop; fall back to no-arm if SL is unavailable.
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   bool reached_2r = false;
   if(pos_sl > 0.0)
     {
      if(ptype == POSITION_TYPE_BUY)
        {
         const double risk = open_price - pos_sl;
         if(risk > 0.0 && (bid - open_price) >= strategy_tp_rr * risk)
            reached_2r = true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double risk = pos_sl - open_price;
         if(risk > 0.0 && (open_price - ask) >= strategy_tp_rr * risk)
            reached_2r = true;
        }
     }
   if(!reached_2r)
      return false;

   // `exit_sma_closes` consecutive closed H1 bars beyond SMA(5) against the trade.
   for(int s = 1; s <= strategy_exit_sma_closes; ++s)
     {
      const double sma_s   = QM_SMA(_Symbol, _Period, strategy_exit_sma_period, s);
      const double close_s = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(sma_s <= 0.0 || close_s <= 0.0)
         return false;
      if(ptype == POSITION_TYPE_BUY  && !(close_s < sma_s))
         return false;
      if(ptype == POSITION_TYPE_SELL && !(close_s > sma_s))
         return false;
     }
   return true; // all required closes are beyond the SMA against the position
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
