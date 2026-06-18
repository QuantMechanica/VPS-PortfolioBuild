#property strict
#property version   "5.0"
#property description "QM5_1390 williams-percent-r-divergence-h4 — Larry Williams %R regular-divergence reversal (H4)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1390 williams-percent-r-divergence-h4
// -----------------------------------------------------------------------------
// Source: forexfactory-trading-systems cluster + Larry Williams, "How I Made One
//   Million Dollars..." (Windsor 1973) / "Long-Term Secrets to Short-Term
//   Trading" (Wiley 2011, ISBN 978-0-470-91571-7) ch.7 (%R divergence).
// Card: artifacts/cards_approved/QM5_1390_williams-percent-r-divergence-h4.md
//   (g0_status APPROVED). BUILD TARGET ea_id = 1390. Card frontmatter says
//   ea_id: QM5_12169 — STALE; qm_ea_id forced to 1390 per build task; flagged.
//
// Strategy (H4, closed-bar reads; shift 1 = last closed bar). REGULAR DIVERGENCE
// reversal: price makes a new extreme but Williams %R(14) does not.
//
//   Bearish (SELL): two 5-bar swing-highs j1 (earlier) and j2 (later),
//     separated 4..24 H4 bars; high[j2] > high[j1] (price higher-high) while
//     WPR[j2] < WPR[j1] (%R lower-high = less overbought = divergence); both
//     WPR in OB zone (> -20); WPR divergence >= 10 pts; price higher-high
//     >= 0.5*ATR_D1; reversal bar[1] is a bear bar with body_ratio >= 0.45 and
//     close[1] < high[j2] - 1.0*ATR_H4; bar-2 confirm (close[1]<close[2] AND
//     close[1]<open[2]); SMA(200) soft regime filter; volatility gate; spread.
//   Bullish (BUY): mirror with 5-bar swing-lows, low[j2] < low[j1],
//     WPR[j2] > WPR[j1], both WPR in OS zone (< -80), etc.
//
//   The DIVERGENCE CONFIRMATION on the just-closed bar[1] is the SINGLE trigger
//   EVENT. Swing-pair geometry, %R magnitudes, regime/vol gates are STATES on
//   the same closed bar.
//
//   SL  : SELL = high[j2] + 0.5*ATR_H4 ; BUY = low[j2] - 0.5*ATR_H4.
//   TP  : SELL = high[j2] - 3.0*ATR_H4 ; BUY = low[j2] + 3.0*ATR_H4.
//   Mgmt: partial-TP 50% at 1.5*ATR_H4 in favour + move remaining SL to BE.
//   Exit: %R-recovery pattern-invalidation; time-stop at 30 H4 bars.
//
//   Spread : skip only a genuinely wide spread (fail-open on .DWX zero spread).
//   Session: only enter on H4 bars whose CLOSE falls in 07:00..21:00 broker.
//   News   : central two-axis framework filter.
//
// SWING / DIVERGENCE detection is bespoke structural logic with no framework
// helper, so raw iHigh/iLow/iOpen/iClose closed-bar reads are perf-allowed.
// They run ONLY inside the QM_IsNewBar-gated entry/exit path (O(window) once
// per closed bar, window <= 35 bars — well within the smoke budget).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1390;
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
input int    strategy_wpr_period        = 14;    // Williams %R period
input int    strategy_swing_window       = 5;     // 5-bar swing detection window (W)
input int    strategy_sep_min            = 4;     // min H4-bar separation between j1,j2
input int    strategy_sep_max            = 24;    // max H4-bar separation between j1,j2
input double strategy_wpr_ob             = -20.0; // overbought line (SELL zone)
input double strategy_wpr_os             = -80.0; // oversold line (BUY zone)
input double strategy_wpr_div_min        = 10.0;  // min %R divergence (points)
input double strategy_price_atrd1_mult   = 0.5;   // price higher-high >= mult*ATR_D1
input int    strategy_atr_h4_period      = 14;    // H4 ATR period (SL/TP/vol)
input int    strategy_atr_d1_period      = 14;    // D1 ATR period (swing significance)
input double strategy_body_ratio_min     = 0.45;  // reversal-bar min body ratio
input double strategy_confirm_atr_mult   = 1.0;   // close[1] beyond extreme by mult*ATR_H4
input int    strategy_sma_macro_period   = 200;   // SMA(200) soft regime filter
input double strategy_sma_regime_atr_mult = 5.0;  // regime band width (mult*ATR_H4)
input double strategy_vol_gate_ratio     = 0.7;   // ATR[1] >= ratio*ATR[20]
input int    strategy_vol_gate_lookback  = 20;    // ATR ratio lookback (bars)
input double strategy_sl_atr_mult        = 0.5;   // SL beyond divergence-extreme
input double strategy_tp_atr_mult        = 3.0;   // TP from divergence-extreme
input double strategy_partial_atr_mult   = 1.5;   // partial-TP trigger (in favour)
input double strategy_partial_fraction   = 0.5;   // fraction closed at partial-TP
input double strategy_recovery_atr_mult  = 0.5;   // %R-recovery proximity to extreme
input int    strategy_time_stop_bars     = 30;    // hard time-stop (H4 bars)
input int    strategy_session_start_h     = 7;    // session open (broker hour)
input int    strategy_session_end_h       = 21;   // session close (broker hour)
input double strategy_spread_pct_of_stop = 40.0;  // skip if spread > this % of SL distance

// File-scope: the divergence-extreme price recorded at the live entry, so the
// per-bar exit (%R-recovery + partial-TP) can reference it without re-detection.
double g_div_extreme = 0.0;   // high[j2] for SELL, low[j2] for BUY
bool   g_be_done     = false; // partial-TP + break-even applied this trade

// -----------------------------------------------------------------------------
// Helpers (closed-bar structural math — perf-allowed bespoke logic)
// -----------------------------------------------------------------------------

// 5-bar swing-high anchor at shift s: high[s] = max(high[s..s+W-1]) AND
// high[s] > high[s+W..s+2W-1] (highest of its W-window AND of the preceding
// W-window). Mirrors the card's canonical 5-bar swing definition.
bool IsSwingHigh(const int s, const int w)
  {
   const double h = iHigh(_Symbol, _Period, s);
   if(h <= 0.0)
      return false;
   for(int k = s + 1; k <= s + w - 1; ++k)
      if(iHigh(_Symbol, _Period, k) > h)
         return false;
   for(int k2 = s + w; k2 <= s + 2 * w - 1; ++k2)
      if(iHigh(_Symbol, _Period, k2) >= h)
         return false;
   return true;
  }

bool IsSwingLow(const int s, const int w)
  {
   const double l = iLow(_Symbol, _Period, s);
   if(l <= 0.0)
      return false;
   for(int k = s + 1; k <= s + w - 1; ++k)
      if(iLow(_Symbol, _Period, k) < l)
         return false;
   for(int k2 = s + w; k2 <= s + 2 * w - 1; ++k2)
      if(iLow(_Symbol, _Period, k2) <= l)
         return false;
   return true;
  }

double BodyRatio(const int s)
  {
   const double o = iOpen(_Symbol, _Period, s);
   const double c = iClose(_Symbol, _Period, s);
   const double h = iHigh(_Symbol, _Period, s);
   const double l = iLow(_Symbol, _Period, s);
   return MathAbs(c - o) / (h - l + 1e-9);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + wide-spread guard.
// Returns TRUE to BLOCK. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   // Session gate in BROKER time — only trade EU/US-equity hours (07:00..21:00).
   if(QM_Sig_Session(TimeCurrent(), strategy_session_start_h, strategy_session_end_h) == 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer

   const double atr_h4 = QM_ATR(_Symbol, _Period, strategy_atr_h4_period, 1);
   if(atr_h4 <= 0.0)
      return false;
   const double sl_distance = strategy_sl_atr_mult * atr_h4;
   if(sl_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only block a genuinely wide spread; .DWX models 0 spread -> never blocks.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * sl_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (HR14, 1-pos-per-symbol).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int    w        = strategy_swing_window;
   const double atr_h4   = QM_ATR(_Symbol, _Period, strategy_atr_h4_period, 1);
   const double atr_h4_b = QM_ATR(_Symbol, _Period, strategy_atr_h4_period,
                                  1 + strategy_vol_gate_lookback);
   const double atr_d1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_d1_period, 1);
   if(atr_h4 <= 0.0 || atr_h4_b <= 0.0 || atr_d1 <= 0.0)
      return false;

   // Volatility gate: current ATR not collapsed vs lookback.
   if(atr_h4 < strategy_vol_gate_ratio * atr_h4_b)
      return false;

   const double sma200 = QM_SMA(_Symbol, _Period, strategy_sma_macro_period, 1);
   if(sma200 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double open2  = iOpen(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || open2 <= 0.0)
      return false;

   // Scan window: a swing point needs w bars ahead + w bars behind it, and the
   // later extreme j2 sits >= sep_min bars back. Bound the search to sep_max.
   // Earliest swing shift we can fully evaluate = sep_max + (2w-1).
   const int max_shift = strategy_sep_max + 2 * w - 1;
   // Guard history availability cheaply via the deepest read.
   if(iHigh(_Symbol, _Period, max_shift + 1) <= 0.0)
      return false;

   // ----------------------------- SELL (bearish divergence) -----------------
     {
      // Find the LATER swing-high j2 (smallest valid shift >= sep_min).
      int j2 = -1;
      for(int s = strategy_sep_min; s <= strategy_sep_max && j2 < 0; ++s)
         if(IsSwingHigh(s, w))
            j2 = s;
      if(j2 >= 0)
        {
         // Find the EARLIER swing-high j1 with j1 - j2 in [sep_min, sep_max].
         int j1 = -1;
         const int j1_lo = j2 + strategy_sep_min;
         int j1_hi = j2 + strategy_sep_max;
         if(j1_hi > max_shift) j1_hi = max_shift;
         for(int s = j1_lo; s <= j1_hi && j1 < 0; ++s)
            if(IsSwingHigh(s, w))
               j1 = s;
         if(j1 >= 0)
           {
            const double high_j1 = iHigh(_Symbol, _Period, j1);
            const double high_j2 = iHigh(_Symbol, _Period, j2);
            const double wpr_j1  = QM_WPR(_Symbol, _Period, strategy_wpr_period, j1);
            const double wpr_j2  = QM_WPR(_Symbol, _Period, strategy_wpr_period, j2);
            const bool   wpr_valid = (wpr_j1 >= -100.0 && wpr_j1 <= 0.0 &&
                                      wpr_j2 >= -100.0 && wpr_j2 <= 0.0);

            const bool price_hh   = (high_j2 > high_j1);
            const bool wpr_lh     = (wpr_j2 < wpr_j1);                  // divergence
            const bool both_ob    = (wpr_j1 > strategy_wpr_ob && wpr_j2 > strategy_wpr_ob);
            const bool div_mag    = ((wpr_j1 - wpr_j2) >= strategy_wpr_div_min);
            const bool price_mag  = ((high_j2 - high_j1) >= strategy_price_atrd1_mult * atr_d1);
            const bool rev_bar    = (BodyRatio(1) >= strategy_body_ratio_min &&
                                     close1 < iOpen(_Symbol, _Period, 1) &&  // bear bar
                                     close1 < high_j2 - strategy_confirm_atr_mult * atr_h4);
            const bool bar2_conf  = (close1 < close2 && close1 < open2);
            // SMA(200) hard soft-filter: NOT in a deep bear regime.
            const bool regime_ok  = (close1 > sma200 - strategy_sma_regime_atr_mult * atr_h4);

            if(wpr_valid && price_hh && wpr_lh && both_ob && div_mag && price_mag &&
               rev_bar && bar2_conf && regime_ok)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(entry <= 0.0)
                  return false;
               double sl = QM_StopRulesNormalizePrice(_Symbol,
                              high_j2 + strategy_sl_atr_mult * atr_h4);
               double tp = QM_StopRulesNormalizePrice(_Symbol,
                              high_j2 - strategy_tp_atr_mult * atr_h4);
               if(sl <= entry || tp <= 0.0 || tp >= entry)
                  return false;
               req.type   = QM_SELL;
               req.price  = 0.0;
               req.sl     = sl;
               req.tp     = tp;
               req.reason = "wpr_div_short";
               g_div_extreme = high_j2;
               g_be_done     = false;
               return true;
              }
           }
        }
     }

   // ----------------------------- BUY (bullish divergence) ------------------
     {
      int j2 = -1;
      for(int s = strategy_sep_min; s <= strategy_sep_max && j2 < 0; ++s)
         if(IsSwingLow(s, w))
            j2 = s;
      if(j2 >= 0)
        {
         int j1 = -1;
         const int j1_lo = j2 + strategy_sep_min;
         int j1_hi = j2 + strategy_sep_max;
         if(j1_hi > max_shift) j1_hi = max_shift;
         for(int s = j1_lo; s <= j1_hi && j1 < 0; ++s)
            if(IsSwingLow(s, w))
               j1 = s;
         if(j1 >= 0)
           {
            const double low_j1 = iLow(_Symbol, _Period, j1);
            const double low_j2 = iLow(_Symbol, _Period, j2);
            const double wpr_j1 = QM_WPR(_Symbol, _Period, strategy_wpr_period, j1);
            const double wpr_j2 = QM_WPR(_Symbol, _Period, strategy_wpr_period, j2);
            const bool   wpr_valid = (wpr_j1 >= -100.0 && wpr_j1 <= 0.0 &&
                                      wpr_j2 >= -100.0 && wpr_j2 <= 0.0);

            const bool price_ll   = (low_j2 < low_j1);
            const bool wpr_hl     = (wpr_j2 > wpr_j1);                  // divergence
            const bool both_os    = (wpr_j1 < strategy_wpr_os && wpr_j2 < strategy_wpr_os);
            const bool div_mag    = ((wpr_j2 - wpr_j1) >= strategy_wpr_div_min);
            const bool price_mag  = ((low_j1 - low_j2) >= strategy_price_atrd1_mult * atr_d1);
            const bool rev_bar    = (BodyRatio(1) >= strategy_body_ratio_min &&
                                     close1 > iOpen(_Symbol, _Period, 1) &&  // bull bar
                                     close1 > low_j2 + strategy_confirm_atr_mult * atr_h4);
            const bool bar2_conf  = (close1 > close2 && close1 > open2);
            const bool regime_ok  = (close1 < sma200 + strategy_sma_regime_atr_mult * atr_h4);

            if(wpr_valid && price_ll && wpr_hl && both_os && div_mag && price_mag &&
               rev_bar && bar2_conf && regime_ok)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(entry <= 0.0)
                  return false;
               double sl = QM_StopRulesNormalizePrice(_Symbol,
                              low_j2 - strategy_sl_atr_mult * atr_h4);
               double tp = QM_StopRulesNormalizePrice(_Symbol,
                              low_j2 + strategy_tp_atr_mult * atr_h4);
               if(sl >= entry || tp <= entry)
                  return false;
               req.type   = QM_BUY;
               req.price  = 0.0;
               req.sl     = sl;
               req.tp     = tp;
               req.reason = "wpr_div_long";
               g_div_extreme = low_j2;
               g_be_done     = false;
               return true;
              }
           }
        }
     }

   return false;
  }

// Partial-TP at 1.5*ATR in favour: close `partial_fraction` and move SL on the
// remainder to break-even. Runs per tick on the open position for this magic.
void Strategy_ManageOpenPosition()
  {
   if(g_be_done)
      return;
   const int magic = QM_FrameworkMagic();
   const double atr_h4 = QM_ATR(_Symbol, _Period, strategy_atr_h4_period, 1);
   if(atr_h4 <= 0.0)
      return;
   const double trigger = strategy_partial_atr_mult * atr_h4;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long   ptype = PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double vol   = PositionGetDouble(POSITION_VOLUME);
      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - entry >= trigger)
           {
            QM_TM_PartialClose(ticket, strategy_partial_fraction * vol, QM_EXIT_STRATEGY);
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry), "partial_be");
            g_be_done = true;
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry - ask >= trigger)
           {
            QM_TM_PartialClose(ticket, strategy_partial_fraction * vol, QM_EXIT_STRATEGY);
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry), "partial_be");
            g_be_done = true;
           }
        }
      break;
     }
  }

// Exits (per closed bar), whichever fires first:
//   - %R-recovery pattern-invalidation: %R returns to OB (SELL) / OS (BUY) AND
//     price back near the divergence-extreme — reversal has failed.
//   - time-stop: position older than time_stop_bars H4 bars.
// Fixed SL/TP and the partial-TP/BE handle the rest.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool     is_long  = false;
   bool     is_short = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!is_long && !is_short)
      return false;

   // Time-stop (H4 bars elapsed since entry).
   const int period_secs = PeriodSeconds(_Period);
   if(period_secs > 0 && open_time > 0)
     {
      const int bars_in_trade = (int)((TimeCurrent() - open_time) / period_secs);
      if(bars_in_trade >= strategy_time_stop_bars)
         return true;
     }

   const double wpr1   = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double atr_h4 = QM_ATR(_Symbol, _Period, strategy_atr_h4_period, 1);
   if(wpr1 < -100.0 || wpr1 > 0.0 || close1 <= 0.0 || atr_h4 <= 0.0 ||
      g_div_extreme <= 0.0)
      return false;
   const double prox = strategy_recovery_atr_mult * atr_h4;

   if(is_short)
     {
      // %R back to overbought near the divergence-high -> reversal failed.
      if(wpr1 > strategy_wpr_ob && close1 > g_div_extreme - prox)
         return true;
     }
   else // is_long
     {
      if(wpr1 < strategy_wpr_os && close1 < g_div_extreme + prox)
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
