#property strict
#property version   "5.0"
#property description "QM5_11339 TC20 H1 EMA RSI candle pattern"

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
input int    qm_ea_id                   = 11339;
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
input int    strategy_fast_ema_period        = 5;
input int    strategy_slow_ema_period        = 21;
input int    strategy_rsi_period             = 21;
input double strategy_rsi_midline            = 50.0;
input int    strategy_cross_lookback_bars    = 2;
input bool   strategy_use_atr_stop           = true;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input int    strategy_swing_lookback_bars    = 10;
input int    strategy_spread_cap_pips        = 20;
input bool   strategy_allow_engulfing        = true;
input bool   strategy_allow_hammer           = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
      return true;

   return false;
  }

bool Strategy_ReadSignalBars(MqlRates &bar_signal, MqlRates &bar_prev)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 2, rates); // perf-allowed: two closed bars for card candle-pattern geometry inside framework new-bar entry gate.
   if(copied != 2)
      return false;
   bar_signal = rates[0];
   bar_prev = rates[1];
   return true;
  }

bool Strategy_BullishEngulfing(const MqlRates &bar_signal, const MqlRates &bar_prev)
  {
   const double range_signal = bar_signal.high - bar_signal.low;
   const double range_prev = bar_prev.high - bar_prev.low;
   if(range_signal <= 0.0 || range_prev <= 0.0)
      return false;

   return (bar_signal.open <= bar_prev.close &&
           bar_signal.close > bar_prev.open &&
           range_signal > range_prev);
  }

bool Strategy_BearishEngulfing(const MqlRates &bar_signal, const MqlRates &bar_prev)
  {
   const double range_signal = bar_signal.high - bar_signal.low;
   const double range_prev = bar_prev.high - bar_prev.low;
   if(range_signal <= 0.0 || range_prev <= 0.0)
      return false;

   return (bar_signal.open >= bar_prev.close &&
           bar_signal.close < bar_prev.open &&
           range_signal > range_prev);
  }

bool Strategy_BullishHammer(const MqlRates &bar_signal)
  {
   const double range = bar_signal.high - bar_signal.low;
   const double body = bar_signal.close - bar_signal.open;
   if(range <= 0.0 || body <= 0.0)
      return false;

   const double lower_wick = bar_signal.open - bar_signal.low;
   const double upper_wick = bar_signal.high - bar_signal.close;
   return (lower_wick >= 2.0 * body &&
           upper_wick <= range * 0.1);
  }

bool Strategy_BearishInvertedHammer(const MqlRates &bar_signal)
  {
   const double range = bar_signal.high - bar_signal.low;
   const double body = bar_signal.open - bar_signal.close;
   if(range <= 0.0 || body <= 0.0)
      return false;

   const double upper_wick = bar_signal.high - bar_signal.open;
   const double lower_wick = bar_signal.close - bar_signal.low;
   return (upper_wick >= 2.0 * body &&
           lower_wick <= range * 0.1);
  }

bool Strategy_HasRecentCross(const int direction)
  {
   const int lookback = MathMax(1, strategy_cross_lookback_bars);
   for(int shift = 1; shift <= lookback; ++shift)
     {
      if(QM_Sig_MA_Cross(_Symbol, (ENUM_TIMEFRAMES)_Period,
                         strategy_fast_ema_period,
                         strategy_slow_ema_period,
                         shift) == direction)
         return true;
     }
   return false;
  }

double Strategy_StopPrice(const QM_OrderType side, const double entry_price)
  {
   if(strategy_use_atr_stop)
      return QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);

   return QM_StopStructure(_Symbol, side, entry_price, strategy_swing_lookback_bars);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_rsi_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_swing_lookback_bars <= 0)
      return false;

   MqlRates bar_signal;
   MqlRates bar_prev;
   if(!Strategy_ReadSignalBars(bar_signal, bar_prev))
      return false;

   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi <= 0.0)
      return false;

   const bool bullish_pattern = (strategy_allow_engulfing && Strategy_BullishEngulfing(bar_signal, bar_prev)) ||
                                (strategy_allow_hammer && Strategy_BullishHammer(bar_signal));
   const bool bearish_pattern = (strategy_allow_engulfing && Strategy_BearishEngulfing(bar_signal, bar_prev)) ||
                                (strategy_allow_hammer && Strategy_BearishInvertedHammer(bar_signal));

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(Strategy_HasRecentCross(+1) && rsi > strategy_rsi_midline && bullish_pattern)
     {
      req.type = QM_BUY;
      req.sl = Strategy_StopPrice(req.type, ask);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.reason = "EMA5_21_RSI21_BULL_CANDLE";
      return true;
     }

   if(Strategy_HasRecentCross(-1) && rsi < strategy_rsi_midline && bearish_pattern)
     {
      req.type = QM_SELL;
      req.sl = Strategy_StopPrice(req.type, bid);
      if(req.sl <= 0.0 || req.sl <= bid)
         return false;
      req.reason = "EMA5_21_RSI21_BEAR_CANDLE";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial, or scale-in management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1, PRICE_CLOSE);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || rsi <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY &&
         (ema_fast < ema_slow || rsi < strategy_rsi_midline))
         return true;
      if(position_type == POSITION_TYPE_SELL &&
         (ema_fast > ema_slow || rsi > strategy_rsi_midline))
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
