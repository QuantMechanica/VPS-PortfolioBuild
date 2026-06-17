#property strict
#property version   "5.0"
#property description "QM5_10656 TradingView Order Block Volumatic FVG"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10656 — Order Block Volumatic FVG (TradingView, author TagsTrading)
// -----------------------------------------------------------------------------
// Mechanik (card QM5_10656_tv-ob-vol-fvg):
//   - M15 baseline. Detect bullish/bearish FVG boxes with the standard
//     three-candle imbalance rule (gap between bar[k+1] and bar[k-1]).
//   - Maintain the NEWEST still-active box per direction; track its age in
//     closed bars and the deepest mitigation reached (how far price has
//     re-entered the gap, 0..1).
//   - Arm an entry on a LATER retest bar (NOT the formation bar): box age must
//     be >= min-age, current price must intersect the active box, and
//     mitigation must reach the threshold. Volume filter (DWX tick volume):
//     total tick volume of the trigger bar >= rolling average * factor AND the
//     directional share (bull/bear body location proxy) passes. Optional candle
//     confirmation: the trigger closed bar must close in the trade direction.
//   - One position per symbol/magic (framework dedupes). Cooldown between
//     entries. Pyramiding disabled.
//   - Exit: fixed-percent stop from entry, capped at 1.5*ATR(14). Trailing stop
//     arms only after a profit trigger (QM_TM_TrailStep). No fixed TP (P2
//     baseline closes at trailing/fixed stop).
//
// Per the .DWX backtest invariants this is a "detect FVG, then arm on a later
// retest bar" design — formation and entry are on different bars, never a
// same-bar conjunction. Spread checks fail-open on zero modeled spread. No swap
// gate. QM_IsNewBar() is consumed once (framework OnTick gate); the cached
// closed-bar state is advanced inside Strategy_EntrySignal which the framework
// only calls on a fresh closed bar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10656;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- FVG detection / mitigation (card defaults) ---
input int    strategy_atr_period            = 14;      // ATR(14) for SL cap + width floor
input double strategy_fvg_min_width_atr     = 0.10;    // ignore micro-gaps below this * ATR
input int    strategy_min_fvg_age_bars      = 20;      // box must be at least this old (card default)
input int    strategy_max_fvg_age_bars      = 200;     // drop stale boxes beyond this age
input double strategy_mitigation_threshold  = 0.60;    // long & short, card default 60%
// --- Volume filter (DWX tick volume proxy) ---
input bool   strategy_volume_filter_enabled = true;
input int    strategy_volume_avg_period     = 20;      // rolling tick-volume average window
input double strategy_volume_min_factor     = 1.00;    // trigger bar tick-vol >= avg * factor
input double strategy_bull_share_min        = 0.50;    // directional close-location share floor
// --- Confirmation / cooldown ---
input bool   strategy_candle_confirmation   = true;    // trigger bar must close in trade dir
input int    strategy_cooldown_bars         = 4;       // min closed bars between entries
// --- Exit ---
input double strategy_sl_percent            = 0.75;    // fixed % stop from entry
input double strategy_sl_atr_cap_mult       = 1.50;    // cap fixed % by 1.5 * ATR(14)
input int    strategy_trail_trigger_pips    = 60;      // arm trailing only after this profit
input int    strategy_trail_step_pips       = 40;      // trail distance once armed

// File-scope closed-bar cached state. The framework advances Strategy_EntrySignal
// once per fresh closed M15 bar; we read fixed shifts (>=1) so all reads are on
// closed bars only.
static datetime g_last_entry_bar_time = 0;   // cooldown anchor (bar-open time of last entry)
static double   g_active_buy_sl_dist  = 0.0; // last computed buy SL distance (for reference)

// -----------------------------------------------------------------------------
// Helpers (file-scope, plain MQL5 — no STL/auto/nullptr).
// -----------------------------------------------------------------------------

// Tick volume of a closed bar at the given shift, as double.
double TickVolAt(const int shift)
  {
   long v = iVolume(_Symbol, PERIOD_M15, shift); // perf-allowed: closed-bar tick volume
   return (v > 0) ? (double)v : 0.0;
  }

// Rolling average tick volume over [from_shift .. from_shift+period-1].
double AvgTickVol(const int from_shift, const int period)
  {
   if(period <= 0)
      return 0.0;
   double sum = 0.0;
   int n = 0;
   for(int s = from_shift; s < from_shift + period; ++s)
     {
      double v = TickVolAt(s);
      if(v > 0.0)
        {
         sum += v;
         n++;
        }
     }
   return (n > 0) ? (sum / n) : 0.0;
  }

// Directional close-location share of a closed bar (0..1): where the close sits
// inside the bar's high-low range. ~1.0 = strong bull bar, ~0.0 = strong bear.
double BullShareAt(const int shift)
  {
   double h = iHigh(_Symbol, PERIOD_M15, shift);  // perf-allowed
   double l = iLow(_Symbol, PERIOD_M15, shift);   // perf-allowed
   double c = iClose(_Symbol, PERIOD_M15, shift); // perf-allowed
   double range = h - l;
   if(range <= 0.0)
      return 0.5;
   double share = (c - l) / range;
   if(share < 0.0)
      share = 0.0;
   if(share > 1.0)
      share = 1.0;
   return share;
  }

// Cooldown: at least strategy_cooldown_bars closed M15 bars since the last entry.
bool CooldownElapsed()
  {
   if(g_last_entry_bar_time <= 0 || strategy_cooldown_bars <= 0)
      return true;
   datetime now_bar = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: last closed bar open time
   if(now_bar <= 0)
      return true;
   int elapsed = (int)((now_bar - g_last_entry_bar_time) / PeriodSeconds(PERIOD_M15));
   return (elapsed >= strategy_cooldown_bars);
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No cheap O(1) regime/time gate beyond framework news/Friday handling.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Detect the newest still-active FVG box (scan back from old to recent so the
// last assignment is the newest), validate age/mitigation/volume/confirmation,
// and arm a market entry on this retest bar. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!CooldownElapsed())
      return false;

   const int avail = Bars(_Symbol, PERIOD_M15); // perf-allowed
   const int scan_max = strategy_max_fvg_age_bars + 4;
   const int needed = MathMax(scan_max + 2, strategy_volume_avg_period + 4);
   if(avail < needed)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double min_width = strategy_fvg_min_width_atr * atr;
   // Current price reference for "price intersects the box" and mitigation depth.
   const double px_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: last closed bar
   if(px_close <= 0.0)
      return false;

   // Newest qualifying boxes, one per direction. A three-candle FVG anchored at
   // formation-middle index m uses bar[m-1] and bar[m+1] in shift terms:
   //   bullish gap : low(m-1) > high(m+1)  -> gap = [high(m+1), low(m-1)]
   //   bearish gap : high(m-1) < low(m+1)  -> gap = [high(m-1), low(m+1)]
   // box age = m (the middle bar's shift); we require age >= min and <= max.
   // We scan from the oldest allowed middle shift down to the youngest so the
   // last match kept is the NEWEST box (card: "use the newest one").
   bool   have_bull = false;
   double bull_low = 0.0, bull_high = 0.0;
   int    bull_age = 0;
   bool   have_bear = false;
   double bear_low = 0.0, bear_high = 0.0;
   int    bear_age = 0;

   const int oldest_mid = strategy_max_fvg_age_bars;
   const int youngest_mid = MathMax(strategy_min_fvg_age_bars, 2);
   for(int m = oldest_mid; m >= youngest_mid; --m)
     {
      const double high_up = iHigh(_Symbol, PERIOD_M15, m + 1); // perf-allowed: candle before middle
      const double low_up  = iLow(_Symbol, PERIOD_M15, m + 1);  // perf-allowed
      const double low_dn  = iLow(_Symbol, PERIOD_M15, m - 1);  // perf-allowed: candle after middle
      const double high_dn = iHigh(_Symbol, PERIOD_M15, m - 1); // perf-allowed
      if(high_up <= 0.0 || low_up <= 0.0 || low_dn <= 0.0 || high_dn <= 0.0)
         continue;

      // Bullish FVG: gap between high of the older bar and low of the newer bar.
      if(low_dn > high_up)
        {
         const double g_low = high_up;
         const double g_high = low_dn;
         if((g_high - g_low) >= min_width)
           {
            // Active = not fully filled: price has not closed back through the
            // far edge (below g_low) since formation. Cheap proxy: current close
            // still at/above the gap low.
            if(px_close >= g_low)
              {
               bull_low = g_low;
               bull_high = g_high;
               bull_age = m;
               have_bull = true; // keep scanning; newer matches overwrite
              }
           }
        }

      // Bearish FVG: gap between low of the older bar and high of the newer bar.
      if(high_dn < low_up)
        {
         const double g_low = high_dn;
         const double g_high = low_up;
         if((g_high - g_low) >= min_width)
           {
            if(px_close <= g_high)
              {
               bear_low = g_low;
               bear_high = g_high;
               bear_age = m;
               have_bear = true;
              }
           }
        }
     }

   // Volume gate inputs for the trigger (last closed) bar.
   const double trig_vol = TickVolAt(1);
   const double avg_vol = AvgTickVol(2, strategy_volume_avg_period);
   const bool vol_total_ok = (!strategy_volume_filter_enabled) ||
                             (avg_vol > 0.0 && trig_vol >= avg_vol * strategy_volume_min_factor);
   const double bull_share = BullShareAt(1);

   // --- LONG setup ---
   if(have_bull && bull_age >= strategy_min_fvg_age_bars)
     {
      const double width = bull_high - bull_low;
      // Mitigation = how deep price has entered the box from its top edge,
      // measured by the current close. 0 at the top edge, 1 at the bottom edge.
      double mitig = (width > 0.0) ? ((bull_high - px_close) / width) : 0.0;
      if(mitig < 0.0)
         mitig = 0.0;
      if(mitig > 1.0)
         mitig = 1.0;
      const bool intersects = (px_close <= bull_high && px_close >= bull_low);
      const bool share_ok = (!strategy_volume_filter_enabled) || (bull_share >= strategy_bull_share_min);
      const bool confirm_ok = (!strategy_candle_confirmation) ||
                              (iClose(_Symbol, PERIOD_M15, 1) > iOpen(_Symbol, PERIOD_M15, 1)); // perf-allowed
      if(intersects && mitig >= strategy_mitigation_threshold &&
         vol_total_ok && share_ok && confirm_ok)
        {
         const double entry = ask;
         double sl_dist = strategy_sl_percent * 0.01 * entry;
         const double atr_cap = strategy_sl_atr_cap_mult * atr;
         if(atr_cap > 0.0 && sl_dist > atr_cap)
            sl_dist = atr_cap;
         if(sl_dist > 0.0)
           {
            const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, sl_dist);
            if(sl > 0.0 && sl < entry)
              {
               req.type = QM_BUY;
               req.price = 0.0;          // framework fills market
               req.sl = sl;
               req.tp = 0.0;             // exit via fixed/trailing stop only
               req.reason = "tv-ob-vol-fvg-long";
               req.symbol_slot = qm_magic_slot_offset;
               g_active_buy_sl_dist = sl_dist;
               g_last_entry_bar_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed
               return true;
              }
           }
        }
     }

   // --- SHORT setup (mirror) ---
   if(have_bear && bear_age >= strategy_min_fvg_age_bars)
     {
      const double width = bear_high - bear_low;
      // Mitigation from the box bottom edge upward: 0 at bottom, 1 at top.
      double mitig = (width > 0.0) ? ((px_close - bear_low) / width) : 0.0;
      if(mitig < 0.0)
         mitig = 0.0;
      if(mitig > 1.0)
         mitig = 1.0;
      const bool intersects = (px_close <= bear_high && px_close >= bear_low);
      const double bear_share = 1.0 - bull_share;
      const bool share_ok = (!strategy_volume_filter_enabled) || (bear_share >= strategy_bull_share_min);
      const bool confirm_ok = (!strategy_candle_confirmation) ||
                              (iClose(_Symbol, PERIOD_M15, 1) < iOpen(_Symbol, PERIOD_M15, 1)); // perf-allowed
      if(intersects && mitig >= strategy_mitigation_threshold &&
         vol_total_ok && share_ok && confirm_ok)
        {
         const double entry = bid;
         double sl_dist = strategy_sl_percent * 0.01 * entry;
         const double atr_cap = strategy_sl_atr_cap_mult * atr;
         if(atr_cap > 0.0 && sl_dist > atr_cap)
            sl_dist = atr_cap;
         if(sl_dist > 0.0)
           {
            const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry, sl_dist);
            if(sl > entry)
              {
               req.type = QM_SELL;
               req.price = 0.0;
               req.sl = sl;
               req.tp = 0.0;
               req.reason = "tv-ob-vol-fvg-short";
               req.symbol_slot = qm_magic_slot_offset;
               g_active_buy_sl_dist = sl_dist;
               g_last_entry_bar_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed
               return true;
              }
           }
        }
     }

   return false;
  }

// Trailing stop arms only after the profit trigger (card: "trailing stop
// activates only after a configured profit trigger"). QM_TM_TrailStep is a
// no-op until price has moved trigger_pips in favour, then trails by step_pips.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_trail_trigger_pips <= 0 || strategy_trail_step_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_step_pips);
     }
  }

// No discretionary exit beyond the fixed/trailing stop handled by SL + trade
// management. Returning false leaves SL/trail in charge.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: defer to the framework two-axis news filter.
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
