#property strict
#property version   "5.0"
#property description "QM5_9644 Bandy TPS Bounded Scale-In (Mean-Reversion, Long-Only, Index, D1)"
// Strategy Card: QM5_9644 (bandy-tps-bounded-mr-index), G0 APPROVED.
// Source lineage: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 (Howard Bandy,
// "Quantitative Technical Analysis", Blue Owl Press 2015, ISBN 978-0-9791037-7-1).
// R4-compliant recast of Bandy's TPS: an UNBOUNDED layered mean-reversion scale-in
// is hard-capped here at exactly 3 equal-risk units under a single magic, with an
// aggregate catastrophic ATR stop on the full position. Long-only index treatment.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Bandy TPS Bounded Scale-In (daily, long-only MR).
// -----------------------------------------------------------------------------
// Per closed D1 bar the EA caches: mean20=SMA(Close,20,D1), sd20=StdDev(Close,20,
// D1), z=(Close-mean20)/sd20, the 200-day close SMA regime gate, ATR(14,D1), and
// the ATR/close vol ratio (a rolling 252-bar ring drives a bespoke top-1st-
// percentile "no-trade-on-chaos" filter). The per-tick path only reads cached
// state + current Ask/Bid.
//
// STATE MACHINE (per magic, persisted via GlobalVariables so it survives terminal
// restarts): units_held in {0,1,2,3}. This is the novel piece of this build and is
// NOT modelled with multiple magic numbers (the card explicitly forbids that) —
// all three units share ONE magic and are tracked by the internal units_held
// counter + a snapshot of the unit-1 entry price / ATR / entry time / aggregate
// catastrophic-stop level.
//
// ENTRY LADDER (LONG only, every trigger regime-gated by Close>SMA200):
//   units_held==0 AND z<=-2.0 -> add unit-1 at next session open (news-gated).
//   units_held==1 AND z<=-2.5 -> add unit-2 at next session open (news NOT applied
//                                 — the trade is already on, per the card).
//   units_held==2 AND z<=-3.0 -> add unit-3 at next session open (news NOT applied).
//   No adds beyond unit-3 (hard cap — structurally enforced, not an input).
//   Additions (N>1) are skipped if >15 trading days have elapsed since unit-1
//   (prevents re-triggering a stale ladder as a fresh down-leg).
//   One unit maximum is added per closed D1 bar.
//
// SIZING: each unit risks exactly 1/3 of the total book-risk budget (RISK_FIXED/3
//   in backtest; RISK_PERCENT/3 live) measured to the SHARED aggregate catastrophic
//   stop. Because every unit's SL is the same fixed stop level, the sum of the three
//   1/3-risk legs equals the full budget at the stop -> bounded worst-case = budget.
//
// EXIT (aggregate — all units close together):
//   Take-profit : z>=0 on the closed bar -> exit ALL at next session open (== the
//                 signal bar's close on gapless .DWX index CFDs, open[0]==close[1]).
//   Time exit   : exit ALL after 10 trading days (closed D1 bars) from unit-1 entry,
//                 regardless of when units 2/3 were added.
//   Catastrophic: exit ALL if the intraday low breaches
//                 entry_unit_1 - 4.0*ATR(14,D1) (ATR snapshotted at UNIT-1 entry,
//                 NOT re-snapshotted per unit). Enforced two ways at the SAME fixed
//                 level: (a) a broker-side SL on every leg (identical level -> no
//                 OrderModify race) and (b) an authoritative per-tick VIRTUAL stop
//                 checked against cached state that flattens all legs atomically.
//
// FILTERS: incomplete-daily-bar skip is intrinsic to the closed-bar cadence; the
//   vol-percentile chaos filter gates NEW entries only (all units); the news
//   temporal gate (PRE30_POST30, +/-30min high-impact) gates unit-1 entries only
//   and never suspends management/exits (audit-binding OnTick ordering).
// Broker-time native: the D1 boundary is the broker day open; no DST math needed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9644;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;   // TOTAL book-risk budget; split 1/3 per unit.
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card: skip NEW UNIT-1 entries within +/-30 min of high-impact macro releases
// (NFP/FOMC/CPI). Temporal axis = PRE30_POST30; DXZ compliance overlay for the live
// venue. Gate applies to unit-1 entries ONLY (unit-2/3 adds and all management/exits
// run through news windows — the trade is already on).
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older.
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// OFF: a scale-in MR hold spans up to a 10-trading-day time stop across weekends; a
// Friday flatten would truncate every multi-day ladder.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_z_lookback         = 20;     // Card: SMA/StdDev period for the z-score (D1).
input int    strategy_regime_ma_period   = 200;    // Card: long-only regime gate SMA(Close,200,D1).
input double strategy_z_entry_unit1      = -2.0;   // Card: units_held==0 & z<=this -> unit-1.
input double strategy_z_entry_unit2      = -2.5;   // Card: units_held==1 & z<=this -> unit-2.
input double strategy_z_entry_unit3      = -3.0;   // Card: units_held==2 & z<=this -> unit-3.
input double strategy_z_exit             = 0.0;    // Card: take-profit when z>= this (zero line).
input int    strategy_time_exit_days     = 10;     // Card: exit ALL after N D1 bars from unit-1.
input int    strategy_stale_ladder_days  = 15;     // Card: skip unit-N (N>1) if >N days since unit-1.
input int    strategy_atr_period         = 14;     // Card: ATR(14,D1) stop-distance basis.
input double strategy_catastrophic_atr   = 4.0;    // Card: aggregate SL = entry_unit_1 - mult*ATR.
input int    strategy_vol_lookback       = 252;    // Card: trailing-window length for the chaos filter.
input double strategy_vol_top_pctile     = 1.0;    // Card: skip new entries if ATR/close in top Nth pctile.

// The 3-unit cap is STRUCTURAL (three fixed ladder rungs below) and is deliberately
// NOT exposed as a tunable input — it is a Hard-Rule-14 bounded-worst-case constraint,
// not a parameter. Do not add a max_units input.

// -----------------------------------------------------------------------------
// File-scope cached daily state (advanced once per new closed D1 bar).
// -----------------------------------------------------------------------------
bool   g_state_valid  = false;
double g_z            = 0.0;    // z-score at shift 1 (latest closed D1 bar).
double g_close_curr   = 0.0;    // latest closed D1 close (regime gate + vol denominator).
double g_sma_regime   = 0.0;    // SMA(Close, regime_ma_period, D1) at shift 1.
double g_atr14        = 0.0;    // ATR(atr_period, D1) at shift 1.
bool   g_chaos_block  = false;  // true when the current vol ratio is in the top percentile.

// Rolling vol-ratio ring buffer for the bespoke percentile filter.
double g_vol_ring[];            // sized to strategy_vol_lookback.
int    g_vol_head  = 0;         // next write index (ring).
int    g_vol_count = 0;         // filled samples (caps at strategy_vol_lookback).
bool   g_ring_init = false;

// -----------------------------------------------------------------------------
// units_held state machine (persisted via GlobalVariables, keyed per symbol).
// -----------------------------------------------------------------------------
int      g_units_held        = 0;     // 0..3 units currently held under this magic.
double   g_unit1_entry_price = 0.0;   // unit-1 fill price (catastrophic-stop reference).
double   g_unit1_atr         = 0.0;   // ATR(14,D1) snapshotted AT unit-1 entry (fixed).
datetime g_unit1_entry_time  = 0;     // unit-1 entry timestamp (for the record / restart).
double   g_cat_stop_price    = 0.0;   // aggregate catastrophic stop = entry1 - mult*atr1 (fixed).
int      g_bars_since_unit1  = 0;     // closed D1 bars since unit-1 entry (time exit + stale gate).

int      g_pending_unit      = 0;     // which unit (1/2/3) is latched to add on this new bar (0=none).
bool     g_exit_now          = false; // aggregate exit latched (TP or time stop).
QM_ExitReason g_exit_reason  = QM_EXIT_STRATEGY;
bool     g_news_allows_now   = true;  // computed once per tick in OnTick; applied to unit-1 only.
bool     g_init_reconciled   = false; // first-tick reconcile of persisted state vs live positions.

// Scratch set by Strategy_EntrySignal, consumed by OnTick post-fill bookkeeping.
int      g_firing_unit       = 0;
double   g_firing_price      = 0.0;
double   g_firing_cat_stop   = 0.0;

string   g_gv_prefix         = "";    // "QM_<ea_id>_<symbol>_"

// -----------------------------------------------------------------------------
// GlobalVariable persistence — units_held survives terminal restarts within the
// same terminal, satisfying the card's persistence requirement without multi-magic.
// -----------------------------------------------------------------------------
void PersistState()
  {
   GlobalVariableSet(g_gv_prefix + "units_held",       (double)g_units_held);
   GlobalVariableSet(g_gv_prefix + "unit1_entry_price", g_unit1_entry_price);
   GlobalVariableSet(g_gv_prefix + "unit1_atr",         g_unit1_atr);
   GlobalVariableSet(g_gv_prefix + "unit1_entry_time", (double)g_unit1_entry_time);
   GlobalVariableSet(g_gv_prefix + "unit1_cat_stop",    g_cat_stop_price);
   GlobalVariableSet(g_gv_prefix + "bars_since_unit1", (double)g_bars_since_unit1);
  }

void LoadState()
  {
   g_units_held        = (int)GlobalVariableGet(g_gv_prefix + "units_held");
   g_unit1_entry_price = GlobalVariableGet(g_gv_prefix + "unit1_entry_price");
   g_unit1_atr         = GlobalVariableGet(g_gv_prefix + "unit1_atr");
   g_unit1_entry_time  = (datetime)(long)GlobalVariableGet(g_gv_prefix + "unit1_entry_time");
   g_cat_stop_price    = GlobalVariableGet(g_gv_prefix + "unit1_cat_stop");
   g_bars_since_unit1  = (int)GlobalVariableGet(g_gv_prefix + "bars_since_unit1");
   if(g_units_held < 0 || g_units_held > 3)
      g_units_held = 0;   // corrupt/absent -> treat as flat.
  }

void ResetState()
  {
   g_units_held        = 0;
   g_unit1_entry_price = 0.0;
   g_unit1_atr         = 0.0;
   g_unit1_entry_time  = 0;
   g_cat_stop_price    = 0.0;
   g_bars_since_unit1  = 0;
   g_pending_unit      = 0;
   g_exit_now          = false;
   PersistState();
  }

// Close every leg carrying this EA's magic (aggregate flatten).
void CloseAllLegs(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

// Record a confirmed unit fill. Unit-1 snapshots the fixed aggregate stop; unit-2/3
// only advance the counter (the aggregate stop stays anchored on unit-1).
void OnUnitFilled(const int unit, const double fill_price, const double cat_stop)
  {
   if(unit == 1)
     {
      g_units_held        = 1;
      g_unit1_entry_price = fill_price;
      g_unit1_atr         = g_atr14;
      g_unit1_entry_time  = TimeCurrent();
      g_cat_stop_price    = cat_stop;
      g_bars_since_unit1  = 0;
     }
   else
     {
      g_units_held = unit;   // 2 or 3; aggregate stop unchanged.
     }
   g_exit_now = false;
   PersistState();
  }

// -----------------------------------------------------------------------------
// Bespoke rolling-percentile chaos filter — computed ONCE per new D1 bar. Returns
// true when the current ATR/close ratio sits in the top strategy_vol_top_pctile
// percent of the trailing strategy_vol_lookback-bar window (window includes the
// current bar). Inactive until the ring holds a full window (cannot rank a partial).
// -----------------------------------------------------------------------------
bool ComputeChaosBlock(const double vol_ratio_now)
  {
   if(g_vol_count < strategy_vol_lookback)
      return false;
   if(vol_ratio_now <= 0.0)
      return false;

   double tmp[];
   ArrayResize(tmp, g_vol_count);
   for(int i = 0; i < g_vol_count; i++)
      tmp[i] = g_vol_ring[i];
   ArraySort(tmp);                          // ascending.

   double frac = 1.0 - (strategy_vol_top_pctile / 100.0);
   if(frac < 0.0) frac = 0.0;
   if(frac > 1.0) frac = 1.0;
   int idx = (int)MathRound(frac * (g_vol_count - 1));
   if(idx < 0) idx = 0;
   if(idx > g_vol_count - 1) idx = g_vol_count - 1;

   const double threshold = tmp[idx];       // (1 - pctile) quantile of the window.
   return (vol_ratio_now >= threshold);
  }

// Advance cached z-score / regime / ATR state, the rolling vol ring, and the
// aggregate exit / ladder-add decision flags once per new closed D1 bar.
void AdvanceDaily()
  {
   g_state_valid  = false;
   g_pending_unit = 0;        // level-triggered: re-evaluate the ladder fresh each bar.

   if(!g_ring_init || ArraySize(g_vol_ring) != strategy_vol_lookback)
     {
      ArrayResize(g_vol_ring, strategy_vol_lookback);
      ArrayInitialize(g_vol_ring, 0.0);
      g_vol_head  = 0;
      g_vol_count = 0;
      g_ring_init = true;
     }

   const double mean20     = QM_SMA(_Symbol, PERIOD_D1, strategy_z_lookback, 1, PRICE_CLOSE);
   const double sd20       = QM_StdDev(_Symbol, PERIOD_D1, strategy_z_lookback, 1, PRICE_CLOSE);
   const double sma_regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_ma_period, 1, PRICE_CLOSE);
   const double atr14      = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double close_curr = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: z numerator + regime gate + vol denominator, once per new D1 bar.
   if(mean20 <= 0.0 || sd20 <= 0.0 || sma_regime <= 0.0 || atr14 <= 0.0 || close_curr <= 0.0)
      return;                 // insufficient history — leave g_state_valid=false.

   const double z         = (close_curr - mean20) / sd20;
   const double vol_ratio = atr14 / close_curr;

   // Push the current vol ratio into the ring (advance by one bar).
   g_vol_ring[g_vol_head] = vol_ratio;
   g_vol_head = (g_vol_head + 1) % strategy_vol_lookback;
   if(g_vol_count < strategy_vol_lookback)
      g_vol_count++;

   g_z           = z;
   g_close_curr  = close_curr;
   g_sma_regime  = sma_regime;
   g_atr14       = atr14;
   g_chaos_block = ComputeChaosBlock(vol_ratio);
   g_state_valid = true;

   const bool regime_ok = (close_curr > sma_regime);

   if(g_units_held > 0)
     {
      g_bars_since_unit1++;
      // Aggregate exits (evaluated before any add).
      if(z >= strategy_z_exit)
        { g_exit_now = true; g_exit_reason = QM_EXIT_STRATEGY; }          // take-profit: z back to zero line.
      else if(g_bars_since_unit1 >= strategy_time_exit_days)
        { g_exit_now = true; g_exit_reason = QM_EXIT_TIME_STOP; }         // 10-trading-day time stop.
      else if(g_bars_since_unit1 <= strategy_stale_ladder_days)
        {
         // Ladder additions (hard-capped at 3). One unit per bar.
         if(g_units_held == 1 && z <= strategy_z_entry_unit2 && regime_ok)
            g_pending_unit = 2;
         else if(g_units_held == 2 && z <= strategy_z_entry_unit3 && regime_ok)
            g_pending_unit = 3;
        }
     }
   else
     {
      // Flat: only unit-1 can open a fresh ladder.
      if(z <= strategy_z_entry_unit1 && regime_ok)
         g_pending_unit = 1;
     }
  }

// Resolve the per-unit risk (exactly 1/3 of the configured budget) in the same mode
// as the active ENV config (RISK_FIXED in backtest, RISK_PERCENT live).
void SelectUnitRisk(QM_RiskMode &out_mode, double &out_value)
  {
   if(RISK_FIXED > 0.0)
     {
      out_mode  = QM_RISK_MODE_FIXED;
      out_value = RISK_FIXED / 3.0;
     }
   else
     {
      out_mode  = QM_RISK_MODE_PERCENT;
      out_value = RISK_PERCENT / 3.0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — bespoke vol-percentile "no-trade-on-chaos" gate. Reads cached
// g_chaos_block only (O(1)); sits on the entry path in OnTick, so it blocks NEW
// entries (all units) without ever suspending management/exits. The card wording
// ("skip new entries ...") is unqualified, so it is applied to unit-1/2/3 alike.
bool Strategy_NoTradeFilter()
  {
   if(!g_state_valid)
      return false;
   return g_chaos_block;
  }

// Trade Entry — fires on the first tick of a new D1 bar for the latched ladder unit.
// Long only. Reads cached state + current Ask only. Every unit's SL is the SHARED
// aggregate catastrophic stop -> per-unit 1/3 risk to that stop sums to the budget.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;
   if(g_pending_unit <= 0)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // News gate applies to UNIT-1 only (unit-2/3 adds run through news windows).
   if(g_pending_unit == 1 && !g_news_allows_now)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double cat_stop;
   if(g_pending_unit == 1)
      cat_stop = ask - strategy_catastrophic_atr * g_atr14;   // fresh anchor from unit-1.
   else
      cat_stop = g_cat_stop_price;                            // fixed aggregate stop from unit-1.

   if(cat_stop <= 0.0 || cat_stop >= ask)
      return false;   // invalid long-stop geometry (also: price already at/below the stop -> do not add).

   req.type               = QM_BUY;
   req.price              = 0.0;         // market fill at send.
   req.sl                 = cat_stop;    // shared aggregate catastrophic stop (identical across legs).
   req.tp                 = 0.0;         // exits are rule-based (z>=0 TP / time / virtual cat-stop).
   req.reason             = StringFormat("TPS_UNIT%d_LONG_D1", g_pending_unit);
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Stash for post-fill bookkeeping (state is only mutated on a CONFIRMED fill).
   g_firing_unit     = g_pending_unit;
   g_firing_price    = ask;
   g_firing_cat_stop = cat_stop;
   return true;
  }

// Trade Management — (1) reconcile cached units against live positions: if we hold
// units but the broker shows none, the aggregate broker SL (or an external close)
// flattened us -> reset. (2) Authoritative per-tick VIRTUAL catastrophic stop: if
// the current Bid breaches the cached aggregate stop, flatten ALL legs atomically.
// O(1): reads cached state + one Bid tick, never recomputes indicators.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const int live = QM_TM_OpenPositionCount(magic);

   if(g_units_held > 0 && live == 0)
     {
      ResetState();     // broker-side flatten (SL hit / external) -> resync to flat.
      return;
     }
   if(g_units_held == 0)
      return;

   if(g_cat_stop_price > 0.0)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0 && bid <= g_cat_stop_price)   // intraday low breach of the aggregate stop.
        {
         CloseAllLegs(QM_EXIT_SL_HIT);
         ResetState();
        }
     }
  }

// Trade Close — reads the once-per-bar aggregate exit latch (z>=0 take-profit or the
// 10-day time stop). The catastrophic stop is handled in Strategy_ManageOpenPosition
// (broker SL + virtual stop), so it is intentionally not repeated here.
bool Strategy_ExitSignal()
  {
   if(g_units_held == 0)
      return false;
   return g_exit_now;
  }

// News Filter Hook — defer to the central gate (temporal PRE30_POST30), which this
// EA applies to unit-1 entries only via g_news_allows_now in the OnTick entry path.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — closed-bar (D1) cadence. State advances on the D1 new-bar
// latch; management (incl. the virtual catastrophic stop) + aggregate exits run
// every tick through news windows; only NEW entries pass the chaos filter, and
// only unit-1 entries pass the news gate.
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
                        qm_news_temporal,              // FW1 Axis A (+/-30min)
                        qm_news_compliance))           // FW1 Axis B (DXZ overlay)
      return INIT_FAILED;

   g_gv_prefix = "QM_" + IntegerToString(qm_ea_id) + "_" + _Symbol + "_";
   LoadState();
   // Stale-GlobalVariable guard: a prior tester run on the same symbol can leave a
   // non-flat units_held in the shared GlobalVariable pool. If we loaded units but
   // hold no live position for this magic, resync to flat BEFORE any bar advances.
   if(g_units_held > 0 && QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
      ResetState();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9644_bandy-tps-bounded-mr-index\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard returns.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();

   // Belt-and-suspenders first-tick reconcile (in case OnInit ran before positions
   // were queryable in the tester). Runs at most once.
   if(!g_init_reconciled)
     {
      if(g_units_held > 0 && QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
         ResetState();
      g_init_reconciled = true;
     }

   if(QM_FrameworkHandleFridayClose())
      return;

   // Advance cached daily state once per new closed D1 bar.
   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      AdvanceDaily();
      QM_EquityStreamOnNewBar();
     }

   // Management (virtual catastrophic stop + reconcile) + aggregate exits run EVERY
   // tick, through news/chaos windows.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      CloseAllLegs(g_exit_reason);
      ResetState();
     }

   // ---- entry path (gates NEW entries only; never management/exits above) ----
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())          // chaos filter: blocks ALL new units.
      return;

   // Compute the news verdict once; applied to unit-1 only inside EntrySignal.
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      g_news_allows_now = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      g_news_allows_now = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);

   // NOTE: do NOT re-call QM_IsNewBar here — it is single-consume per tick and the
   // AdvanceDaily block above already consumed the D1 new-bar event. g_pending_unit
   // is set ONLY inside AdvanceDaily and cleared after the attempt below, so each
   // unit is added strictly once, on the new-bar edge.
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      QM_RiskMode unit_mode;
      double unit_value;
      SelectUnitRisk(unit_mode, unit_value);
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket, QM_FrameworkMagic(), unit_mode, unit_value))
         OnUnitFilled(g_firing_unit, g_firing_price, g_firing_cat_stop);
      g_pending_unit = 0;   // consume the latch (one attempt per bar; no intrabar retry).
      g_firing_unit  = 0;
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
