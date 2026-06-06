#property strict
#property version   "5.0"
#property description "QM5_10849 TradingView Sovereign SMEMA Trend"

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
input int    qm_ea_id                   = 10849;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_CURRENT;
input int             strategy_fast_smema      = 2;
input int             strategy_slow_smema      = 5;
input int             strategy_baseline_smema  = 15;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 1.8;
input double          strategy_tp1_atr_mult    = 2.5;
input double          strategy_tp2_atr_mult    = 4.5;
input double          strategy_trail_atr_mult  = 1.5;
input int             strategy_max_bars        = 10;
input double          strategy_max_spread_stop = 0.15;
input bool            strategy_filter_adx      = false;
input double          strategy_adx_min         = 18.0;
input bool            strategy_filter_rsi      = false;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_long_min    = 52.0;
input double          strategy_rsi_short_max   = 48.0;
input bool            strategy_filter_atr_ratio = false;
input int             strategy_atr_ratio_sma   = 20;
input double          strategy_atr_ratio_min   = 0.8;
input bool            strategy_filter_baseline = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Closed-bar cache of the raw SMEMA crossover, refreshed once per new bar inside
// Strategy_EntrySignal (which the framework gates with QM_IsNewBar). The per-tick
// Strategy_ExitSignal reads this instead of recomputing the SMEMA stack on every
// tick — the EMA values only change on closed bars, so per-tick recompute would
// be ~14 redundant CopyBuffer reads per tick. +1 = bull cross, -1 = bear cross,
// 0 = no cross on the last closed bar.
int g_smema_signal = 0;

ENUM_TIMEFRAMES StrategyTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf);
  }

double SmemaValue(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double ema = QM_EMA(_Symbol, StrategyTF(), period, shift + i, PRICE_CLOSE);
      if(ema <= 0.0)
         return 0.0;
      sum += ema;
     }
   return sum / period;
  }

double CloseProxy(const int shift)
  {
   return QM_EMA(_Symbol, StrategyTF(), 1, shift, PRICE_CLOSE);
  }

double AtrSma(const int period, const int samples)
  {
   if(period <= 0 || samples <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 1; i <= samples; ++i)
     {
      const double atr = QM_ATR(_Symbol, StrategyTF(), period, i);
      if(atr <= 0.0)
         return 0.0;
      sum += atr;
     }
   return sum / samples;
  }

int PriceDistanceToPips(const double distance)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(distance <= 0.0 || point <= 0.0)
      return 0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double pip_distance = point * pip_factor;
   if(pip_distance <= 0.0)
      return 0;

   return (int)MathMax(1.0, MathRound(distance / pip_distance));
  }

bool PassesOptionalFilters(const int direction)
  {
   const ENUM_TIMEFRAMES tf = StrategyTF();

   if(strategy_filter_adx)
     {
      const double adx = QM_ADX(_Symbol, tf, 14, 1);
      if(adx < strategy_adx_min)
         return false;
     }

   if(strategy_filter_rsi)
     {
      const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
      if(direction > 0 && rsi < strategy_rsi_long_min)
         return false;
      if(direction < 0 && rsi > strategy_rsi_short_max)
         return false;
     }

   if(strategy_filter_atr_ratio)
     {
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      const double atr_sma = AtrSma(strategy_atr_period, strategy_atr_ratio_sma);
      if(atr <= 0.0 || atr_sma <= 0.0 || atr / atr_sma < strategy_atr_ratio_min)
         return false;
     }

   if(strategy_filter_baseline)
     {
      const double close_1 = CloseProxy(1);
      const double baseline = SmemaValue(strategy_baseline_smema, 1);
      if(close_1 <= 0.0 || baseline <= 0.0)
         return false;
      if(direction > 0 && close_1 <= baseline)
         return false;
      if(direction < 0 && close_1 >= baseline)
         return false;
     }

   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, StrategyTF(), strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || atr <= 0.0)
      return true;

   const double stop_points = (atr * strategy_atr_sl_mult) / point;
   const double spread_points = (ask - bid) / point;
   if(stop_points <= 0.0)
      return true;

   if(spread_points > stop_points * strategy_max_spread_stop)
      return true;

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

   const ENUM_TIMEFRAMES tf = StrategyTF();
   const double fast_1 = SmemaValue(strategy_fast_smema, 1);
   const double fast_2 = SmemaValue(strategy_fast_smema, 2);
   const double slow_1 = SmemaValue(strategy_slow_smema, 1);
   const double slow_2 = SmemaValue(strategy_slow_smema, 2);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0 || atr <= 0.0)
      return false;

   int direction = 0;
   if(fast_2 <= slow_2 && fast_1 > slow_1)
      direction = 1;
   else if(fast_2 >= slow_2 && fast_1 < slow_1)
      direction = -1;

   // Cache the raw crossover for the per-tick exit BEFORE optional filters:
   // the card's "close on opposite SMEMA crossover" exit is unfiltered.
   g_smema_signal = direction;

   if(direction == 0)
      return false;

   if(!PassesOptionalFilters(direction))
      return false;

   const QM_OrderType side = (direction > 0 ? QM_BUY : QM_SELL);
   const double entry = (direction > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_tp2_atr_mult);
   req.reason = (direction > 0 ? "SMEMA_BULL_CROSS" : "SMEMA_BEAR_CROSS");
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, StrategyTF(), strategy_atr_period, 1);
   const int tp1_pips = PriceDistanceToPips(atr * strategy_tp1_atr_mult);
   if(magic <= 0 || tp1_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double market = (type == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                       : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double moved = (type == POSITION_TYPE_BUY ? market - open_price : open_price - market);
      if(moved < atr * strategy_tp1_atr_mult)
         continue;

      QM_TM_MoveToBreakEven(ticket, tp1_pips, 0);
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // Read the closed-bar crossover cached by Strategy_EntrySignal on the last
   // new bar — no per-tick SMEMA recompute (the values only change per bar).
   const bool bullish_cross = (g_smema_signal > 0);
   const bool bearish_cross = (g_smema_signal < 0);
   const int period_seconds = PeriodSeconds(StrategyTF());
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && bearish_cross)
         return true;
      if(type == POSITION_TYPE_SELL && bullish_cross)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(period_seconds > 0 && strategy_max_bars > 0 && opened > 0 &&
         (now - opened) >= period_seconds * strategy_max_bars)
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
