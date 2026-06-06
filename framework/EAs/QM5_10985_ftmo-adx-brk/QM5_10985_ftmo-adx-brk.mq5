#property strict
#property version   "5.0"
#property description "QM5_10985 FTMO ADX Range Breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

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
input int    qm_ea_id                   = 10985;
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
input int    strategy_adx_period              = 14;
input int    strategy_atr_period              = 14;
input int    strategy_donchian_lookback       = 20;
input int    strategy_compression_window      = 12;
input int    strategy_compression_min_bars    = 8;
input double strategy_compression_adx_max     = 22.0;
input double strategy_compression_atr_mult    = 2.2;
input double strategy_breakout_adx_level      = 25.0;
input double strategy_exit_adx_level          = 20.0;
input double strategy_breakout_range_atr_mult = 2.5;
input double strategy_sl_atr_mult             = 1.2;
input double strategy_tp_r_multiple           = 2.0;
input double strategy_trail_trigger_r         = 1.5;
input double strategy_trail_atr_mult          = 2.0;
input int    strategy_max_hold_bars           = 48;
input int    strategy_max_spread_points       = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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

   if(_Period != PERIOD_H1)
      return false;
   if(strategy_adx_period <= 0 || strategy_atr_period <= 0 ||
      strategy_donchian_lookback <= 1 || strategy_compression_window <= 0 ||
      strategy_compression_min_bars <= 0 || strategy_max_hold_bars <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int compressed_bars = 0;
   for(int shift = 2; shift < 2 + strategy_compression_window; ++shift)
     {
      const double adx_past = QM_ADX(_Symbol, tf, strategy_adx_period, shift);
      if(adx_past > 0.0 && adx_past < strategy_compression_adx_max)
         compressed_bars++;
     }
   if(compressed_bars < strategy_compression_min_bars)
      return false;

   double donchian_high = -DBL_MAX;
   double donchian_low = DBL_MAX;
   for(int shift = 2; shift < 2 + strategy_donchian_lookback; ++shift)
     {
      const double bar_high = iHigh(_Symbol, tf, shift); // perf-allowed: bounded Donchian structural high
      const double bar_low = iLow(_Symbol, tf, shift);   // perf-allowed: bounded Donchian structural low
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return false;
      if(bar_high > donchian_high)
         donchian_high = bar_high;
      if(bar_low < donchian_low)
         donchian_low = bar_low;
     }
   if(donchian_high <= 0.0 || donchian_low <= 0.0 || donchian_high <= donchian_low)
      return false;

   const double channel_height = donchian_high - donchian_low;
   if(channel_height > strategy_compression_atr_mult * atr)
      return false;
   // Breakout candle (just-closed bar) extremes for the range-explosion filter.
   const double high_1 = iHigh(_Symbol, tf, 1); // perf-allowed: breakout candle range check
   const double low_1 = iLow(_Symbol, tf, 1);   // perf-allowed: breakout candle range check
   if(high_1 <= 0.0 || low_1 <= 0.0 || high_1 <= low_1)
      return false;
   if((high_1 - low_1) > strategy_breakout_range_atr_mult * atr)
      return false;

   // Breakout direction on the just-closed bar via the framework signal. It
   // evaluates close[1] against the same prior-N Donchian window computed above
   // (shift+1..shift+lookback), so no raw iClose is needed in the EA.
   const int brk = QM_Sig_Range_Breakout(_Symbol, tf, strategy_donchian_lookback, 1);
   if(brk == 0)
      return false;

   const double adx_1 = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   const double adx_2 = QM_ADX(_Symbol, tf, strategy_adx_period, 2);
   if(adx_1 <= strategy_breakout_adx_level || adx_2 > strategy_breakout_adx_level || adx_1 <= adx_2)
      return false;

   const double plus_di = QM_ADX_PlusDI(_Symbol, tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, tf, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   static double last_traded_high = 0.0;
   static double last_traded_low = 0.0;
   static int    last_traded_side = 0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double same_range_tolerance = (point > 0.0) ? point * 0.5 : 0.00000001;

   int side = 0;
   if(brk > 0 && plus_di > minus_di)
      side = 1;
   else if(brk < 0 && minus_di > plus_di)
      side = -1;
   else
      return false;

   if(last_traded_side == side &&
      MathAbs(last_traded_high - donchian_high) <= same_range_tolerance &&
      MathAbs(last_traded_low - donchian_low) <= same_range_tolerance)
      return false;

   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double midpoint = (donchian_high + donchian_low) * 0.5;
   double sl = 0.0;
   if(side > 0)
     {
      const double atr_stop = entry - strategy_sl_atr_mult * atr;
      sl = atr_stop;
      if(midpoint > 0.0 && midpoint < entry)
         sl = MathMax(midpoint, atr_stop);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + (entry - req.sl) * strategy_tp_r_multiple, _Digits);
      req.reason = "adx_donchian_breakout_long";
     }
   else
     {
      const double atr_stop = entry + strategy_sl_atr_mult * atr;
      sl = atr_stop;
      if(midpoint > entry)
         sl = MathMin(midpoint, atr_stop);
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - (req.sl - entry) * strategy_tp_r_multiple, _Digits);
      req.reason = "adx_donchian_breakout_short";
     }

   req.price = 0.0;
   last_traded_high = donchian_high;
   last_traded_low = donchian_low;
   last_traded_side = side;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_tp <= 0.0)
         continue;

      // Initial risk R recovered from the entry geometry (TP = entry + 2R, fixed
      // at open and never moved), so no per-trade file-scope state is required.
      const double original_r = MathAbs(current_tp - open_price) / strategy_tp_r_multiple;
      if(original_r <= 0.0)
         continue;

      const double market_price = (position_type == POSITION_TYPE_BUY)
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double favorable = (position_type == POSITION_TYPE_BUY)
                               ? (market_price - open_price)
                               : (open_price - market_price);

      // Card: trail after +1.5R using 2*ATR. QM_TM_TrailATR trails the SL to
      // market -/+ 2*ATR and only ever tightens (favourable-only), which is the
      // framework primitive closest to the card's "2*ATR from the extreme close".
      if(favorable >= strategy_trail_trigger_r * original_r)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double adx_1 = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
      if(adx_1 > 0.0 && adx_1 < strategy_exit_adx_level)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && TimeCurrent() - opened_at >= strategy_max_hold_bars * PeriodSeconds(PERIOD_H1))
         return true;
     }

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
