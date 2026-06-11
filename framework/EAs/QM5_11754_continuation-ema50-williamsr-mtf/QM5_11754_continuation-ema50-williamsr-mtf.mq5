#property strict
#property version   "5.0"
#property description "QM5_11754 Continuation EMA50 WilliamsR MTF"

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
input int    qm_ea_id                   = 11754;
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
input int    strategy_ema_period        = 50;
input int    strategy_wpr_period        = 14;
input double strategy_wpr_oversold      = -80.0;
input double strategy_wpr_overbought    = -20.0;
input int    strategy_trail_sma_period  = 5;
input double strategy_trail_rr_trigger  = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_tp_mult       = 5.0;
input int    strategy_sl_buffer_points  = 10;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: the card defines no session, spread, or regime veto
   // beyond the central framework news, kill-switch, and Friday-close gates.
   if(_Period != PERIOD_H4)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: D1 EMA50 trend, H4 EMA50 pullback, H4 Williams %R re-entry.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period < 2 || strategy_wpr_period < 2 ||
      strategy_trail_sma_period < 2 || strategy_atr_period < 1 ||
      strategy_atr_tp_mult <= 0.0 || strategy_trail_rr_trigger <= 0.0)
      return false;

   const string sym = _Symbol;
   const double d1_close = iClose(sym, PERIOD_D1, 1); // perf-allowed: closed-bar card price reference
   const double d1_ema = QM_EMA(sym, PERIOD_D1, strategy_ema_period, 1);
   const double d1_ema_prev = QM_EMA(sym, PERIOD_D1, strategy_ema_period, 2);
   const double h4_close = iClose(sym, PERIOD_H4, 1); // perf-allowed: closed signal-bar pullback check
   const double h4_high = iHigh(sym, PERIOD_H4, 1); // perf-allowed: signal-bar structure stop
   const double h4_low = iLow(sym, PERIOD_H4, 1); // perf-allowed: signal-bar structure stop
   const double h4_ema = QM_EMA(sym, PERIOD_H4, strategy_ema_period, 1);
   const double wpr_now = QM_WPR(sym, PERIOD_H4, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(sym, PERIOD_H4, strategy_wpr_period, 2);
   const double atr = QM_ATR(sym, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   if(d1_close <= 0.0 || d1_ema <= 0.0 || d1_ema_prev <= 0.0 ||
      h4_close <= 0.0 || h4_high <= 0.0 || h4_low <= 0.0 ||
      h4_ema <= 0.0 || atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_buffer = (double)strategy_sl_buffer_points * point;
   const bool d1_up = (d1_close > d1_ema && d1_ema > d1_ema_prev);
   const bool d1_down = (d1_close < d1_ema && d1_ema < d1_ema_prev);
   const bool long_pullback = (h4_close < h4_ema);
   const bool short_pullback = (h4_close > h4_ema);
   const bool long_wpr_cross = (wpr_prev <= strategy_wpr_oversold && wpr_now > strategy_wpr_oversold);
   const bool short_wpr_cross = (wpr_prev >= strategy_wpr_overbought && wpr_now < strategy_wpr_overbought);

   if(d1_up && long_pullback && long_wpr_cross)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(h4_low - stop_buffer, _Digits);
      req.tp = NormalizeDouble(ask + atr * strategy_atr_tp_mult, _Digits);
      req.reason = "EMA50_D1_H4_WPR_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(d1_down && short_pullback && short_wpr_cross)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(h4_high + stop_buffer, _Digits);
      req.tp = NormalizeDouble(bid - atr * strategy_atr_tp_mult, _Digits);
      req.reason = "EMA50_D1_H4_WPR_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: after price reaches 2R, trail SL with the last two
   // H4 closes relative to SMA(5), as specified by the card.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: O(1) closed-bar trail reference
   const double close2 = iClose(_Symbol, PERIOD_H4, 2); // perf-allowed: O(1) closed-bar trail reference
   const double sma1 = QM_SMA(_Symbol, PERIOD_H4, strategy_trail_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_H4, strategy_trail_sma_period, 2);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0 ||
      bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
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

      const double risk = MathAbs(open_price - current_sl);
      if(risk <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         if((bid - open_price) < risk * strategy_trail_rr_trigger)
            continue;
         if(!(close1 < sma1 && close2 < sma2))
            continue;
         const double new_sl = NormalizeDouble(MathMin(close1, close2), _Digits);
         if(new_sl > current_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "SMA5_AFTER_2R_LONG");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if((open_price - ask) < risk * strategy_trail_rr_trigger)
            continue;
         if(!(close1 > sma1 && close2 > sma2))
            continue;
         const double new_sl = NormalizeDouble(MathMax(close1, close2), _Digits);
         if(new_sl < current_sl && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "SMA5_AFTER_2R_SHORT");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: no discretionary close beyond SL, ATR hard TP, SMA5 trail,
   // framework Friday close, kill-switch, and news gates.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: defer to the V5 two-axis framework news filter.
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
