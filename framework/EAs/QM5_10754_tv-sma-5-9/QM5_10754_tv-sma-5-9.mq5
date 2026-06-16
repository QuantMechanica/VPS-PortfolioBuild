#property strict
#property version   "5.0"
#property description "QM5_10754 TradingView SMA 5/9 Structure Stop"
// rework v2 2026-06-16 — fixed zero-trade strangle: optional ATR stop cap was
// mis-wired (mult<=0 rejected ALL trades) and 3x single-bar ATR cap rejected
// ~all 5-bar structure stops on a fast M15 cross (2024 smoke 0/1/5 trades vs
// ~120/yr). ATR cap now genuinely optional + widened to 6x spike-guard.

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
input int    qm_ea_id                   = 10754;
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
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_M15;
input int             strategy_fast_sma_period       = 5;
input int             strategy_slow_sma_period       = 9;
input int             strategy_structure_lookback    = 5;
input int             strategy_atr_period            = 14;
// rework v2 2026-06-16 — widened 3.0 -> 6.0. The card's ATR cap is a spike
// guard for OUTSIZED stops; a 5-bar structure stop on a fast M15 cross is
// routinely several single-bar ATRs wide, so a 3x cap rejected ~all entries
// (2024 smoke: 0/1/5 trades). 6x still rejects genuine spikes. Set 0 to disable.
input double          strategy_max_stop_atr_mult     = 6.0;
input double          strategy_take_profit_rr        = 2.0;
input bool            strategy_use_sma200_filter     = false;
input int             strategy_context_sma_period    = 200;
input int             strategy_max_spread_points     = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type)
  {
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

int Strategy_SmaCrossSignal()
  {
   if(strategy_fast_sma_period <= 0 ||
      strategy_slow_sma_period <= strategy_fast_sma_period)
      return 0;

   const double fast_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 2, PRICE_CLOSE);
   const double slow_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 2, PRICE_CLOSE);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return 0;

   if(fast_2 <= slow_2 && fast_1 > slow_1)
      return 1;
   if(fast_2 >= slow_2 && fast_1 < slow_1)
      return -1;
   return 0;
  }

bool Strategy_Sma200FilterPasses(const QM_OrderType side)
  {
   if(!strategy_use_sma200_filter)
      return true;
   if(strategy_context_sma_period <= 0)
      return false;

   const double close_1 = QM_SMA(_Symbol, strategy_timeframe, 1, 1, PRICE_CLOSE);
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_context_sma_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || sma_200 <= 0.0)
      return false;

   if(side == QM_BUY)
      return (close_1 > sma_200);
   return (close_1 < sma_200);
  }

bool Strategy_StopDistancePasses(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || entry == sl)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   const double stop_points = stop_distance / point;
   const long broker_min_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(broker_min_points > 0 && stop_points < (double)broker_min_points)
      return false;

   // rework v2 2026-06-16 — the ATR cap is the card's *optional* spike guard
   // ("Optional ATR stop cap to avoid outsized stop during spikes"), not a hard
   // primary filter. The original wiring rejected EVERY trade when the cap was
   // disabled (mult<=0 -> return false) AND, while enabled, compared a 5-bar
   // structure-stop distance against a single-bar ATR cap — dimensionally
   // guaranteed to over-reject a fast M15 5/9 cross. Evidence: 2024 smoke gave
   // 0/1/5 trades (EURUSD/USDJPY/GDAXI) vs ~120/yr expected. Fix: mult<=0 now
   // means "no cap" (filter genuinely optional); keep the cap only as a true
   // outlier spike guard.
   if(strategy_max_stop_atr_mult <= 0.0 || strategy_atr_period <= 0)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   return (stop_distance <= strategy_max_stop_atr_mult * atr);
  }

// No Trade Filter (time, spread, news): the framework handles news and Friday
// close; this hook enforces M15 execution and an optional spread ceiling.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: closed-bar SMA(5/9) cross, previous-5-candle structure stop,
// rejection of too-small or >3*ATR(14) stops, and a fixed 2R target.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_timeframe)
      return false;
   if(strategy_structure_lookback <= 0 || strategy_take_profit_rr <= 0.0)
      return false;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type))
      return false;

   const int signal = Strategy_SmaCrossSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   if(!Strategy_Sma200FilterPasses(side))
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = QM_StopStructure(_Symbol, side, entry, strategy_structure_lookback);
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;
   if(!Strategy_StopDistancePasses(entry, sl))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "TV_SMA59_LONG" : "TV_SMA59_SHORT";
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or add-on logic.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: opposite SMA(5/9) cross closes any open position before broker
// SL/TP if the reversal arrives first.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_GetOurPosition(position_type))
      return false;

   const int signal = Strategy_SmaCrossSignal();
   if(position_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && signal > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; central framework news mode applies.
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
