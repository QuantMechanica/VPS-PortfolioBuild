#property strict
#property version   "5.0"
#property description "QM5_10214 TradingView GVTO Supertrend DMI Trend"

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
input int    qm_ea_id                   = 10214;
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
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
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
// GVTO = EMA200 baseline + SuperTrend(ATR 14, factor 3.5) flip + ADX/DMI(14)
// regime gate. Long when price closes above EMA200, SuperTrend flips green,
// ADX>25 and DI+>DI-. SuperTrend line is the trailing stop / flip exit.
input int    strategy_ema_period            = 200;    // EMA200 trend baseline
input int    strategy_st_atr_period         = 14;     // SuperTrend ATR length
input double strategy_st_multiplier         = 3.5;    // SuperTrend factor
input int    strategy_adx_period            = 14;     // ADX + DMI period
input double strategy_adx_floor             = 25.0;   // ADX must exceed this
input double strategy_emergency_atr_mult    = 3.0;    // emergency SL = N*ATR cap
input int    strategy_supertrend_warmup_bars = 200;   // forward-reconstruction window

// -----------------------------------------------------------------------------
// SuperTrend forward reconstruction (single pass, seeded from hl2 median).
// Computes direction at the last two closed bars (shift 1 and shift 2) plus the
// current SuperTrend line at shift 1. dir = +1 (green / uptrend, line is lower
// band) or -1 (red / downtrend, line is upper band). Seeding `dir` from the
// bar median (hl2) at the warmup anchor — NOT from a band several ATR away —
// keeps the trend free to flip (DWX invariant #8). Returns false if any bar /
// ATR read is unavailable so callers fail-safe (no trade) rather than acting on
// a half-formed line.
// -----------------------------------------------------------------------------
bool ComputeSuperTrend(const int warmup,
                       double &out_line_1,
                       int &out_dir_1,
                       int &out_dir_2)
  {
   out_line_1 = 0.0;
   out_dir_1  = 0;
   out_dir_2  = 0;

   if(warmup < 10 || strategy_st_atr_period <= 1 || strategy_st_multiplier <= 0.0)
      return false;

   int    dir        = 0;
   double upper      = 0.0;
   double lower      = 0.0;
   double prev_line  = 0.0;
   double line       = 0.0;

   for(int i = warmup; i >= 1; --i)
     {
      const double hi      = iHigh(_Symbol, _Period, i);     // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double lo      = iLow(_Symbol, _Period, i);      // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double cl      = iClose(_Symbol, _Period, i);    // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double prev_cl = iClose(_Symbol, _Period, i + 1);// perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double atr     = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return false;

      const double mid         = (hi + lo) * 0.5;            // hl2 median seed
      const double basic_upper = mid + strategy_st_multiplier * atr;
      const double basic_lower = mid - strategy_st_multiplier * atr;

      if(i == warmup)
        {
         upper = basic_upper;
         lower = basic_lower;
         dir   = (cl >= mid) ? 1 : -1;
        }
      else
        {
         upper = (basic_upper < upper || prev_cl > upper) ? basic_upper : upper;
         lower = (basic_lower > lower || prev_cl < lower) ? basic_lower : lower;
         if(prev_line == upper)
            dir = (cl <= upper) ? -1 : 1;
         else
            dir = (cl >= lower) ? 1 : -1;
        }
      line      = (dir > 0) ? lower : upper;
      prev_line = line;

      if(i == 2)
         out_dir_2 = dir;
      if(i == 1)
        {
         out_dir_1  = dir;
         out_line_1 = line;
        }
     }

   return (out_dir_1 != 0 && out_dir_2 != 0 && out_line_1 > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card authorizes only the standard V5 spread/news filters; the ADX/DMI
   // regime gate lives in Strategy_EntrySignal (needs closed-bar reads).
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period <= 1 || strategy_adx_period <= 1 ||
      strategy_emergency_atr_mult <= 0.0)
      return false;

   const int warmup = MathMax(strategy_supertrend_warmup_bars,
                              strategy_st_atr_period * 4);

   double st_line = 0.0;
   int    dir_1   = 0;
   int    dir_2   = 0;
   if(!ComputeSuperTrend(warmup, st_line, dir_1, dir_2))
      return false;

   // SuperTrend FLIP is the single trigger event. EMA200 / ADX / DI are STATES
   // read on the same closed bar (DWX invariant #4 — never demand two events).
   const bool flip_green = (dir_1 > 0 && dir_2 < 0);
   const bool flip_red   = (dir_1 < 0 && dir_2 > 0);
   if(!flip_green && !flip_red)
      return false;

   const double ema     = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double close_1 = iClose(_Symbol, _Period, 1);       // perf-allowed: single closed-bar read for EMA gate
   const double adx     = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   const double di_plus = QM_ADX_PlusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   const double di_minus= QM_ADX_MinusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   const double atr     = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_st_atr_period, 1);
   if(ema <= 0.0 || close_1 <= 0.0 || adx <= 0.0 || atr <= 0.0)
      return false;

   if(adx <= strategy_adx_floor)
      return false;

   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   // LONG: close > EMA200, SuperTrend flips green, ADX>floor, DI+ > DI-.
   if(flip_green && close_1 > ema && di_plus > di_minus)
     {
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.reason = "gvto_supertrend_dmi_long";
      // Primary stop = SuperTrend line; cap at emergency N*ATR if the line is
      // unavailable (>= entry) or wider than the cap.
      const double emergency_sl = ask - strategy_emergency_atr_mult * atr;
      double sl = (st_line > 0.0 && st_line < ask && st_line >= emergency_sl)
                  ? st_line : emergency_sl;
      req.sl = sl;
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   // SHORT: close < EMA200, SuperTrend flips red, ADX>floor, DI- > DI+.
   if(flip_red && close_1 < ema && di_minus > di_plus)
     {
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.reason = "gvto_supertrend_dmi_short";
      const double emergency_sl = bid + strategy_emergency_atr_mult * atr;
      double sl = (st_line > bid && st_line <= emergency_sl)
                  ? st_line : emergency_sl;
      req.sl = sl;
      return (req.sl > bid + point);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
// GVTO trails the open position along the SuperTrend line (dynamic stop).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   // Only do the (bounded) SuperTrend reconstruction when a matching position
   // exists, to keep the per-tick path cheap when flat.
   bool has_position = false;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong t = PositionGetTicket(p);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }
   if(!has_position)
      return;

   const int warmup = MathMax(strategy_supertrend_warmup_bars,
                              strategy_st_atr_period * 4);
   double st_line = 0.0;
   int    dir_1   = 0;
   int    dir_2   = 0;
   if(!ComputeSuperTrend(warmup, st_line, dir_1, dir_2) || st_line <= 0.0)
      return;

   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      // SuperTrend trailing stop: only tighten in the trade's favour.
      if(ptype == POSITION_TYPE_BUY && dir_1 > 0 && st_line < bid &&
         (current_sl <= 0.0 || st_line > current_sl + point))
         QM_TM_MoveSL(ticket, st_line, "gvto_supertrend_trail_long");
      if(ptype == POSITION_TYPE_SELL && dir_1 < 0 && st_line > ask &&
         (current_sl <= 0.0 || st_line < current_sl - point))
         QM_TM_MoveSL(ticket, st_line, "gvto_supertrend_trail_short");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end). GVTO exits on a SuperTrend flip against
// the open position (long closes when SuperTrend turns red, and vice versa).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const int warmup = MathMax(strategy_supertrend_warmup_bars,
                              strategy_st_atr_period * 4);
   double st_line = 0.0;
   int    dir_1   = 0;
   int    dir_2   = 0;
   if(!ComputeSuperTrend(warmup, st_line, dir_1, dir_2))
      return false;

   // Exit long when SuperTrend is red (dir_1 < 0); exit short when green.
   if(ptype == POSITION_TYPE_BUY && dir_1 < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && dir_1 > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
