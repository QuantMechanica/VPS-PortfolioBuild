#property strict
#property version   "5.0"
#property description "QM5_10782 TradingView SMC BTC/EUR Order Block R3"

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
input int    qm_ea_id                   = 10782;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input ENUM_TIMEFRAMES strategy_htf_ema_tf          = PERIOD_H1;
input int             strategy_ema_period          = 200;
input int             strategy_swing_length        = 4;
input int             strategy_structure_lookback  = 80;
input int             strategy_liquidity_lookback  = 7;
input double          strategy_liquidity_tol_pct   = 0.10;
input bool            strategy_require_fvg         = true;
input bool            strategy_require_pd_zone     = true;
input int             strategy_atr_period          = 14;
input double          strategy_atr_buffer_mult     = 0.0;
input double          strategy_rr_target           = 3.0;
input double          strategy_max_spread_points   = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session filter. Optional spread cap defaults to disabled.
   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }
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

   if(strategy_ema_period <= 0 ||
      strategy_swing_length < 2 ||
      strategy_structure_lookback < strategy_swing_length * 2 + 5 ||
      strategy_liquidity_lookback < 1 ||
      strategy_rr_target <= 0.0)
      return false;

   const int min_bars_needed = strategy_liquidity_lookback + strategy_swing_length * 2 + 12;
   const int bars_needed = (strategy_structure_lookback > min_bars_needed)
                           ? strategy_structure_lookback
                           : min_bars_needed;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, bars_needed, rates); // perf-allowed: structural SMC scan, framework new-bar gated.
   if(copied < strategy_swing_length * 2 + 10)
      return false;

   const double ema_htf = QM_EMA(_Symbol, strategy_htf_ema_tf, strategy_ema_period, 1);
   if(ema_htf <= 0.0)
      return false;

   const double close_last = rates[1].close;
   const bool long_permission = (close_last > ema_htf);
   const bool short_permission = (close_last < ema_htf);
   if(!long_permission && !short_permission)
      return false;

   double swing_high = 0.0;
   double swing_low = 0.0;
   int swing_high_shift = -1;
   int swing_low_shift = -1;
   const int copied_scan_limit = copied - strategy_swing_length - 1;
   const int strategy_scan_limit = strategy_structure_lookback - strategy_swing_length - 1;
   const int max_scan = (copied_scan_limit < strategy_scan_limit) ? copied_scan_limit : strategy_scan_limit;
   for(int shift = strategy_swing_length + 1; shift <= max_scan; ++shift)
     {
      bool is_swing_high = true;
      bool is_swing_low = true;
      for(int k = 1; k <= strategy_swing_length; ++k)
        {
         if(rates[shift].high <= rates[shift - k].high || rates[shift].high <= rates[shift + k].high)
            is_swing_high = false;
         if(rates[shift].low >= rates[shift - k].low || rates[shift].low >= rates[shift + k].low)
            is_swing_low = false;
        }
      if(is_swing_high && swing_high_shift < 0)
        {
         swing_high = rates[shift].high;
         swing_high_shift = shift;
        }
      if(is_swing_low && swing_low_shift < 0)
        {
         swing_low = rates[shift].low;
         swing_low_shift = shift;
        }
      if(swing_high_shift >= 0 && swing_low_shift >= 0)
         break;
     }
   if(swing_high <= 0.0 || swing_low <= 0.0 || swing_high <= swing_low)
      return false;

   const bool bullish_bos = (close_last > swing_high);
   const bool bearish_bos = (close_last < swing_low);
   if(!bullish_bos && !bearish_bos)
      return false;

   const int ob_shift = 2;
   const double ob_high = rates[ob_shift].high;
   const double ob_low = rates[ob_shift].low;
   const double ob_mid = (ob_high + ob_low) * 0.5;
   const double range_mid = (swing_high + swing_low) * 0.5;
   if(ob_high <= ob_low || ob_low <= 0.0)
      return false;

   double recent_high = -DBL_MAX;
   double recent_low = DBL_MAX;
   const int liq_start = 3;
   const int liq_limit = liq_start + strategy_liquidity_lookback - 1;
   const int liq_end = ((copied - 1) < liq_limit) ? (copied - 1) : liq_limit;
   for(int shift = liq_start; shift <= liq_end; ++shift)
     {
      recent_high = MathMax(recent_high, rates[shift].high);
      recent_low = MathMin(recent_low, rates[shift].low);
     }
   if(recent_high <= 0.0 || recent_low <= 0.0 || recent_high == -DBL_MAX || recent_low == DBL_MAX)
      return false;

   const double tol = MathMax(0.0, strategy_liquidity_tol_pct) / 100.0;
   const bool long_swept_liquidity = (MathMin(rates[1].low, rates[2].low) <= recent_low * (1.0 + tol));
   const bool short_swept_liquidity = (MathMax(rates[1].high, rates[2].high) >= recent_high * (1.0 - tol));
   const bool bullish_fvg = (rates[1].low > rates[3].high);
   const bool bearish_fvg = (rates[1].high < rates[3].low);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const bool last_bar_touched_ob = (rates[1].low <= ob_high && rates[1].high >= ob_low);
   const bool ask_in_ob = (ask >= ob_low && ask <= ob_high);
   const bool bid_in_ob = (bid >= ob_low && bid <= ob_high);
   if(strategy_atr_period <= 0)
      return false;
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double buffer = (atr > 0.0 && strategy_atr_buffer_mult > 0.0) ? atr * strategy_atr_buffer_mult : 0.0;

   if(long_permission &&
      bullish_bos &&
      rates[ob_shift].close < rates[ob_shift].open &&
      (!strategy_require_fvg || bullish_fvg) &&
      long_swept_liquidity &&
      (!strategy_require_pd_zone || ob_mid < range_mid) &&
      (ask_in_ob || last_bar_touched_ob))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ob_low - buffer, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_target);
      req.reason = "SMC_LONG_BOS_OB_FVG_SWEEP_PD";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < ask && req.tp > ask && MathAbs(ask - req.sl) / point > 1.0);
     }

   if(short_permission &&
      bearish_bos &&
      rates[ob_shift].close > rates[ob_shift].open &&
      (!strategy_require_fvg || bearish_fvg) &&
      short_swept_liquidity &&
      (!strategy_require_pd_zone || ob_mid > range_mid) &&
      (bid_in_ob || last_bar_touched_ob))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(ob_high + buffer, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_target);
      req.reason = "SMC_SHORT_BOS_OB_FVG_SWEEP_PD";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > bid && req.tp < bid && MathAbs(bid - req.sl) / point > 1.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines no break-even, trailing, partial close, or pyramiding logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool have_position = false;
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
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   if(!QM_IsNewBar(_Symbol, PERIOD_CURRENT))
      return false;

   const int min_bars_needed = strategy_swing_length * 2 + 10;
   const int bars_needed = (strategy_structure_lookback > min_bars_needed)
                           ? strategy_structure_lookback
                           : min_bars_needed;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, bars_needed, rates); // perf-allowed: opposite-BOS structural exit, position-only new-bar gated.
   if(copied < strategy_swing_length * 2 + 10)
      return false;

   double swing_high = 0.0;
   double swing_low = 0.0;
   int swing_high_shift = -1;
   int swing_low_shift = -1;
   const int copied_scan_limit = copied - strategy_swing_length - 1;
   const int strategy_scan_limit = strategy_structure_lookback - strategy_swing_length - 1;
   const int max_scan = (copied_scan_limit < strategy_scan_limit) ? copied_scan_limit : strategy_scan_limit;
   for(int shift = strategy_swing_length + 1; shift <= max_scan; ++shift)
     {
      bool is_swing_high = true;
      bool is_swing_low = true;
      for(int k = 1; k <= strategy_swing_length; ++k)
        {
         if(rates[shift].high <= rates[shift - k].high || rates[shift].high <= rates[shift + k].high)
            is_swing_high = false;
         if(rates[shift].low >= rates[shift - k].low || rates[shift].low >= rates[shift + k].low)
            is_swing_low = false;
        }
      if(is_swing_high && swing_high_shift < 0)
        {
         swing_high = rates[shift].high;
         swing_high_shift = shift;
        }
      if(is_swing_low && swing_low_shift < 0)
        {
         swing_low = rates[shift].low;
         swing_low_shift = shift;
        }
      if(swing_high_shift >= 0 && swing_low_shift >= 0)
         break;
     }
   if(swing_high <= 0.0 || swing_low <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && rates[1].close < swing_low)
      return true;
   if(position_type == POSITION_TYPE_SELL && rates[1].close > swing_high)
      return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // No card-specific news rule; central framework news modes remain callable.
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
