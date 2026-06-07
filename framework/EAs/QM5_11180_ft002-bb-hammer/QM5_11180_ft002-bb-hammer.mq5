#property strict
#property version   "5.0"
#property description "QM5_11180 FT002 Bollinger Hammer Reversal"

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
input int    qm_ea_id                   = 11180;
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
input int    strategy_rsi_period        = 14;
input double strategy_rsi_entry         = 30.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_slowk_entry = 20.0;
input int    strategy_bb_window         = 20;
input double strategy_bb_deviation      = 2.0;
input double strategy_fisher_exit       = 0.30;
input double strategy_stoploss_pct      = 10.0;
input double strategy_roi_0_pct         = 5.0;
input double strategy_roi_20_pct        = 4.0;
input double strategy_roi_30_pct        = 3.0;
input double strategy_roi_60_pct        = 1.0;
input bool   strategy_exit_profit_only  = true;
input int    strategy_atr_period        = 14;
input double strategy_max_spread_atr_pct = 15.0;
input double strategy_psar_step         = 0.02;
input double strategy_psar_maximum      = 0.20;
input int    strategy_psar_warmup_bars  = 120;

bool Strategy_ReadClosedBar(const int shift, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, shift, 1, rates);
   if(copied != 1)
      return false;

   bar = rates[0];
   return (bar.open > 0.0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

bool Strategy_IsHammer(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0)
      return false;

   const double body = MathAbs(bar.close - bar.open);
   if(body <= 0.0 || body > range * 0.35)
      return false;

   const double upper = bar.high - MathMax(bar.open, bar.close);
   const double lower = MathMin(bar.open, bar.close) - bar.low;
   return (lower >= body * 2.0 && upper <= body);
  }

double Strategy_FisherFromRSI(const double rsi)
  {
   double value = 0.1 * (rsi - 50.0);
   if(value > 10.0)
      value = 10.0;
   if(value < -10.0)
      value = -10.0;

   const double e = MathExp(2.0 * value);
   if(e <= 0.0)
      return 0.0;
   return (e - 1.0) / (e + 1.0);
  }

bool Strategy_ReadPSAR(const int shift, double &out_psar)
  {
   out_psar = 0.0;
   if(strategy_psar_step <= 0.0 || strategy_psar_maximum <= 0.0 ||
      strategy_psar_warmup_bars < 10)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = MathMax(strategy_psar_warmup_bars, 30);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, shift, bars_needed, rates);
   if(copied < 10)
      return false;

   int oldest = copied - 1;
   int prev = oldest - 1;
   bool uptrend = (rates[prev].close >= rates[oldest].close);
   double af = strategy_psar_step;
   double ep = uptrend ? MathMax(rates[oldest].high, rates[prev].high)
                       : MathMin(rates[oldest].low, rates[prev].low);
   double sar = uptrend ? MathMin(rates[oldest].low, rates[prev].low)
                        : MathMax(rates[oldest].high, rates[prev].high);

   for(int bar = oldest - 2; bar >= 0; --bar)
     {
      sar = sar + af * (ep - sar);

      if(uptrend)
        {
         sar = MathMin(sar, rates[bar + 1].low);
         sar = MathMin(sar, rates[bar + 2].low);
         if(rates[bar].low < sar)
           {
            uptrend = false;
            sar = ep;
            ep = rates[bar].low;
            af = strategy_psar_step;
           }
         else if(rates[bar].high > ep)
           {
            ep = rates[bar].high;
            af = MathMin(af + strategy_psar_step, strategy_psar_maximum);
           }
        }
      else
        {
         sar = MathMax(sar, rates[bar + 1].high);
         sar = MathMax(sar, rates[bar + 2].high);
         if(rates[bar].high > sar)
           {
            uptrend = true;
            sar = ep;
            ep = rates[bar].high;
            af = strategy_psar_step;
           }
         else if(rates[bar].low < ep)
           {
            ep = rates[bar].low;
            af = MathMin(af + strategy_psar_step, strategy_psar_maximum);
           }
        }
     }

   out_psar = NormalizeDouble(sar, _Digits);
   return (out_psar > 0.0);
  }

bool Strategy_HasOpenLong(ulong &ticket, double &open_price, datetime &open_time)
  {
   ticket = 0;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      ticket = candidate;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
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
   if(_Period != PERIOD_M5)
      return true;

   if(strategy_rsi_period <= 0 || strategy_stoch_k <= 0 || strategy_stoch_d <= 0 ||
      strategy_stoch_slowing <= 0 || strategy_bb_window <= 1 ||
      strategy_bb_deviation <= 0.0 || strategy_stoploss_pct <= 0.0 ||
      strategy_atr_period <= 0)
      return true;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(QM_RSI(_Symbol, tf, strategy_rsi_period, 1) <= 0.0)
      return true;
   if(QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1) < 0.0)
      return true;
   if(QM_BB_Lower(_Symbol, tf, strategy_bb_window, strategy_bb_deviation, 1, PRICE_TYPICAL) <= 0.0)
      return true;

   if(strategy_max_spread_atr_pct > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
         return true;
      if((ask - bid) > atr * strategy_max_spread_atr_pct / 100.0)
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

   ulong existing_ticket = 0;
   double existing_open = 0.0;
   datetime existing_time = 0;
   if(Strategy_HasOpenLong(existing_ticket, existing_open, existing_time))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double stoch_k = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, tf, strategy_bb_window, strategy_bb_deviation, 1, PRICE_TYPICAL);
   if(rsi <= 0.0 || stoch_k < 0.0 || bb_lower <= 0.0)
      return false;

   MqlRates bar;
   if(!Strategy_ReadClosedBar(1, bar))
      return false;

   if(!(rsi < strategy_rsi_entry))
      return false;
   if(!(stoch_k < strategy_stoch_slowk_entry))
      return false;
   if(!(bar.close < bb_lower))
      return false;
   if(!Strategy_IsHammer(bar))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = NormalizeDouble(entry * (1.0 - strategy_stoploss_pct / 100.0), _Digits);
   req.tp = NormalizeDouble(entry * (1.0 + strategy_roi_0_pct / 100.0), _Digits);
   req.reason = "ft002_bb_hammer_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // perf-allowed: hammer detection requires one closed OHLC bar; this runs only after the framework closed-bar gate.
   return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_HasOpenLong(ticket, open_price, open_time))
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(open_price <= 0.0 || bid <= 0.0)
      return;

   const int hold_minutes = (int)((TimeCurrent() - open_time) / 60);
   double min_roi = strategy_roi_0_pct;
   if(hold_minutes >= 60)
      min_roi = strategy_roi_60_pct;
   else if(hold_minutes >= 30)
      min_roi = strategy_roi_30_pct;
   else if(hold_minutes >= 20)
      min_roi = strategy_roi_20_pct;

   const double profit_pct = (bid - open_price) / open_price * 100.0;
   if(min_roi > 0.0 && profit_pct >= min_roi)
      QM_TM_ClosePosition(ticket, QM_EXIT_TP_HIT);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_HasOpenLong(ticket, open_price, open_time))
      return false;

   if(!QM_IsNewBar(_Symbol, (ENUM_TIMEFRAMES)_Period))
      return false;

   MqlRates bar;
   if(!Strategy_ReadClosedBar(1, bar))
      return false;

   double psar = 0.0;
   if(!Strategy_ReadPSAR(1, psar))
      return false;

   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   if(strategy_exit_profit_only)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= open_price)
         return false;
     }

   // perf-allowed: PSAR has no framework reader here; bounded CopyRates computes one closed-bar SAR value.
   return (psar > bar.close && Strategy_FisherFromRSI(rsi) > strategy_fisher_exit);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return !QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   if(qm_news_mode_legacy != QM_NEWS_OFF)
      return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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
