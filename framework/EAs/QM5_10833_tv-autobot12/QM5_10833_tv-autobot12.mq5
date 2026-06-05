#property strict
#property version   "5.0"
#property description "QM5_10833 TradingView AutoTrade Bot v12 Sweep Momentum"

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
input int    qm_ea_id                   = 10833;
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
input ENUM_TIMEFRAMES strategy_trend_tf              = PERIOD_H1;
input int             strategy_htf_ema_period        = 115;
input int             strategy_hma_period            = 20;
input int             strategy_sweep_lookback_bars   = 14;
input int             strategy_williams_period       = 14;
input int             strategy_atr_period            = 14;
input double          strategy_stop_atr_buffer_frac  = 0.10;
input double          strategy_target_rr             = 5.0;
input int             strategy_mode                  = 2;      // 0=HP only, 1=LP only, 2=HP+LP
input double          strategy_max_spread_points     = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool Strategy_LoadBars(MqlRates &bars[])
  {
   const int sweep_lookback = MathMax(2, MathMin(strategy_sweep_lookback_bars, 100));
   const int wpr_period = MathMax(2, MathMin(strategy_williams_period, 100));
   const int need = MathMax(sweep_lookback + 3, wpr_period + 3);
   ArrayResize(bars, need);
   ArraySetAsSeries(bars, true);
   return (CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need, bars) == need); // perf-allowed: bounded sweep/Williams window, called only after QM_IsNewBar.
  }

bool Strategy_LoadTrendBars(MqlRates &htf_bars[])
  {
   ArrayResize(htf_bars, 2);
   ArraySetAsSeries(htf_bars, true);
   return (CopyRates(_Symbol, strategy_trend_tf, 1, 2, htf_bars) == 2); // perf-allowed: two closed H1 trend bars, called only after QM_IsNewBar.
  }

bool Strategy_SwingExtremes(const MqlRates &bars[],
                            const int lookback,
                            double &swing_high,
                            double &swing_low)
  {
   const int capped = MathMax(2, MathMin(lookback, 100));
   if(ArraySize(bars) < capped + 1)
      return false;

   swing_high = bars[1].high;
   swing_low = bars[1].low;
   for(int i = 2; i <= capped; ++i)
     {
      swing_high = MathMax(swing_high, bars[i].high);
      swing_low = MathMin(swing_low, bars[i].low);
     }

   return (swing_high > swing_low && swing_low > 0.0);
  }

double Strategy_WilliamsR(const MqlRates &bars[], const int start_idx, const int period)
  {
   const int capped = MathMax(2, MathMin(period, 100));
   if(start_idx < 0 || ArraySize(bars) < start_idx + capped)
      return 0.0;

   double highest = bars[start_idx].high;
   double lowest = bars[start_idx].low;
   for(int i = start_idx + 1; i < start_idx + capped; ++i)
     {
      highest = MathMax(highest, bars[i].high);
      lowest = MathMin(lowest, bars[i].low);
     }

   const double range = highest - lowest;
   if(range <= 0.0)
      return 0.0;
   return -100.0 * (highest - bars[start_idx].close) / range;
  }

bool Strategy_TrendAligned(const bool want_long, const MqlRates &htf_bars[], const MqlRates &bar)
  {
   if(ArraySize(htf_bars) < 2)
      return false;

   const int ema_period = MathMax(2, strategy_htf_ema_period);
   const int hma_period = MathMax(4, strategy_hma_period);
   const double ema_1 = QM_EMA(_Symbol, strategy_trend_tf, ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, strategy_trend_tf, ema_period, 2);
   const double hma_1 = QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, hma_period, 1);
   const double hma_2 = QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, hma_period, 2);
   if(ema_1 <= 0.0 || ema_2 <= 0.0 || hma_1 <= 0.0 || hma_2 <= 0.0)
      return false;

   if(want_long)
      return (ema_1 > ema_2 && htf_bars[0].close > ema_1 &&
              (hma_1 > hma_2 || bar.close > hma_1));

   return (ema_1 < ema_2 && htf_bars[0].close < ema_1 &&
           (hma_1 < hma_2 || bar.close < hma_1));
  }

bool Strategy_BuildRequest(const bool want_long,
                           const string reason,
                           const double sweep_extreme,
                           QM_EntryRequest &req)
  {
   const double entry = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0 || sweep_extreme <= 0.0)
      return false;

   const double buffer = atr * MathMax(0.0, strategy_stop_atr_buffer_frac);
   const double sl = want_long ? sweep_extreme - buffer : sweep_extreme + buffer;
   if(sl <= 0.0 || MathAbs(entry - sl) < point * 10.0)
      return false;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;

   const QM_OrderType side = want_long ? QM_BUY : QM_SELL;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, MathMax(0.1, strategy_target_rr));
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllows())
      return true;

   return false; // no card-specific time filter; news is handled by the framework hook below.
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(Strategy_HasOpenPosition())
      return false;

   MqlRates bars[];
   MqlRates htf_bars[];
   if(!Strategy_LoadBars(bars) || !Strategy_LoadTrendBars(htf_bars))
      return false;

   const MqlRates bar = bars[0];
   double swing_high = 0.0;
   double swing_low = 0.0;
   if(!Strategy_SwingExtremes(bars, strategy_sweep_lookback_bars, swing_high, swing_low))
      return false;

   const double wpr_now = Strategy_WilliamsR(bars, 0, strategy_williams_period);
   const double wpr_prev = Strategy_WilliamsR(bars, 1, strategy_williams_period);
   const bool allow_hp = (strategy_mode == 0 || strategy_mode == 2);
   const bool allow_lp = (strategy_mode == 1 || strategy_mode == 2);

   if(allow_hp && bar.low < swing_low && bar.close > swing_low &&
      wpr_prev <= -80.0 && wpr_now > -80.0 &&
      Strategy_TrendAligned(true, htf_bars, bar))
      return Strategy_BuildRequest(true, "TV_AUTOBOT12_HP_LONG", bar.low, req);

   if(allow_hp && bar.high > swing_high && bar.close < swing_high &&
      wpr_prev >= -20.0 && wpr_now < -20.0 &&
      Strategy_TrendAligned(false, htf_bars, bar))
      return Strategy_BuildRequest(false, "TV_AUTOBOT12_HP_SHORT", bar.high, req);

   if(allow_lp && bar.low > swing_low && bar.close > bars[1].close &&
      Strategy_TrendAligned(true, htf_bars, bar))
      return Strategy_BuildRequest(true, "TV_AUTOBOT12_LP_LONG", bar.low, req);

   if(allow_lp && bar.high < swing_high && bar.close < bars[1].close &&
      Strategy_TrendAligned(false, htf_bars, bar))
      return Strategy_BuildRequest(false, "TV_AUTOBOT12_LP_SHORT", bar.high, req);

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP management only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
// Trade Close
bool Strategy_ExitSignal()
  {
   // Card specifies no discretionary close beyond SL/TP and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
// News Filter Hook
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
