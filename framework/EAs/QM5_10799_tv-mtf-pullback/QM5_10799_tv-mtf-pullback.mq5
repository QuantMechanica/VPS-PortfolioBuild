#property strict
#property version   "5.0"
#property description "QM5_10799 TradingView MTF Pullback RSI Divergence"

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
input int    qm_ea_id                   = 10799;
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
input ENUM_TIMEFRAMES strategy_trend_tf       = PERIOD_H4;
input int             strategy_ema_period     = 50;
input int             strategy_rsi_period     = 14;
input double          strategy_rsi_oversold   = 30.0;
input double          strategy_rsi_pullback   = 40.0;
input double          strategy_rsi_overbought = 70.0;
input double          strategy_rsi_rally      = 60.0;
input int             strategy_atr_period     = 14;
input double          strategy_atr_sl_mult    = 2.0;
input double          strategy_take_profit_pct = 2.0;
input int             strategy_swing_lookback = 12;
input int             strategy_div_lookback   = 8;

double BarOpen(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iOpen(sym, tf, shift); // perf-allowed: bounded candle-pattern read on framework closed-bar entry path.
  }

double BarHigh(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iHigh(sym, tf, shift); // perf-allowed: bounded swing/pullback read on framework closed-bar entry path.
  }

double BarLow(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iLow(sym, tf, shift); // perf-allowed: bounded swing/pullback read on framework closed-bar entry path.
  }

double BarClose(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(sym, tf, shift); // perf-allowed: bounded candle-pattern read on framework closed-bar entry path.
  }

double HighestHigh(const string sym, const ENUM_TIMEFRAMES tf, const int lookback, const int start_shift)
  {
   double high = -DBL_MAX;
   for(int i = start_shift; i < start_shift + lookback; ++i)
      high = MathMax(high, BarHigh(sym, tf, i));
   return high;
  }

double LowestLow(const string sym, const ENUM_TIMEFRAMES tf, const int lookback, const int start_shift)
  {
   double low = DBL_MAX;
   for(int i = start_shift; i < start_shift + lookback; ++i)
      low = MathMin(low, BarLow(sym, tf, i));
   return low;
  }

bool BullishEngulfing(const int shift)
  {
   const double o1 = BarOpen(_Symbol, _Period, shift);
   const double c1 = BarClose(_Symbol, _Period, shift);
   const double o2 = BarOpen(_Symbol, _Period, shift + 1);
   const double c2 = BarClose(_Symbol, _Period, shift + 1);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 < o2 && c1 > o1 && c1 >= o2 && o1 <= c2);
  }

bool BearishEngulfing(const int shift)
  {
   const double o1 = BarOpen(_Symbol, _Period, shift);
   const double c1 = BarClose(_Symbol, _Period, shift);
   const double o2 = BarOpen(_Symbol, _Period, shift + 1);
   const double c2 = BarClose(_Symbol, _Period, shift + 1);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 > o2 && c1 < o1 && c1 <= o2 && o1 >= c2);
  }

bool RsiTurnsUp()
  {
   const double r1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double r2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double r3 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 3);
   return ((r2 < strategy_rsi_oversold || r2 < strategy_rsi_pullback) && r1 > r2 && r2 <= r3);
  }

bool RsiTurnsDown()
  {
   const double r1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double r2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double r3 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 3);
   return ((r2 > strategy_rsi_overbought || r2 > strategy_rsi_rally) && r1 < r2 && r2 >= r3);
  }

bool BullishRsiDivergence()
  {
   int recent = 1;
   int prior = 3;
   double recent_low = DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 1; i <= MathMax(3, strategy_div_lookback / 2); ++i)
     {
      const double low = BarLow(_Symbol, _Period, i);
      if(low < recent_low)
        {
         recent_low = low;
         recent = i;
        }
     }
   for(int i = MathMax(3, strategy_div_lookback / 2) + 1; i <= strategy_div_lookback; ++i)
     {
      const double low = BarLow(_Symbol, _Period, i);
      if(low < prior_low)
        {
         prior_low = low;
         prior = i;
        }
     }
   const double r_recent = QM_RSI(_Symbol, _Period, strategy_rsi_period, recent);
   const double r_prior = QM_RSI(_Symbol, _Period, strategy_rsi_period, prior);
   return (recent_low < prior_low && r_recent > r_prior);
  }

bool BearishRsiDivergence()
  {
   int recent = 1;
   int prior = 3;
   double recent_high = -DBL_MAX;
   double prior_high = -DBL_MAX;
   for(int i = 1; i <= MathMax(3, strategy_div_lookback / 2); ++i)
     {
      const double high = BarHigh(_Symbol, _Period, i);
      if(high > recent_high)
        {
         recent_high = high;
         recent = i;
        }
     }
   for(int i = MathMax(3, strategy_div_lookback / 2) + 1; i <= strategy_div_lookback; ++i)
     {
      const double high = BarHigh(_Symbol, _Period, i);
      if(high > prior_high)
        {
         prior_high = high;
         prior = i;
        }
     }
   const double r_recent = QM_RSI(_Symbol, _Period, strategy_rsi_period, recent);
   const double r_prior = QM_RSI(_Symbol, _Period, strategy_rsi_period, prior);
   return (recent_high > prior_high && r_recent < r_prior);
  }

bool RecentBullishEngulfing()
  {
   return BullishEngulfing(1) || BullishEngulfing(2) || BullishEngulfing(3);
  }

bool RecentBearishEngulfing()
  {
   return BearishEngulfing(1) || BearishEngulfing(2) || BearishEngulfing(3);
  }

bool HasOurPosition(ENUM_POSITION_TYPE &type_out)
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
      type_out = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

double NormalizeSymbolPrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_ema_period < 2 || strategy_rsi_period < 2 ||
      strategy_atr_period < 1 || strategy_swing_lookback < 3 ||
      strategy_div_lookback < 4 || strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_pct <= 0.0)
      return false;

   ENUM_POSITION_TYPE existing_type;
   if(HasOurPosition(existing_type))
      return false;

   const double htf_close = BarClose(_Symbol, strategy_trend_tf, 1);
   const double htf_ema = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_period, 1);
   const double htf_ema_prev = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_period, 2);
   const double htf_swing_high = HighestHigh(_Symbol, strategy_trend_tf, strategy_swing_lookback, 1);
   const double htf_swing_low = LowestLow(_Symbol, strategy_trend_tf, strategy_swing_lookback, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(htf_close <= 0.0 || htf_ema <= 0.0 || htf_ema_prev <= 0.0 ||
      htf_swing_high <= 0.0 || htf_swing_low <= 0.0 || atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double tp_mult = strategy_take_profit_pct / 100.0;

   const bool htf_up = (htf_close > htf_ema && htf_ema > htf_ema_prev && ask > htf_ema);
   const bool htf_down = (htf_close < htf_ema && htf_ema < htf_ema_prev && bid < htf_ema);
   const bool pullback_from_high = (htf_close < htf_swing_high && htf_close > htf_ema);
   const bool pullback_from_low = (htf_close > htf_swing_low && htf_close < htf_ema);
   const bool long_rsi = (BullishRsiDivergence() || RsiTurnsUp());
   const bool short_rsi = (BearishRsiDivergence() || RsiTurnsDown());

   if(htf_up && pullback_from_high && long_rsi && RecentBullishEngulfing())
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeSymbolPrice(ask - stop_dist);
      req.tp = NormalizeSymbolPrice(ask * (1.0 + tp_mult));
      req.reason = "TV_MTF_PULLBACK_LONG";
      return (req.sl > 0.0 && req.tp > ask);
     }

   if(htf_down && pullback_from_low && short_rsi && RecentBearishEngulfing())
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeSymbolPrice(bid + stop_dist);
      req.tp = NormalizeSymbolPrice(bid * (1.0 - tp_mult));
      req.reason = "TV_MTF_PULLBACK_SHORT";
      return (req.sl > bid && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop and fixed target only; no BE/trailing/partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!HasOurPosition(ptype))
      return false;

   if(ptype == POSITION_TYPE_BUY && BearishEngulfing(1) && RsiTurnsDown())
      return true;
   if(ptype == POSITION_TYPE_SELL && BullishEngulfing(1) && RsiTurnsUp())
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
