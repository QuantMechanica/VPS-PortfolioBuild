#property strict
#property version   "5.0"
#property description "QM5_9501 Pring KST Signal-Line Cross (D1-native W1-rescale)"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
//
// CARD-MANDATED RESCALE (documented, DWX backtest invariant #10 extended to
// W1): the approved card defines Pring's long-term KST on PERIOD_W1, but
// QM_Indicators.mqh's own QM_CalendarPeriodKey documents that ".DWX custom
// symbols yield 0 bars on MN1/W1 in the tester" — the same limitation the
// framework already works around for monthly strategies by going D1-native
// with a bars-per-period proxy. This EA applies the identical rescue: every
// W1 lookback in the card is multiplied by 5 (5 trading days/week) and
// evaluated on PERIOD_D1 closed bars instead. The KST cross-detection logic
// itself is untouched — only the bar unit changes.
//
// CARD-MANDATED DEVIATION: the card's whipsaw guard ("no fresh entry within
// 4 W1 bars of a prior SL exit") requires knowing whether the last close of
// this magic's position was SL-triggered, which the 5 standard Strategy_
// hooks cannot see. OnTradeTransaction below therefore carries one extra
// call (Strategy_OnTradeTransactionHook) alongside the mandatory
// QM_FrameworkOnTradeTransaction call — a minimal, additive wiring change,
// not a reimplementation of any framework primitive.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9501;
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
// Card explicitly excludes news filtering from this W1-cadence strategy
// ("news_calendar HIGH events are intra-day phenomena that average out over
// a W1 holding period") — Axis A defaults OFF here, unlike the framework's
// usual PRE30_POST30 default. Axis B (DXZ prop-firm compliance overlay) is a
// separate, mandatory Hard-Rule concern and stays on regardless of holding
// period.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// KST composite, D1-native (W1 lookbacks x5 — see header rescale note).
input int    strategy_roc1_lookback      = 45;   // 9 W1 bars
input int    strategy_roc2_lookback      = 60;   // 12 W1 bars
input int    strategy_roc3_lookback      = 90;   // 18 W1 bars
input int    strategy_roc4_lookback      = 120;  // 24 W1 bars
input int    strategy_smooth_123         = 30;   // 6 W1 bars — rcma1/2/3 smoothing
input int    strategy_smooth_4           = 45;   // 9 W1 bars — rcma4 smoothing
input int    strategy_signal_smooth      = 45;   // 9 W1 bars — Signal = SMA(KST, .)
input int    strategy_bias_sma_period    = 200;  // 40 W1 bars — long-term bias filter
input int    strategy_atr_period         = 70;   // 14 W1 bars — stop + spread-filter ATR
input double strategy_atr_stop_mult      = 3.0;
input int    strategy_time_stop_days     = 130;  // 26 W1 bars (~6 months)
input int    strategy_whipsaw_guard_days = 20;   // 4 W1 bars post-SL cooldown
input double strategy_spread_atr_frac    = 0.05;

// -----------------------------------------------------------------------------
// KST composite — pure array arithmetic over one bounded CopyClose read
// (perf-allowed: one structural read per closed D1 bar, not per tick).
// -----------------------------------------------------------------------------

double KST_ROC(const double &closes[], const int idx_now, const int lookback)
  {
   const int idx_then = idx_now + lookback;
   return (closes[idx_now] - closes[idx_then]) / closes[idx_then] * 100.0;
  }

double KST_RCMA(const double &closes[], const int base_idx, const int lookback, const int smooth)
  {
   double sum = 0.0;
   for(int j = 0; j < smooth; ++j)
      sum += KST_ROC(closes, base_idx + j, lookback);
   return sum / (double)smooth;
  }

double KST_Value(const double &closes[], const int base_idx)
  {
   const double rcma1 = KST_RCMA(closes, base_idx, strategy_roc1_lookback, strategy_smooth_123);
   const double rcma2 = KST_RCMA(closes, base_idx, strategy_roc2_lookback, strategy_smooth_123);
   const double rcma3 = KST_RCMA(closes, base_idx, strategy_roc3_lookback, strategy_smooth_123);
   const double rcma4 = KST_RCMA(closes, base_idx, strategy_roc4_lookback, strategy_smooth_4);
   return 1.0 * rcma1 + 2.0 * rcma2 + 3.0 * rcma3 + 4.0 * rcma4;
  }

double KST_Signal(const double &closes[], const int base_idx)
  {
   double sum = 0.0;
   for(int j = 0; j < strategy_signal_smooth; ++j)
      sum += KST_Value(closes, base_idx + j);
   return sum / (double)strategy_signal_smooth;
  }

// Returns KST/Signal at the current closed D1 bar (shift=1, base_idx=0) and
// the prior closed bar (shift=2, base_idx=1) for cross detection, plus the
// current closed-bar close for the bias-MA filter.
bool ComputeKSTSeries(double &kst_1, double &signal_1,
                      double &kst_2, double &signal_2,
                      double &close_1)
  {
   if(strategy_roc1_lookback < 1 || strategy_roc2_lookback < 1 ||
      strategy_roc3_lookback < 1 || strategy_roc4_lookback < 1 ||
      strategy_smooth_123 < 1 || strategy_smooth_4 < 1 || strategy_signal_smooth < 1)
      return false;

   const int max_smooth = MathMax(strategy_smooth_123, strategy_smooth_4);
   const int max_lookback = MathMax(MathMax(strategy_roc1_lookback, strategy_roc2_lookback),
                                    MathMax(strategy_roc3_lookback, strategy_roc4_lookback));
   const int need = 1 + (strategy_signal_smooth - 1) + (max_smooth - 1) + max_lookback + 5;

   double closes[];
   ArrayResize(closes, need);
   ArraySetAsSeries(closes, true);
   // Replaces ~10k+ per-point CopyRates calls the naive per-term
   // implementation would otherwise require; only called from the
   // closed-bar-gated EntrySignal / self-gated ExitSignal paths.
   if(CopyClose(_Symbol, PERIOD_D1, 1, need, closes) != need) // perf-allowed: one bounded structural close-price read per closed D1 bar
      return false;
   for(int i = 0; i < need; ++i)
      if(closes[i] <= 0.0)
         return false;

   close_1 = closes[0];
   kst_1 = KST_Value(closes, 0);
   signal_1 = KST_Signal(closes, 0);
   kst_2 = KST_Value(closes, 1);
   signal_2 = KST_Signal(closes, 1);
   return true;
  }

string WhipsawKey()
  {
   return StringFormat("QM_9501_WHIPSAW_%d", qm_ea_id * 10000 + qm_magic_slot_offset);
  }

// DWX invariant #1: only block a genuinely wide spread; never fail-closed on
// the zero-modeled-spread .DWX backtest reading.
bool PassesSpreadFilter(const double atr_now)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || bid >= ask)
      return true;
   const double cap = strategy_spread_atr_frac * atr_now;
   if(cap <= 0.0)
      return true;
   return ((ask - bid) <= cap);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: bidirectional KST/Signal cross with 200-D1 (40W1) bias filter
// and zero-line confirmation, plus a post-SL-exit whipsaw cooldown.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bias_sma_period < 2 || strategy_atr_period < 1 || strategy_atr_stop_mult <= 0.0)
      return false;

   double kst_1 = 0.0, signal_1 = 0.0, kst_2 = 0.0, signal_2 = 0.0, close_1 = 0.0;
   if(!ComputeKSTSeries(kst_1, signal_1, kst_2, signal_2, close_1))
      return false;

   const double bias_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_bias_sma_period, 1, PRICE_CLOSE);
   if(bias_sma <= 0.0)
      return false;

   const bool cross_up = (kst_2 <= signal_2) && (kst_1 > signal_1);
   const bool cross_down = (kst_2 >= signal_2) && (kst_1 < signal_1);

   const bool want_long = (close_1 > bias_sma) && cross_up && (kst_1 > 0.0);
   const bool want_short = (close_1 < bias_sma) && cross_down && (kst_1 < 0.0);
   if(!want_long && !want_short)
      return false;

   if(strategy_whipsaw_guard_days > 0 && GlobalVariableCheck(WhipsawKey()))
     {
      const datetime last_sl_exit = (datetime)GlobalVariableGet(WhipsawKey());
      if(last_sl_exit > 0)
        {
         const int held_days = QM_TM_HeldPeriods(_Symbol, PERIOD_D1, last_sl_exit, TimeCurrent());
         if(held_days >= 0 && held_days < strategy_whipsaw_guard_days)
            return false;
        }
     }

   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   if(!PassesSpreadFilter(atr_now))
      return false;

   const QM_OrderType order_type = want_long ? QM_BUY : QM_SELL;
   const double entry_price = SymbolInfoDouble(_Symbol, want_long ? SYMBOL_ASK : SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double stop_price = QM_StopATR(_Symbol, order_type, entry_price,
                                        strategy_atr_period, strategy_atr_stop_mult);
   if(stop_price <= 0.0)
      return false;
   if(order_type == QM_BUY && stop_price >= entry_price)
      return false;
   if(order_type == QM_SELL && stop_price <= entry_price)
      return false;

   req.type = order_type;
   req.sl = stop_price;
   req.reason = StringFormat("PRING_KST_%s kst=%.4f signal=%.4f", want_long ? "LONG" : "SHORT", kst_1, signal_1);
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial-close
// or scale-in rule. The ATR stop is server-side from entry.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: evaluate only once per D1 calendar edge. Close on the opposite
// KST/Signal cross or after the card's 26-W1-bar (130 D1) time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return false;

   if(strategy_time_stop_days > 0)
     {
      const int held_days = QM_TM_HeldPeriodsForMagic((long)magic, _Symbol, PERIOD_D1, TimeCurrent());
      if(held_days >= strategy_time_stop_days)
         return true;
     }

   double kst_1 = 0.0, signal_1 = 0.0, kst_2 = 0.0, signal_2 = 0.0, close_1 = 0.0;
   if(!ComputeKSTSeries(kst_1, signal_1, kst_2, signal_2, close_1))
      return false;

   const bool cross_up = (kst_2 <= signal_2) && (kst_1 > signal_1);
   const bool cross_down = (kst_2 >= signal_2) && (kst_1 < signal_1);

   bool is_long = false, is_short = false;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      is_long = (ptype == POSITION_TYPE_BUY);
      is_short = (ptype == POSITION_TYPE_SELL);
      break;
     }

   if(is_long)
      return cross_down;
   if(is_short)
      return cross_up;
   return false;
  }

// News Filter Hook: no card-specific override. Axis A is OFF by default input
// (card excludes news filtering from this W1-cadence strategy); Axis B (DXZ
// compliance) remains available via the framework's callable two-axis gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Whipsaw guard bookkeeping: record the timestamp of any SL-triggered close
// of this magic's position so EntrySignal can enforce the card's post-SL
// cooldown. Only DEAL_REASON_SL closing deals are recorded; signal/time-stop
// exits (closed by our own code, not the broker stop) do not arm the guard.
void Strategy_OnTradeTransactionHook(const MqlTradeTransaction &trans)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic())
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;
   const ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   if(reason == DEAL_REASON_SL)
      GlobalVariableSet(WhipsawKey(), (double)TimeCurrent());
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // CARD-MANDATED DEVIATION (see header comment): whipsaw-guard bookkeeping.
   Strategy_OnTradeTransactionHook(trans);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
