#property strict
#property version   "5.0"
#property description "QM5_10615 MQL5 Daily Pivot Touch Stop"

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
input int    qm_ea_id                   = 10615;
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
input int    strategy_target_level          = 3;     // 1=S/R1, 2=S/R2, 3=S/R3.
input int    strategy_atr_period            = 14;    // Catastrophic fallback when pivot levels are unusable.
input double strategy_atr_sl_mult           = 2.0;   // Card fallback stop = 2.0 * ATR(14).
input bool   strategy_intraday_close_enabled = false; // Source isTradeDay behaviour: close at 23:00 broker time.
input bool   strategy_breakeven_enabled     = false; // Source ModSL behaviour at first support/resistance.

struct StrategyPivotLevels
  {
   double pivot;
   double r1;
   double r2;
   double r3;
   double s1;
   double s2;
   double s3;
  };

StrategyPivotLevels g_pivot_levels;
bool                g_pivot_levels_valid = false;

bool ReadPivotLevels(StrategyPivotLevels &levels)
  {
   MqlRates daily[1];
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, daily) != 1) // perf-allowed: one previous D1 bar for pivot structure, called only after QM_IsNewBar() gate.
      return false;

   const double high = daily[0].high;
   const double low = daily[0].low;
   const double close = daily[0].close;
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
      return false;

   levels.pivot = NormalizeDouble((high + low + close) / 3.0, _Digits);
   levels.r1 = NormalizeDouble(2.0 * levels.pivot - low, _Digits);
   levels.s1 = NormalizeDouble(2.0 * levels.pivot - high, _Digits);
   levels.r2 = NormalizeDouble(levels.pivot + (levels.r1 - levels.s1), _Digits);
   levels.s2 = NormalizeDouble(levels.pivot - (levels.r1 - levels.s1), _Digits);
   levels.r3 = NormalizeDouble(high + 2.0 * (levels.pivot - low), _Digits);
   levels.s3 = NormalizeDouble(low - 2.0 * (high - levels.pivot), _Digits);
   return true;
  }

bool ReadClosedCloses(double &close1, double &close2)
  {
   double closes[2];
   if(CopyClose(_Symbol, _Period, 1, 2, closes) != 2) // perf-allowed: two closed-bar closes for source pivot-cross rule, called only after QM_IsNewBar() gate.
      return false;
   close1 = closes[0];
   close2 = closes[1];
   return (close1 > 0.0 && close2 > 0.0);
  }

int TargetLevel()
  {
   if(strategy_target_level < 1)
      return 1;
   if(strategy_target_level > 3)
      return 3;
   return strategy_target_level;
  }

void PrimaryStops(const bool is_buy, const StrategyPivotLevels &levels, double &sl, double &tp)
  {
   const int level = TargetLevel();
   if(is_buy)
     {
      sl = (level == 1) ? levels.s1 : ((level == 2) ? levels.s2 : levels.s3);
      tp = (level == 1) ? levels.r1 : ((level == 2) ? levels.r2 : levels.r3);
     }
   else
     {
      const double spread_offset = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      sl = ((level == 1) ? levels.r1 : ((level == 2) ? levels.r2 : levels.r3)) + spread_offset;
      tp = ((level == 1) ? levels.s1 : ((level == 2) ? levels.s2 : levels.s3)) + spread_offset;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
  }

void SecondaryStops(const bool is_buy, const StrategyPivotLevels &levels, double &sl, double &tp)
  {
   if(is_buy)
     {
      sl = levels.s2;
      tp = levels.r3;
     }
   else
     {
      const double spread_offset = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      sl = levels.r2 + spread_offset;
      tp = levels.s3 + spread_offset;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
  }

bool StopsAreUsable(const bool is_buy, const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   const double min_dist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * point;
   if(is_buy)
      return (sl < entry - min_dist && tp > entry + min_dist);
   return (sl > entry + min_dist && tp < entry - min_dist);
  }

bool FallbackATRStops(const bool is_buy, const double entry, double &sl, double &tp)
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double dist = atr * strategy_atr_sl_mult;
   sl = NormalizeDouble(is_buy ? entry - dist : entry + dist, _Digits);
   tp = NormalizeDouble(is_buy ? entry + dist : entry - dist, _Digits);
   return StopsAreUsable(is_buy, entry, sl, tp);
  }

bool SelectStops(const bool is_buy, const double entry, const StrategyPivotLevels &levels, double &sl, double &tp)
  {
   PrimaryStops(is_buy, levels, sl, tp);
   if(StopsAreUsable(is_buy, entry, sl, tp))
      return true;

   SecondaryStops(is_buy, levels, sl, tp);
   if(StopsAreUsable(is_buy, entry, sl, tp))
      return true;

   return FallbackATRStops(is_buy, entry, sl, tp);
  }

bool HasCurrentPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
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
   return (PeriodSeconds(_Period) >= PeriodSeconds(PERIOD_D1));
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

   StrategyPivotLevels levels;
   double close1 = 0.0;
   double close2 = 0.0;
   if(!ReadPivotLevels(levels) || !ReadClosedCloses(close1, close2))
      return false;

   g_pivot_levels = levels;
   g_pivot_levels_valid = true;

   if(HasCurrentPosition())
      return false;

   const bool buy_signal = (close1 > levels.pivot && close2 <= levels.pivot);
   const bool sell_signal = (close1 < levels.pivot && close2 >= levels.pivot);
   if(buy_signal == sell_signal)
      return false;

   const bool is_buy = buy_signal;
   const double entry = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!SelectStops(is_buy, entry, levels, sl, tp))
      return false;

   req.type = is_buy ? QM_BUY : QM_SELL;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = sl;
   req.tp = tp;
   req.reason = is_buy ? "PIVOT_CROSS_UP" : "PIVOT_CROSS_DOWN";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled)
      return;

   if(!g_pivot_levels_valid)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread_offset = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double target_sl = NormalizeDouble(open_price + spread_offset, _Digits);
         if(bid >= g_pivot_levels.r1 && (current_sl <= 0.0 || current_sl < target_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "pivot_first_resistance_breakeven");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double target_sl = NormalizeDouble(open_price - spread_offset, _Digits);
         if(ask <= g_pivot_levels.s1 && (current_sl <= 0.0 || current_sl > target_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "pivot_first_support_breakeven");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_intraday_close_enabled)
      return false;

   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   return (broker_dt.hour == 23);
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
