#property strict
#property version   "5.0"
#property description "QM5_41487 Freqtrade BinHV45 Bollinger Drop Reversal (M5, FX+XAU, v2)"
// Strategy Card: QM5_41487 (ft-binhv45-v2), G0 APPROVED 2026-09-21.
// Second-Chance v2 of QM5_11211 (retired 2026-08-21, OWNER D1 disposition;
// original EA was never built) under revision f05399de. Original card
// rejected at G0 2026-05-23 on M1 (implausible cadence); this v2 reruns the
// mechanism on M5 per the Edge Lab charter design box (M5-M15 scalping).
// Source: "BinHV45.py", freqtrade-strategies (GitHub), commit
//         dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4. Source ID
//         1580128f-e465-5454-bb97-a7572a6cfd6d.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41487 — BinHV45 Bollinger capitulation reversal (v2)
// -----------------------------------------------------------------------------
// LONG only. On the closed M5 bar[1]:
//   1. lower[1] > 0                                        (valid warmup)
//   2. bbdelta[1] = |mid[1]-lower[1]| > close[1]*bbdelta_per_mille/1000
//   3. closedelta = |close[1]-close[2]| > close[1]*closedelta_per_mille/1000
//   4. tail = |close[1]-low[1]| < bbdelta[1]*tail_per_mille/1000
//   5. close[1] < lower[1]                                 (band pierce)
//   6. close[1] <= close[2]                                (negative close)
// Entry: market buy at open of the next bar (bar 0).
// Exit : TP = min(1.25% of entry, 1.5*ATR(14,M5)); SL = min(1.5*ATR(14,M5),
//        5% of entry) — both distances taken as the TIGHTER of the pair, same
//        "conservative execution" convention as the card's explicit SL Min()
//        formula. No discretionary signal exit (source has none); lifecycle
//        is TP / hard SL / Friday close only. See SPEC.md for the TP
//        interpretation note (card wording is a parenthetical "or", read as
//        Min for consistency with the SL formula and OWNER's conservative-
//        fills doctrine).
// Only the five Strategy_* hooks + two local helpers are strategy code; the
// OnInit/OnTick framework wiring below is the canonical skeleton, untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41487;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
// HR4: both risk inputs exist. Backtest defaults to RISK_FIXED ($1000); the
// live setfile sets RISK_PERCENT=0.5 and RISK_FIXED=0.
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period           = 40;    // Bollinger period (card: 40)
input double strategy_bb_deviation        = 2.0;    // Bollinger deviation (card: 2.0)
input double strategy_bbdelta_per_mille   = 7.0;    // band-expansion threshold, card default 7
input double strategy_closedelta_per_mille= 17.0;   // bar-velocity threshold, card baseline 17 (sweep [3,7,17])
input double strategy_tail_per_mille      = 25.0;   // minimal lower-tail threshold, card default 25
input double strategy_tp_pct              = 1.25;   // ROI target, % of entry price (card: +1.25%)
input double strategy_tp_atr_mult         = 1.5;    // ROI target ATR alternative (card: 1.5*ATR)
input int    strategy_atr_period          = 14;     // ATR period for TP/SL (card: ATR(14, M5))
input double strategy_sl_atr_mult         = 1.5;    // SL ATR component (card: 1.5*ATR)
input double strategy_sl_pct_cap          = 5.0;    // SL hard cap, % of entry (card: -5.0%)
input double strategy_spread_cap_pct_of_sl= 6.0;    // spread <= this % of planned stop distance (card: 6%)

// -----------------------------------------------------------------------------
// Local helpers (used only by the strategy hooks below).
// -----------------------------------------------------------------------------

// Safety-stop PRICE for `side` from `entry_ref`: tighter of 1.5*ATR(14,M5) and
// 5% of entry (card: "Min(1.5*ATR(14,M5), 0.05*entry_price)"). 0.0 => no
// valid stop (caller must refuse to enter).
double ComputeSafetyStop(const QM_OrderType side, const double entry_ref)
  {
   const double sl_atr = QM_StopATR(_Symbol, side, entry_ref, strategy_atr_period, strategy_sl_atr_mult);
   const double sl_pct_distance = entry_ref * (strategy_sl_pct_cap / 100.0);
   const double sl_pct = QM_StopRulesStopFromDistance(_Symbol, side, entry_ref, sl_pct_distance);
   if(sl_atr <= 0.0 && sl_pct <= 0.0)
      return 0.0;
   if(sl_atr <= 0.0)
      return sl_pct;
   if(sl_pct <= 0.0)
      return sl_atr;
   // BUY: stop sits below entry, tighter = higher price (smaller distance).
   return (side == QM_BUY) ? MathMax(sl_atr, sl_pct) : MathMin(sl_atr, sl_pct);
  }

// Take-profit PRICE for `side` from `entry_ref`: tighter of 1.25% of entry and
// 1.5*ATR(14,M5) — see the TP interpretation note in the header comment and
// SPEC.md. 0.0 => no valid target (caller must refuse to enter).
double ComputeTakeProfit(const QM_OrderType side, const double entry_ref)
  {
   const double tp_pct_distance = entry_ref * (strategy_tp_pct / 100.0);
   const double tp_pct = QM_StopRulesTakeFromDistance(_Symbol, side, entry_ref, tp_pct_distance);
   const double tp_atr = QM_TakeATR(_Symbol, side, entry_ref, strategy_atr_period, strategy_tp_atr_mult);
   if(tp_pct <= 0.0 && tp_atr <= 0.0)
      return 0.0;
   if(tp_pct <= 0.0)
      return tp_atr;
   if(tp_atr <= 0.0)
      return tp_pct;
   // BUY: target sits above entry, tighter = lower price (smaller distance).
   return (side == QM_BUY) ? MathMin(tp_pct, tp_atr) : MathMax(tp_pct, tp_atr);
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No per-tick no-trade filter beyond the entry-time spread gate below (card
// ties the spread cap to the planned stop distance of the candidate entry,
// which is only known once the BB/ATR setup evaluates — see
// Strategy_EntrySignal). Management/exit paths never need this filter.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: BinHV45 capitulation-drop setup on closed M5 bar[1]. Caller
// guarantees QM_IsNewBar()==true, so the closed-bar reads advance once/bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;   // 0 => framework fills market price
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic — single-entry capitulation reversal.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double mid_1   = QM_BB_Middle(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower_1 = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1);
   // perf-allowed: no QM close/low reader exists; closed-bar reads only (gated by QM_IsNewBar).
   const double close_1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed
   const double close_2 = iClose(_Symbol, PERIOD_M5, 2); // perf-allowed
   const double low_1   = iLow(_Symbol, PERIOD_M5, 1);   // perf-allowed

   if(mid_1 <= 0.0 || lower_1 <= 0.0 || close_1 <= 0.0 || close_2 <= 0.0 || low_1 <= 0.0)
      return false; // warmup / bad read — condition 1 (lower[1] > 0) folded in here

   const double bbdelta    = MathAbs(mid_1 - lower_1);
   const double closedelta = MathAbs(close_1 - close_2);
   const double tail       = MathAbs(close_1 - low_1);

   const bool cond_band_expansion = bbdelta > close_1 * (strategy_bbdelta_per_mille / 1000.0);
   const bool cond_velocity       = closedelta > close_1 * (strategy_closedelta_per_mille / 1000.0);
   const bool cond_tail           = tail < bbdelta * (strategy_tail_per_mille / 1000.0);
   const bool cond_pierce         = close_1 < lower_1;
   const bool cond_negative_close = close_1 <= close_2;

   if(!(cond_band_expansion && cond_velocity && cond_tail && cond_pierce && cond_negative_close))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double sl = ComputeSafetyStop(QM_BUY, ask);
   if(sl <= 0.0 || sl >= ask)
      return false; // refuse to enter without a valid safety stop

   const double stop_distance = ask - sl;
   if(stop_distance <= 0.0)
      return false;

   // Card: "Spread must be <= 6% of planned stop distance; skip entry during
   // spread widening." Gated here (entry-time only) since the planned stop
   // distance is only known once this setup evaluates.
   const double spread = ask - bid;
   if(spread > stop_distance * (strategy_spread_cap_pct_of_sl / 100.0))
      return false;

   const double tp = ComputeTakeProfit(QM_BUY, ask);
   if(tp <= 0.0 || tp <= ask)
      return false; // refuse to enter without a valid target

   req.type   = QM_BUY;
   req.reason = "QM5_41487_BINHV45_CAPITULATION_LONG";
   req.sl     = sl;
   req.tp     = tp;
   return true;
  }

// No trailing / break-even / partial logic — BinHV45 holds to the ROI target
// or the hard safety stop set at entry (card: "no sell signal"; lifecycle is
// ROI/SL/weekend-close only — see the TP/SL interpretation note above).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary signal exit — the source strategy has none (exit_long=0).
// Lifecycle is governed exclusively by the broker-side TP/SL attached at
// entry plus the framework's Friday-close sweep.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central 2-axis news filter (no custom high-impact handling).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_41487_ft_binhv45_v2\"}");
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
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick).
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

   // FW1 — 2-axis news check. Gates NEW entries only — never the
   // management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 — emit end-of-day equity snapshot if the day rolled since last tick.
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
