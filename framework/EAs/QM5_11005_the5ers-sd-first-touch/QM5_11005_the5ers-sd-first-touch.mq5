#property strict
#property version   "5.0"
#property description "QM5_11005 the5ers-sd-first-touch — Supply/Demand fresh-zone first-touch rejection (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11005 the5ers-sd-first-touch
// -----------------------------------------------------------------------------
// Source: The5ers blog "The Difference Between Supply & Demand and Support &
//         Resistance" (The5ers Team, updated 2022-07-14).
// Card: artifacts/cards_approved/QM5_11005_the5ers-sd-first-touch.md (APPROVED).
//
// Mechanics (closed-bar reads at shift>=1, H1):
//   Fresh DEMAND zone: a "base" of 1..4 consecutive candles whose total
//     high-low range <= base_atr_mult * ATR, followed within depart_window
//     candles by a close that exceeds the base HIGH by >= impulse_atr_mult*ATR
//     (impulsive bullish departure). Zone bounds = [base_low, base_high].
//   Fresh SUPPLY zone: symmetric — small-range base then a close BELOW the base
//     LOW by >= impulse_atr_mult*ATR (impulsive bearish departure).
//   First-touch LONG: the closed bar [1] is the FIRST return to a fresh demand
//     zone since creation AND rejects it: low[1] <= zone_high && close[1] > zone_high.
//   First-touch SHORT: low/high symmetric — high[1] >= zone_low &&
//     close[1] < zone_low, first touch of a fresh supply zone.
//   Zone freshness: invalidated if any bar between creation and the trigger bar
//     already entered the zone (first-touch only), or if older than
//     zone_max_age_bars closed bars (~20 trading days of H1).
//   Stop : LONG = zone_low - sl_atr_buffer_mult*ATR ; SHORT = zone_high + buffer.
//   Take : fixed take_rr R multiple of the initial stop distance.
//   Exit : (a) close beyond the OPPOSITE side of the originating zone before TP;
//          (b) time stop after max_hold_bars closed bars.
//
// Determinism: zone detection is a bounded backward scan over a fixed lookback
// window, evaluated ONCE per closed bar. No discretion, no ML, one position per
// magic. All bar reads are closed bars (shift >= 1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11005;
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
input int    strategy_atr_period        = 14;     // ATR(H1,14) for base/impulse/stop scaling
input int    strategy_base_max_candles  = 4;      // max candles in the consolidation base (1..4)
input double strategy_base_atr_mult     = 1.2;    // base total range must be <= mult * ATR
input int    strategy_depart_window     = 3;      // departure must occur within N candles after base
input double strategy_impulse_atr_mult  = 1.5;    // departure close must exceed base edge by mult*ATR
input int    strategy_zone_max_age_bars = 480;    // zone invalid if older than N closed bars (~20 trading days H1)
input double strategy_sl_atr_buffer_mult = 0.25;  // stop placed buffer*ATR beyond the zone edge
input double strategy_take_rr           = 2.0;    // take profit at this R multiple
input int    strategy_max_hold_bars     = 48;     // time stop: close after N closed bars
input int    strategy_scan_lookback     = 500;    // bounded backward scan window (closed bars)

// -----------------------------------------------------------------------------
// File-scope state for the OPEN position's originating zone (for exits).
// Set when we open; cleared when flat. Advanced/read only on the closed-bar gate.
// -----------------------------------------------------------------------------
double   g_open_zone_low      = 0.0;   // originating zone low  (for the open position)
double   g_open_zone_high     = 0.0;   // originating zone high (for the open position)
bool     g_open_is_long       = false; // direction of the open position
datetime g_open_entry_bar     = 0;     // bar-open time of the entry bar (for time stop)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No regime/session filter for this card; entry work
// is on the closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Detect a fresh DEMAND zone whose departure bar is at shift `depart_shift`,
// with the base immediately preceding it. Returns true and fills bounds if a
// valid impulsive bullish departure forms here. `atr_value` is ATR at the
// trigger (shift 1) used to scale base/impulse thresholds.
bool DetectDemandZone(const int depart_shift, const double atr_value,
                      double &zone_low, double &zone_high, int &base_first_shift)
  {
   // Try base sizes 1..base_max_candles. Base candles sit at the shifts
   // immediately OLDER than (i.e. larger shift than) the departure bar.
   for(int base_len = 1; base_len <= strategy_base_max_candles; ++base_len)
     {
      const int base_newest = depart_shift + 1;            // closest base bar to departure
      const int base_oldest = depart_shift + base_len;     // furthest base bar
      if(base_oldest + strategy_atr_period + 2 >= strategy_scan_lookback)
         return false; // not enough history within the scan window

      double bhigh = -1.0, blow = 1e18;
      for(int s = base_newest; s <= base_oldest; ++s)
        {
         const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar scan
         const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
         if(hi <= 0.0 || lo <= 0.0)
            return false;
         if(hi > bhigh) bhigh = hi;
         if(lo < blow)  blow  = lo;
        }
      const double base_range = bhigh - blow;
      if(base_range <= 0.0)
         continue;
      if(base_range > strategy_base_atr_mult * atr_value)
         continue; // base not a tight consolidation for this length

      // Impulsive bullish departure: close at depart_shift exceeds base high by
      // >= impulse_atr_mult * ATR.
      const double dep_close = iClose(_Symbol, _Period, depart_shift); // perf-allowed
      if(dep_close <= 0.0)
         continue;
      if(dep_close - bhigh < strategy_impulse_atr_mult * atr_value)
         continue;

      zone_low  = blow;
      zone_high = bhigh;
      base_first_shift = base_oldest;
      return true;
     }
   return false;
  }

// Symmetric fresh SUPPLY zone: tight base then an impulsive bearish departure
// (close below base low by >= impulse_atr_mult * ATR).
bool DetectSupplyZone(const int depart_shift, const double atr_value,
                      double &zone_low, double &zone_high, int &base_first_shift)
  {
   for(int base_len = 1; base_len <= strategy_base_max_candles; ++base_len)
     {
      const int base_newest = depart_shift + 1;
      const int base_oldest = depart_shift + base_len;
      if(base_oldest + strategy_atr_period + 2 >= strategy_scan_lookback)
         return false;

      double bhigh = -1.0, blow = 1e18;
      for(int s = base_newest; s <= base_oldest; ++s)
        {
         const double hi = iHigh(_Symbol, _Period, s); // perf-allowed
         const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
         if(hi <= 0.0 || lo <= 0.0)
            return false;
         if(hi > bhigh) bhigh = hi;
         if(lo < blow)  blow  = lo;
        }
      const double base_range = bhigh - blow;
      if(base_range <= 0.0)
         continue;
      if(base_range > strategy_base_atr_mult * atr_value)
         continue;

      const double dep_close = iClose(_Symbol, _Period, depart_shift); // perf-allowed
      if(dep_close <= 0.0)
         continue;
      if(blow - dep_close < strategy_impulse_atr_mult * atr_value)
         continue;

      zone_low  = blow;
      zone_high = bhigh;
      base_first_shift = base_oldest;
      return true;
     }
   return false;
  }

// True if the closed bars strictly between the departure bar and the trigger
// bar [1] never entered the demand zone (i.e. bar low never reached the zone
// high). Ensures bar [1] is the FIRST touch. `pre_trigger_shift` = depart_shift-1
// down to 2 are the "since creation, before trigger" bars.
bool DemandUntouchedBeforeTrigger(const int depart_shift, const double zone_high)
  {
   for(int s = depart_shift - 1; s >= 2; --s)
     {
      const double lo = iLow(_Symbol, _Period, s); // perf-allowed
      if(lo <= 0.0)
         return false;
      if(lo <= zone_high)
         return false; // an earlier bar already touched the zone -> not first touch
     }
   return true;
  }

// Symmetric for supply: no earlier bar's high reached the zone low.
bool SupplyUntouchedBeforeTrigger(const int depart_shift, const double zone_low)
  {
   for(int s = depart_shift - 1; s >= 2; --s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed
      if(hi <= 0.0)
         return false;
      if(hi >= zone_low)
         return false;
     }
   return true;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: trigger-bar reads
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   // The departure bar must be old enough to leave room for a base + age check,
   // and young enough to be within zone_max_age_bars. The smallest departure
   // shift is 2 (base at shift>=3, trigger at shift 1). Scan from newest fresh
   // zone outward; take the FIRST (most recent) valid first-touch setup.
   const int max_depart = MathMin(strategy_zone_max_age_bars, strategy_scan_lookback - strategy_atr_period - 4);

   for(int depart_shift = 2; depart_shift <= max_depart; ++depart_shift)
     {
      double zlow = 0.0, zhigh = 0.0;
      int    base_first = 0;

      // --- DEMAND / LONG ---
      if(DetectDemandZone(depart_shift, atr_value, zlow, zhigh, base_first))
        {
         // First-touch rejection on the trigger bar [1]:
         //   low[1] dipped into the zone (<= zone_high) and close[1] rejected up
         //   back above zone_high.
         if(low1 <= zhigh && close1 > zhigh &&
            DemandUntouchedBeforeTrigger(depart_shift, zhigh))
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                  zlow - strategy_sl_atr_buffer_mult * atr_value);
            if(sl <= 0.0 || sl >= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_rr);
            if(tp <= 0.0)
               return false;

            req.type   = QM_BUY;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "sd_demand_first_touch_long";

            g_open_zone_low  = zlow;
            g_open_zone_high = zhigh;
            g_open_is_long   = true;
            g_open_entry_bar = iTime(_Symbol, _Period, 0); // perf-allowed: entry-bar open time
            return true;
           }
        }

      // --- SUPPLY / SHORT ---
      if(DetectSupplyZone(depart_shift, atr_value, zlow, zhigh, base_first))
        {
         if(high1 >= zlow && close1 < zlow &&
            SupplyUntouchedBeforeTrigger(depart_shift, zlow))
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                                  zhigh + strategy_sl_atr_buffer_mult * atr_value);
            if(sl <= 0.0 || sl <= entry)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_rr);
            if(tp <= 0.0)
               return false;

            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "sd_supply_first_touch_short";

            g_open_zone_low  = zlow;
            g_open_zone_high = zhigh;
            g_open_is_long   = false;
            g_open_entry_bar = iTime(_Symbol, _Period, 0); // perf-allowed
            return true;
           }
        }
     }

   return false;
  }

// No active SL/TP trailing — fixed stop and R-multiple target set at entry.
// Secondary signal exit + time stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Secondary exit (close beyond the opposite side of the originating zone) and
// time stop (max_hold_bars closed bars). Evaluated on closed bars.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   // (a) Secondary signal exit: price closes beyond the OPPOSITE side of the zone.
   //   Long  was taken at the demand zone -> opposite side is the zone LOW.
   //   Short was taken at the supply zone -> opposite side is the zone HIGH.
   if(g_open_zone_low > 0.0 && g_open_zone_high > 0.0)
     {
      if(g_open_is_long && close1 < g_open_zone_low)
         return true;
      if(!g_open_is_long && close1 > g_open_zone_high)
         return true;
     }

   // (b) Time stop: close after max_hold_bars closed bars since entry.
   if(g_open_entry_bar > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((cur_bar - g_open_entry_bar) / secs_per_bar);
         if(bars_held >= strategy_max_hold_bars)
            return true;
        }
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
      // Position closed by our discretionary exit — clear originating-zone state.
      if(QM_TM_OpenPositionCount(magic) <= 0)
        {
         g_open_zone_low  = 0.0;
         g_open_zone_high = 0.0;
         g_open_entry_bar = 0;
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // If SL/TP closed the position since we last opened, clear stale zone state
   // so the next entry starts clean.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0 && g_open_entry_bar > 0)
     {
      g_open_zone_low  = 0.0;
      g_open_zone_high = 0.0;
      g_open_entry_bar = 0;
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
