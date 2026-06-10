#property strict
#property version   "5.0"
#property description "QM5_9457 Geraked Bollinger RSI Re-Entry (gk-bbrsi)"
// Strategy Card: QM5_9457 (gk-bbrsi), G0 APPROVED 2026-05-19.
// Source: geraked/metatrader5, BBRSI.mq5 (Geraked/Rabist)
// Mechanik: BB(500,2) + RSI(7) mean-reversion re-entry on M5.

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
input int    qm_ea_id                   = 9457;
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
// BB(500, 2.0) + RSI(7) re-entry mean-reversion. Card §Entry/Exit/Stop.
input int    strategy_bb_period         = 500;   // Bollinger band period (card default)
input double strategy_bb_deviation      = 2.0;   // Bollinger band deviation
input int    strategy_rsi_period        = 7;     // RSI period (card default)
input double strategy_tp_coef           = 1.0;   // TP = tp_coef * SL distance (card TPCoef=1)
input double strategy_sl_dev_mult       = 0.9;   // SL extension beyond band: 0.9 * band_half_width
input int    strategy_max_hold_bars     = 72;    // Time exit after N M5 bars (card default)

// =============================================================================
// Global state — open position tracking for time-stop and middle-band exit.
// =============================================================================

// Track bar count since entry for time-stop.
// Keyed per ticket — only one position at a time due to MultipleOpenPos=false.
datetime g_entry_bar_time  = 0;  // iTime(_Symbol, _Period, 0) at entry bar
int      g_bars_in_trade   = 0;

// -----------------------------------------------------------------------------
// Helper: count how many M5 bars have elapsed since g_entry_bar_time
// Incremented on each new bar when in trade.
// -----------------------------------------------------------------------------
void UpdateBarsInTrade()
  {
   if(g_entry_bar_time <= 0)
      return;
   const datetime t0 = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-time read for time-stop tracking
   if(t0 > g_entry_bar_time)
     {
      // Estimate bars: each M5 bar = 5 minutes. Count via index shift.
      // We simply increment on every new bar poll.
      g_bars_in_trade++;
     }
  }

// Helper: do we have a position for our magic?
bool HasOurPosition(ulong &out_ticket, ENUM_POSITION_TYPE &out_type, double &out_open)
  {
   out_ticket = 0;
   out_open   = 0.0;
   out_type   = POSITION_TYPE_BUY;
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
      out_ticket = ticket;
      out_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      out_open   = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // One-position gate: if we already have an open position, suppress new entries.
   ulong   dummy_ticket = 0;
   ENUM_POSITION_TYPE dummy_type = POSITION_TYPE_BUY;
   double  dummy_open  = 0.0;
   if(HasOurPosition(dummy_ticket, dummy_type, dummy_open))
      return true;  // block new entries while position is open
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

   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0 || strategy_rsi_period < 2)
      return false;

   // Indicator values at bar[1] and bar[2] (closed bars only).
   // BB on PRICE_CLOSE (card default, standard isBands default).
   const double bb_upper_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_middle_1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);

   const double bb_upper_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   const double bb_lower_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);

   if(bb_upper_1 <= 0.0 || bb_middle_1 <= 0.0 || bb_lower_1 <= 0.0)
      return false;
   if(bb_upper_2 <= 0.0 || bb_lower_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_CLOSE);

   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar close for band re-entry entry signal
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: prior bar close for oversold/overbought confirmation

   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   // Band half-width at bar[1] for SL calculation.
   const double band_half_1 = bb_middle_1 - bb_lower_1;

   // ------------------------------------------------------------------
   // BUY signal: bar[2] oversold below lower band; bar[1] re-enters.
   // bar[2]: RSI[2] < 30 AND close[2] < lower[2]
   // bar[1]: 30 < RSI[1] < 50 AND close[1] < middle[1] AND close[1] > lower[1]
   // ------------------------------------------------------------------
   if(rsi_2 < 30.0 && close_2 < bb_lower_2 &&
      rsi_1 > 30.0 && rsi_1 < 50.0 &&
      close_1 > bb_lower_1 && close_1 < bb_middle_1)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      // SL: lower[1] - 0.9 * (middle[1] - lower[1])
      const double sl_price = bb_lower_1 - strategy_sl_dev_mult * band_half_1;
      if(sl_price <= 0.0 || sl_price >= ask)
         return false;

      const double sl_dist = ask - sl_price;
      if(sl_dist <= 0.0)
         return false;

      const double tp_price = ask + sl_dist * strategy_tp_coef;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp     = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "GKBBRSI_BUY_REENTRY";
      return true;
     }

   // ------------------------------------------------------------------
   // SELL signal: bar[2] overbought above upper band; bar[1] re-enters.
   // bar[2]: RSI[2] > 70 AND close[2] > upper[2]
   // bar[1]: 50 < RSI[1] < 70 AND close[1] > middle[1] AND close[1] < upper[1]
   // ------------------------------------------------------------------
   if(rsi_2 > 70.0 && close_2 > bb_upper_2 &&
      rsi_1 > 50.0 && rsi_1 < 70.0 &&
      close_1 < bb_upper_1 && close_1 > bb_middle_1)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      // SL: upper[1] + 0.9 * (upper[1] - middle[1])
      const double sl_price = bb_upper_1 + strategy_sl_dev_mult * band_half_1;
      if(sl_price <= 0.0 || sl_price <= bid)
         return false;

      const double sl_dist = sl_price - bid;
      if(sl_dist <= 0.0)
         return false;

      const double tp_price = bid - sl_dist * strategy_tp_coef;
      if(tp_price <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = NormalizeDouble(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.tp     = NormalizeDouble(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      req.reason = "GKBBRSI_SELL_REENTRY";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines no trailing or break-even management.
   // Track bars-in-trade for time-stop in Strategy_ExitSignal.
   if(QM_IsNewBar())
      UpdateBarsInTrade();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong   ticket  = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   double  open_price = 0.0;

   if(!HasOurPosition(ticket, pos_type, open_price))
     {
      // No position: reset tracking state.
      if(g_entry_bar_time > 0)
        {
         g_entry_bar_time = 0;
         g_bars_in_trade  = 0;
        }
      return false;
     }

   // Record entry bar time on first sight of position.
   if(g_entry_bar_time <= 0)
     {
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: record entry bar time for time-stop
      g_bars_in_trade  = 0;
     }

   // ------------------------------------------------------------------
   // Time stop: close after strategy_max_hold_bars M5 bars.
   // ------------------------------------------------------------------
   if(strategy_max_hold_bars > 0 && g_bars_in_trade >= strategy_max_hold_bars)
      return true;

   // ------------------------------------------------------------------
   // Middle-band crossover exit (card: optional source close rule).
   // Close buy when close crosses ABOVE middle band.
   // Close sell when close crosses BELOW middle band.
   // Only triggers on new bar.
   // ------------------------------------------------------------------
   if(!QM_IsNewBar())
      return false;

   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0)
      return false;

   const double mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   if(mid <= 0.0)
      return false;
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar close for middle-band crossover exit
   if(close_1 <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY && close_1 > mid)
      return true;
   if(pos_type == POSITION_TYPE_SELL && close_1 < mid)
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

   g_entry_bar_time = 0;
   g_bars_in_trade  = 0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9457_gk-bbrsi\",\"bb_period\":500,\"rsi_period\":7}");
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
      // Reset tracking after close.
      g_entry_bar_time = 0;
      g_bars_in_trade  = 0;
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
      if(QM_TM_OpenPosition(req, out_ticket))
        {
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: record entry bar time for time-stop tracking
         g_bars_in_trade  = 0;
        }
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
