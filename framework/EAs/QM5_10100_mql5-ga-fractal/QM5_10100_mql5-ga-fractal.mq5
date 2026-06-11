#property strict
#property version   "5.0"
#property description "QM5_10100 MQL5 Geometric Asymmetry Fractal Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10100;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault Q09 News Impact Mode.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fractal_lookback_bars = 120;
input int    strategy_min_range_bars        = 12;
input int    strategy_atr_period            = 14;
input double strategy_min_range_atr_mult    = 0.75;
input double strategy_side_zone_fraction    = 0.15;
input int    strategy_min_side_touches      = 2;
input double strategy_length_ratio_min      = 1.15;
input double strategy_slope_ratio_min       = 1.15;
input double strategy_time_ratio_max        = 0.85;
input int    strategy_vote_threshold        = 2;
input double strategy_breakout_atr_buffer   = 0.10;
input double strategy_sl_atr_buffer         = 0.25;
input double strategy_take_profit_rr        = 2.0;
input bool   strategy_use_measured_move_tp  = false;
input bool   strategy_use_last_swing_stop   = true;

struct QM_FractalRange
  {
   bool      valid;
   int       bias;
   int       votes;
   int       newest_shift;
   int       oldest_shift;
   double    high;
   double    low;
   double    height;
   double    atr;
   double    breakout_buffer;
   double    buy_stop_ref;
   double    sell_stop_ref;
   datetime  anchor_time;
  };

datetime g_traded_range_anchor_time = 0;
double   g_active_range_high = 0.0;
double   g_active_range_low = 0.0;

bool IsUsableFractalValue(const double value)
  {
   return (value > 0.0 && value != EMPTY_VALUE && value < DBL_MAX / 2.0);
  }

bool FindOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

void ResetRange(QM_FractalRange &range)
  {
   range.valid = false;
   range.bias = 0;
   range.votes = 0;
   range.newest_shift = 0;
   range.oldest_shift = 0;
   range.high = 0.0;
   range.low = 0.0;
   range.height = 0.0;
   range.atr = 0.0;
   range.breakout_buffer = 0.0;
   range.buy_stop_ref = 0.0;
   range.sell_stop_ref = 0.0;
   range.anchor_time = 0;
  }

bool FindQualifiedRange(QM_FractalRange &range)
  {
   ResetRange(range);

   if(strategy_fractal_lookback_bars < 10 ||
      strategy_min_range_bars < 3 ||
      strategy_atr_period <= 0 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_side_zone_fraction <= 0.0 ||
      strategy_min_side_touches <= 0 ||
      strategy_vote_threshold <= 0)
      return false;

   int ftype[3];
   int fshift[3];
   double fprice[3];
   ArrayInitialize(ftype, 0);
   ArrayInitialize(fshift, 0);
   ArrayInitialize(fprice, 0.0);

   int found = 0;
   int prior_type = 0;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   for(int shift = 2; shift <= strategy_fractal_lookback_bars && found < 3; ++shift)
     {
      const double upper = QM_FractalUpper(_Symbol, tf, shift);
      const double lower = QM_FractalLower(_Symbol, tf, shift);
      int this_type = 0;
      double this_price = 0.0;

      if(IsUsableFractalValue(upper) && (prior_type == 0 || prior_type < 0))
        {
         this_type = 1;
         this_price = upper;
        }
      else if(IsUsableFractalValue(lower) && (prior_type == 0 || prior_type > 0))
        {
         this_type = -1;
         this_price = lower;
        }

      if(this_type == 0)
         continue;

      ftype[found] = this_type;
      fshift[found] = shift;
      fprice[found] = this_price;
      prior_type = this_type;
      found++;
     }

   if(found < 3)
      return false;

   range.newest_shift = fshift[0];
   range.oldest_shift = fshift[2];
   const int duration = range.oldest_shift - range.newest_shift + 1;
   if(duration < strategy_min_range_bars)
      return false;

   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   for(int shift = range.newest_shift; shift <= range.oldest_shift; ++shift)
     {
      const double high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar structural range scan; no QM_High helper exists.
      const double low = iLow(_Symbol, _Period, shift);   // perf-allowed: bounded closed-bar structural range scan; no QM_Low helper exists.
      if(high > 0.0)
         range_high = MathMax(range_high, high);
      if(low > 0.0)
         range_low = MathMin(range_low, low);
     }

   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   range.high = range_high;
   range.low = range_low;
   range.height = range.high - range.low;
   range.atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(range.atr <= 0.0 || range.height < range.atr * strategy_min_range_atr_mult)
      return false;

   const double zone_width = range.height * strategy_side_zone_fraction;
   int upper_touches = 0;
   int lower_touches = 0;
   for(int shift = range.newest_shift; shift <= range.oldest_shift; ++shift)
     {
      const double high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar side-zone touch scan; no QM_High helper exists.
      const double low = iLow(_Symbol, _Period, shift);   // perf-allowed: bounded closed-bar side-zone touch scan; no QM_Low helper exists.
      if(high >= range.high - zone_width)
         upper_touches++;
      if(low <= range.low + zone_width)
         lower_touches++;
     }

   if((upper_touches + lower_touches) < strategy_min_side_touches ||
      upper_touches == 0 ||
      lower_touches == 0)
      return false;

   const double prior_leg_len = MathAbs(fprice[1] - fprice[2]);
   const double final_leg_len = MathAbs(fprice[0] - fprice[1]);
   const int prior_leg_bars = MathMax(1, fshift[2] - fshift[1]);
   const int final_leg_bars = MathMax(1, fshift[1] - fshift[0]);
   if(prior_leg_len <= 0.0 || final_leg_len <= 0.0)
      return false;

   int votes = 0;
   if(final_leg_len / prior_leg_len >= strategy_length_ratio_min)
      votes++;

   const double prior_slope = prior_leg_len / (double)prior_leg_bars;
   const double final_slope = final_leg_len / (double)final_leg_bars;
   if(prior_slope > 0.0 && final_slope / prior_slope >= strategy_slope_ratio_min)
      votes++;

   if((double)final_leg_bars / (double)prior_leg_bars <= strategy_time_ratio_max)
      votes++;

   if(votes < strategy_vote_threshold)
      return false;

   const double final_delta = fprice[0] - fprice[1];
   range.bias = (final_delta > 0.0) ? 1 : -1;
   range.votes = votes;
   range.breakout_buffer = range.atr * strategy_breakout_atr_buffer;
   range.buy_stop_ref = range.low;
   range.sell_stop_ref = range.high;
   if(strategy_use_last_swing_stop)
     {
      for(int i = 0; i < 3; ++i)
        {
         if(ftype[i] < 0)
           {
            range.buy_stop_ref = fprice[i];
            break;
           }
        }
      for(int i = 0; i < 3; ++i)
        {
         if(ftype[i] > 0)
           {
            range.sell_stop_ref = fprice[i];
            break;
           }
        }
     }

   range.anchor_time = iTime(_Symbol, _Period, range.newest_shift); // perf-allowed: range identity only; not a per-EA new-bar gate.
   range.valid = (range.anchor_time > 0);
   return range.valid;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, _Period) < strategy_fractal_lookback_bars + 10) // perf-allowed: O(1) warmup guard; no QM_Bars helper exists.
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(FindOpenPosition(position_type))
      return false;

   QM_FractalRange range;
   if(!FindQualifiedRange(range))
      return false;
   if(range.anchor_time == g_traded_range_anchor_time)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar breakout close; no QM_Close helper exists.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close_1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(range.bias > 0 && close_1 > range.high + range.breakout_buffer)
     {
      const double entry = ask;
      const double sl = range.buy_stop_ref - range.atr * strategy_sl_atr_buffer;
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double rr_tp = entry + (entry - sl) * strategy_take_profit_rr;
      const double measured_tp = range.high + range.height;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble((strategy_use_measured_move_tp && measured_tp > entry) ? measured_tp : rr_tp, _Digits);
      req.reason = StringFormat("GA_FRACTAL_BUY_V%d", range.votes);
      g_traded_range_anchor_time = range.anchor_time;
      g_active_range_high = range.high;
      g_active_range_low = range.low;
      return true;
     }

   if(range.bias < 0 && close_1 < range.low - range.breakout_buffer)
     {
      const double entry = bid;
      const double sl = range.sell_stop_ref + range.atr * strategy_sl_atr_buffer;
      if(sl <= entry)
         return false;
      const double rr_tp = entry - (sl - entry) * strategy_take_profit_rr;
      const double measured_tp = range.low - range.height;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble((strategy_use_measured_move_tp && measured_tp < entry) ? measured_tp : rr_tp, _Digits);
      req.reason = StringFormat("GA_FRACTAL_SELL_V%d", range.votes);
      g_traded_range_anchor_time = range.anchor_time;
      g_active_range_high = range.high;
      g_active_range_low = range.low;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!FindOpenPosition(position_type))
     {
      g_active_range_high = 0.0;
      g_active_range_low = 0.0;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_active_range_high <= 0.0 || g_active_range_low <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!FindOpenPosition(position_type))
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar inside-range exit check; no QM_Close helper exists.
   if(close_1 <= 0.0)
      return false;

   return (close_1 < g_active_range_high && close_1 > g_active_range_low);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to the framework news filter.
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
