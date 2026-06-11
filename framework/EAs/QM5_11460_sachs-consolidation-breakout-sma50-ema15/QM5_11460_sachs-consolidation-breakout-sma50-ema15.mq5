#property strict
#property version   "5.0"
#property description "QM5_11460 Sachs consolidation breakout SMA50 EMA15"

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
input int    qm_ea_id                   = 11460;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H4;
input int             strategy_sma_period        = 50;
input int             strategy_ema_period        = 15;
input int             strategy_atr_period        = 14;
input int             strategy_consol_min_bars   = 3;
input int             strategy_consol_max_bars   = 10;
input double          strategy_box_atr_mult      = 1.5;
input double          strategy_min_box_pips      = 10.0;
input double          strategy_max_box_pips      = 60.0;
input double          strategy_sl_buffer_pips    = 5.0;
input double          strategy_tp_atr_mult       = 2.0;
input double          strategy_max_spread_pips   = 20.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: time, spread, news. The framework owns time/news gates;
   // the card adds a 20-pip spread cap.
   if(strategy_max_spread_pips <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / pip > strategy_max_spread_pips);
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

   if(strategy_sma_period <= 1 || strategy_ema_period <= 1 ||
      strategy_tp_atr_mult <= 0.0 || strategy_sl_buffer_pips <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   if(pip <= 0.0 || strategy_atr_period <= 0 || strategy_box_atr_mult <= 0.0)
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   int box_bars = 0;
   bool box_ok = false;

   const int min_bars = MathMax(3, strategy_consol_min_bars);
   const int max_bars = MathMin(10, MathMax(min_bars, strategy_consol_max_bars));
   for(int bars = min_bars; bars <= max_bars && !box_ok; ++bars)
     {
      double hi = -DBL_MAX;
      double lo = DBL_MAX;
      for(int shift = 2; shift <= bars + 1; ++shift)
        {
         // perf-allowed: bounded structural box read, inside framework closed-bar entry gate.
         const double h = iHigh(_Symbol, strategy_signal_tf, shift);
         // perf-allowed: bounded structural box read, inside framework closed-bar entry gate.
         const double l = iLow(_Symbol, strategy_signal_tf, shift);
         if(h <= 0.0 || l <= 0.0 || h < l)
            return false;
         hi = MathMax(hi, h);
         lo = MathMin(lo, l);
        }

      const double width = hi - lo;
      const double width_pips = width / pip;
      if(width_pips < strategy_min_box_pips || width_pips > strategy_max_box_pips)
         continue;

      const double atr_ref = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, bars + 2);
      if(atr_ref <= 0.0)
         continue;

      if(width < atr_ref * strategy_box_atr_mult)
        {
         box_high = hi;
         box_low = lo;
         box_bars = bars;
         box_ok = true;
        }
     }

   if(!box_ok)
      return false;

   // perf-allowed: closed breakout bar read, inside framework closed-bar entry gate.
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close1 <= 0.0)
      return false;

   const double sma1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 1);
   const double sma3 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 3);
   const double sma5 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 5);
   const double ema1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   const double atr1 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(sma1 <= 0.0 || sma3 <= 0.0 || sma5 <= 0.0 || ema1 <= 0.0 || atr1 <= 0.0)
      return false;

   const bool downtrend = (sma3 < sma5 && ema1 < sma1);
   const bool uptrend = (sma3 > sma5 && ema1 > sma1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(downtrend && close1 < box_low && ema1 < box_low)
     {
      const double entry = bid;
      req.type = QM_SELL;
      req.sl = QM_TM_NormalizePrice(_Symbol, box_high + strategy_sl_buffer_pips * pip);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry - atr1 * strategy_tp_atr_mult);
      req.reason = StringFormat("SACHS_SHORT_BOX_%d", box_bars);
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   if(uptrend && close1 > box_high)
     {
      const double entry = ask;
      req.type = QM_BUY;
      req.sl = QM_TM_NormalizePrice(_Symbol, box_low - strategy_sl_buffer_pips * pip);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry + atr1 * strategy_tp_atr_mult);
      req.reason = StringFormat("SACHS_LONG_BOX_%d", box_bars);
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: card defines no trailing, break-even, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: close on EMA15 cross back through the last closed close.
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   bool found = false;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      found = true;
      break;
     }
   if(!found)
      return false;

   // perf-allowed: O(1) closed-bar exit reads; skeleton calls ExitSignal before the entry new-bar gate.
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   // perf-allowed: O(1) closed-bar exit reads; skeleton calls ExitSignal before the entry new-bar gate.
   const double close2 = iClose(_Symbol, strategy_signal_tf, 2);
   const double ema1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (close1 < ema1 && close2 >= ema2);
   if(ptype == POSITION_TYPE_SELL)
      return (close1 > ema1 && close2 <= ema2);

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to central framework news gates.
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
