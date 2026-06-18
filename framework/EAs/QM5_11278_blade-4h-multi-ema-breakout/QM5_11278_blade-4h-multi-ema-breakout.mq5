#property strict
#property version   "5.0"
#property description "QM5_11278 blade-4h-multi-ema-breakout — Blade 4H Multi-EMA Breakout-Retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11278 blade-4h-multi-ema-breakout
// -----------------------------------------------------------------------------
// Source: "The Blade Forex Strategies" — ForexSuccessSecrets.com PDF,
//         "4H Breakout System" (pp. 26-50). source_id e78a9f1f-...
// Card  : artifacts/cards_approved/QM5_11278_blade-4h-multi-ema-breakout.md
//         (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; .DWX gapless H4 CFDs):
//   The multi-EMA STACK ALIGNMENT is a regime STATE; the breakout is the single
//   EVENT. We never require two fresh events on the same bar (DWX invariant #4).
//
//   Trend STATE   : EMA(30) sloping up over slope_bars (ema30[1] > ema30[slope])
//                   AND last closed price above EMA(30).
//   Stack STATE   : the 150/200/365 EMAs are aligned with the trend, acting as
//                   the dynamic S/R zone (long: ema150 > ema200 > ema365; mirror
//                   for short). This is the "multi-EMA stack" alignment STATE.
//   Consolidation : a prior N-bar extreme that price has been coiling under/over.
//                   The broken level = highest high (long) / lowest low (short)
//                   over [shift 2 .. break_lookback+1], i.e. EXCLUDING the
//                   trigger bar itself.
//   Breakout EVENT: the single trigger. On a GAPLESS CFD open[0]==close[1], so
//                   we test the PRIOR CLOSE, not an intrabar range:
//                     long : close[1] > broken_level  AND  close[2] <= broken_level
//                   (a fresh close-through on the just-closed bar). The large-body
//                   qualifier (range > ATR*body_mult) approximates the volume
//                   spike from the card.
//   Retest STATE  : price has pulled back near the broken level — the just-closed
//                   bar's low (long) is within atr*retest_band of broken_level,
//                   so we buy the retest of the broken S/R, not a runaway bar.
//   Stop          : structure stop behind the broken level (lookback low/high),
//                   floored to >= sl_floor_pips behind entry (card: 20-25 pips).
//   Management    : break-even at +1R; then ATR(14)*trail_mult trailing stop.
//   Exit          : EMA(30) flips against the position (defensive trend exit).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11278;
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
input int    strategy_ema_trend_period   = 30;    // EMA(30) trend-direction gauge (green)
input int    strategy_ema_mid_period     = 150;   // EMA(150) dynamic S/R (orange)
input int    strategy_ema_long_period    = 200;   // EMA(200) dynamic S/R (blue)
input int    strategy_ema_max_period     = 365;   // EMA(365) dynamic S/R (red)
input int    strategy_ema_slope_bars     = 5;     // bars back to gauge EMA(30) slope
input int    strategy_break_lookback     = 12;    // consolidation window for the broken S/R level
input int    strategy_atr_period         = 14;    // ATR(14): breakout body + retest band + trail
input double strategy_break_body_mult    = 1.0;   // breakout bar range > ATR * this (volume-spike proxy)
input double strategy_retest_band_atr    = 0.30;  // retest within ATR * this of broken level
input int    strategy_sl_struct_lookback = 6;     // structure-stop lookback (behind broken S/R)
input int    strategy_sl_floor_pips      = 25;    // min stop distance behind entry (card: 20-25 pips)
input double strategy_be_trigger_r       = 1.0;   // move SL to break-even at +this * initial risk
input double strategy_trail_atr_mult     = 1.5;   // ATR(14) trailing-stop multiple (card P3)
input double strategy_spread_pct_of_stop = 20.0;  // skip if spread > this % of stop distance

// =============================================================================
// Strategy hooks
// =============================================================================

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = atr_value; // reference scale for the spread cap
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Long and short, mirror logic. One position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA stack (closed bar, shift 1) ---
   const double ema_trend  = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   const double ema_trend5 = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, strategy_ema_slope_bars);
   const double ema_mid    = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_long   = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 1);
   const double ema_max    = QM_EMA(_Symbol, _Period, strategy_ema_max_period, 1);
   if(ema_trend <= 0.0 || ema_trend5 <= 0.0 || ema_mid <= 0.0 || ema_long <= 0.0 || ema_max <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Just-closed bar OHLC (shift 1) and prior bar close (shift 2).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // Large-body breakout-bar qualifier (volume-spike proxy from the card).
   const double bar_range = high1 - low1;
   const bool   big_body  = (bar_range > strategy_break_body_mult * atr_value);

   // Consolidation extremes over the window PRECEDING the trigger bar
   // (shifts 2 .. break_lookback+1) — the broken S/R level.
   double level_high = -DBL_MAX;
   double level_low  =  DBL_MAX;
   const int first_shift = 2;
   const int last_shift  = strategy_break_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded consolidation scan, gated by QM_IsNewBar
      const double l = iLow(_Symbol, _Period, s);  // perf-allowed: bounded consolidation scan, gated by QM_IsNewBar
      if(h > 0.0 && h > level_high) level_high = h;
      if(l > 0.0 && l < level_low)  level_low  = l;
     }
   if(level_high <= 0.0 || level_low <= 0.0 || level_high <= level_low)
      return false;

   // ---------------- LONG ----------------
   // Trend STATE: EMA(30) sloping up + price above EMA(30).
   // Stack STATE: ema150 > ema200 > ema365 (bullish dynamic S/R alignment).
   const bool long_trend = (ema_trend > ema_trend5) && (close1 > ema_trend);
   const bool long_stack = (ema_mid > ema_long) && (ema_long > ema_max);
   // Breakout EVENT (single trigger): fresh close-through of the broken high.
   const bool long_break = (close1 > level_high) && (close2 <= level_high);
   // Retest STATE: just-closed bar pulled back near the broken level.
   const bool long_retest = (low1 <= level_high + strategy_retest_band_atr * atr_value);

   if(long_trend && long_stack && long_break && long_retest && big_body)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Structure stop behind the broken S/R, floored to sl_floor_pips.
      double sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_sl_struct_lookback);
      const double floor_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_floor_pips);
      const double floor_sl   = entry - floor_dist;
      if(sl <= 0.0 || sl > floor_sl)
         sl = floor_sl; // ensure at least the pip floor behind entry
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — ride trend via BE + ATR trail
      req.reason = "blade_breakout_long";
      return true;
     }

   // ---------------- SHORT ----------------
   const bool short_trend = (ema_trend < ema_trend5) && (close1 < ema_trend);
   const bool short_stack = (ema_mid < ema_long) && (ema_long < ema_max);
   const bool short_break = (close1 < level_low) && (close2 >= level_low);
   const bool short_retest = (high1 >= level_low - strategy_retest_band_atr * atr_value);

   if(short_trend && short_stack && short_break && short_retest && big_body)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_sl_struct_lookback);
      const double floor_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_floor_pips);
      const double floor_sl   = entry + floor_dist;
      if(sl <= 0.0 || sl < floor_sl)
         sl = floor_sl;
      if(sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "blade_breakout_short";
      return true;
     }

   return false;
  }

// Active management: break-even at +1R, then ATR(14)*trail_mult trailing stop.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Break-even when in profit by 1 * initial risk (entry-to-SL distance).
      const double entry   = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl       = PositionGetDouble(POSITION_SL);
      if(entry > 0.0 && sl > 0.0)
        {
         const double risk_dist = MathAbs(entry - sl);
         if(risk_dist > 0.0)
           {
            const int trigger_pips = (int)MathRound(strategy_be_trigger_r * risk_dist /
                                       QM_StopRulesPipsToPriceDistance(_Symbol, 1));
            if(trigger_pips > 0)
               QM_TM_MoveToBreakEven(ticket, trigger_pips, 2);
           }
        }

      // ATR trailing stop (card: ATR(14) * 1.5).
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Defensive exit: EMA(30) flips against the open position (trend gone).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double ema_trend  = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
      const double ema_trend5 = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, strategy_ema_slope_bars);
      if(ema_trend <= 0.0 || ema_trend5 <= 0.0)
         return false;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      // Long held but EMA(30) now sloping down -> trend defensive exit.
      if(ptype == POSITION_TYPE_BUY && ema_trend < ema_trend5)
         return true;
      // Short held but EMA(30) now sloping up -> trend defensive exit.
      if(ptype == POSITION_TYPE_SELL && ema_trend > ema_trend5)
         return true;
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11278\",\"ea\":\"blade-4h-multi-ema-breakout\"}");
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
