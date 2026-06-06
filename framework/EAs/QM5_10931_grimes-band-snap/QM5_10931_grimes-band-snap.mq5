#property strict
#property version   "5.0"
#property description "QM5_10931 Grimes Band Snapback"

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
input int    qm_ea_id                   = 10931;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H4;
input int             strategy_ema_period      = 20;
input int             strategy_atr_period      = 20;
input double          strategy_keltner_atr_mult = 2.25;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_long_max    = 30.0;
input double          strategy_rsi_short_min   = 70.0;
input int             strategy_slope_bars      = 5;
input double          strategy_max_slope_atr   = 0.75;
input double          strategy_stop_pad_atr    = 0.25;
input double          strategy_max_stop_atr    = 3.0;
input int             strategy_max_hold_bars   = 8;
input double          strategy_max_spread_stop_frac = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session/regime no-trade filter beyond entry-local spread/slide checks.
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

   if(strategy_ema_period <= 1 || strategy_atr_period <= 1 || strategy_rsi_period <= 1 ||
      strategy_slope_bars <= 0 || strategy_keltner_atr_mult <= 0.0 ||
      strategy_stop_pad_atr < 0.0 || strategy_max_stop_atr <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_timeframe, 1, 4, rates) < 4) // perf-allowed: closed-bar OHLC for signal low/high/close; caller is QM_IsNewBar-gated.
      return false;

   const double atr_signal = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema_signal = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double atr_prior = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 2);
   const double ema_prior = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 2);
   const double ema_slope_ref = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1 + strategy_slope_bars);
   if(atr_signal <= 0.0 || ema_signal <= 0.0 || atr_prior <= 0.0 || ema_prior <= 0.0 || ema_slope_ref <= 0.0)
      return false;

   const double lower_signal = ema_signal - strategy_keltner_atr_mult * atr_signal;
   const double upper_signal = ema_signal + strategy_keltner_atr_mult * atr_signal;
   const double lower_prior = ema_prior - strategy_keltner_atr_mult * atr_prior;
   const double upper_prior = ema_prior + strategy_keltner_atr_mult * atr_prior;
   const double ema_slope = ema_signal - ema_slope_ref;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask <= 0.0 || bid <= 0.0 || spread < 0.0)
      return false;

   bool last_three_below = true;
   bool last_three_above = true;
   for(int i = 1; i <= 3; ++i)
     {
      const int shift = i + 1;
      const double atr_i = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      const double ema_i = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
      if(atr_i <= 0.0 || ema_i <= 0.0)
         return false;
      const double lower_i = ema_i - strategy_keltner_atr_mult * atr_i;
      const double upper_i = ema_i + strategy_keltner_atr_mult * atr_i;
      if(rates[i].close >= lower_i)
         last_three_below = false;
      if(rates[i].close <= upper_i)
         last_three_above = false;
     }

   const double rsi_prior = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 2);

   if(rates[1].close < lower_prior &&
      rsi_prior <= strategy_rsi_long_max &&
      rates[0].close >= lower_signal &&
      ema_slope > -strategy_max_slope_atr * atr_signal &&
      !last_three_below)
     {
      const double sl = rates[0].low - strategy_stop_pad_atr * atr_signal;
      const double stop_dist = ask - sl;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr * atr_signal)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;
      if(ema_signal <= ask)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = ema_signal;
      req.reason = "GRIMES_BAND_SNAP_LONG";
      return true;
     }

   if(rates[1].close > upper_prior &&
      rsi_prior >= strategy_rsi_short_min &&
      rates[0].close <= upper_signal &&
      ema_slope < strategy_max_slope_atr * atr_signal &&
      !last_three_above)
     {
      const double sl = rates[0].high + strategy_stop_pad_atr * atr_signal;
      const double stop_dist = sl - bid;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr * atr_signal)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;
      if(ema_signal >= bid)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = ema_signal;
      req.reason = "GRIMES_BAND_SNAP_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double risk_dist = is_buy ? (open_price - current_sl) : (current_sl - open_price);
      if(risk_dist <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      const bool improves = is_buy ? (open_price > current_sl) : (open_price < current_sl);
      if(moved >= risk_dist && improves)
         QM_TM_MoveSL(ticket, open_price, "grimes_band_snap_1r_breakeven");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int hold_seconds = PeriodSeconds(strategy_timeframe) * strategy_max_hold_bars;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && position_time > 0 && TimeCurrent() - position_time >= hold_seconds)
         return true;

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, strategy_timeframe, 1, 1, rates) < 1) // perf-allowed: one closed bar for adverse same-band exit.
         continue;

      const double atr_signal = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      const double ema_signal = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
      if(atr_signal <= 0.0 || ema_signal <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double lower_signal = ema_signal - strategy_keltner_atr_mult * atr_signal;
      const double upper_signal = ema_signal + strategy_keltner_atr_mult * atr_signal;
      if(ptype == POSITION_TYPE_BUY && rates[0].close < lower_signal)
         return true;
      if(ptype == POSITION_TYPE_SELL && rates[0].close > upper_signal)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
