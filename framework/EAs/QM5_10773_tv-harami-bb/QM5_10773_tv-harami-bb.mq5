#property strict
#property version   "5.0"
#property description "QM5_10773 TradingView Harami Bollinger Band Reversal"

#include <QM/QM_Common.mqh>

enum Strategy_HaramiStrictness
  {
   STRATEGY_HARAMI_BODY_INSIDE = 0,
   STRATEGY_HARAMI_FULL_RANGE_INSIDE = 1
  };

enum Strategy_StopMode
  {
   STRATEGY_STOP_SOURCE_POINTS = 0,
   STRATEGY_STOP_ATR = 1
  };

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
input int    qm_ea_id                   = 10773;
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
input ENUM_TIMEFRAMES         strategy_signal_timeframe  = PERIOD_CURRENT;
input int                     strategy_bb_period         = 20;
input double                  strategy_bb_deviation      = 2.0;
input Strategy_HaramiStrictness strategy_pattern_strictness = STRATEGY_HARAMI_BODY_INSIDE;
input Strategy_StopMode       strategy_stop_mode         = STRATEGY_STOP_ATR;
input int                     strategy_source_sl_points  = 20;
input int                     strategy_source_tp_points  = 40;
input int                     strategy_atr_period        = 14;
input double                  strategy_atr_sl_mult       = 1.0;
input double                  strategy_take_profit_rr    = 2.0;
input bool                    strategy_use_ema200_filter = false;
input int                     strategy_ema_period        = 200;
input int                     strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   if(strategy_signal_timeframe == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return strategy_signal_timeframe;
  }

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

bool Strategy_ReadCandle(const ENUM_TIMEFRAMES tf,
                         const int shift,
                         double &open_price,
                         double &high_price,
                         double &low_price,
                         double &close_price)
  {
   MqlRates rates[1];
   if(CopyRates(_Symbol, tf, shift, 1, rates) != 1) // perf-allowed: Harami geometry reads one closed candle per closed-bar entry pass.
      return false;

   open_price = rates[0].open;
   high_price = rates[0].high;
   low_price = rates[0].low;
   close_price = rates[0].close;
   return (open_price > 0.0 && high_price > 0.0 && low_price > 0.0 && close_price > 0.0);
  }

double Strategy_BodyHigh(const double open_price, const double close_price)
  {
   return MathMax(open_price, close_price);
  }

double Strategy_BodyLow(const double open_price, const double close_price)
  {
   return MathMin(open_price, close_price);
  }

bool Strategy_SecondCandleInsideFirst(const double o1,
                                      const double h1,
                                      const double l1,
                                      const double c1,
                                      const double o2,
                                      const double h2,
                                      const double l2,
                                      const double c2)
  {
   const bool body_inside =
      (Strategy_BodyLow(o1, c1) >= Strategy_BodyLow(o2, c2) &&
       Strategy_BodyHigh(o1, c1) <= Strategy_BodyHigh(o2, c2));
   if(!body_inside)
      return false;

   if(strategy_pattern_strictness == STRATEGY_HARAMI_FULL_RANGE_INSIDE)
      return (l1 >= l2 && h1 <= h2);
   return true;
  }

int Strategy_HaramiSignal()
  {
   if(strategy_bb_period <= 0 || strategy_bb_deviation <= 0.0)
      return 0;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   double o1 = 0.0, h1 = 0.0, l1 = 0.0, c1 = 0.0;
   double o2 = 0.0, h2 = 0.0, l2 = 0.0, c2 = 0.0;
   if(!Strategy_ReadCandle(tf, 1, o1, h1, l1, c1))
      return 0;
   if(!Strategy_ReadCandle(tf, 2, o2, h2, l2, c2))
      return 0;

   if(!Strategy_SecondCandleInsideFirst(o1, h1, l1, c1, o2, h2, l2, c2))
      return 0;

   const double lower_2 = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   const double upper_2 = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   if(lower_2 <= 0.0 || upper_2 <= 0.0)
      return 0;

   const bool first_bearish = (c2 < o2);
   const bool second_bullish = (c1 > o1);
   const bool first_bullish = (c2 > o2);
   const bool second_bearish = (c1 < o1);

   if(first_bearish && second_bullish && l2 <= lower_2)
      return 1;
   if(first_bullish && second_bearish && h2 >= upper_2)
      return -1;
   return 0;
  }

bool Strategy_EmaFilterPasses(const QM_OrderType side)
  {
   if(!strategy_use_ema200_filter)
      return true;
   if(strategy_ema_period <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   double o1 = 0.0, h1 = 0.0, l1 = 0.0, c1 = 0.0;
   if(!Strategy_ReadCandle(tf, 1, o1, h1, l1, c1))
      return false;

   const double ema = QM_EMA(_Symbol, tf, strategy_ema_period, 1, PRICE_CLOSE);
   if(ema <= 0.0)
      return false;

   if(side == QM_BUY)
      return (c1 > ema);
   return (c1 < ema);
  }

bool Strategy_StopDistancePasses(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0 || entry == sl)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double stop_points = MathAbs(entry - sl) / point;
   const long broker_min_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(broker_min_points > 0 && stop_points < (double)broker_min_points)
      return false;

   return true;
  }

bool Strategy_BuildBracket(const QM_OrderType side,
                           const double entry,
                           double &sl,
                           double &tp)
  {
   sl = 0.0;
   tp = 0.0;
   if(entry <= 0.0)
      return false;

   if(strategy_stop_mode == STRATEGY_STOP_SOURCE_POINTS)
     {
      if(strategy_source_sl_points <= 0 || strategy_source_tp_points <= 0)
         return false;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;

      if(side == QM_BUY)
        {
         sl = entry - (double)strategy_source_sl_points * point;
         tp = entry + (double)strategy_source_tp_points * point;
        }
      else
        {
         sl = entry + (double)strategy_source_sl_points * point;
         tp = entry - (double)strategy_source_tp_points * point;
        }
     }
   else
     {
      if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_take_profit_rr <= 0.0)
         return false;
      sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
     }

   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(side == QM_BUY && (sl >= entry || tp <= entry))
      return false;
   if(side == QM_SELL && (sl <= entry || tp >= entry))
      return false;

   return Strategy_StopDistancePasses(entry, sl);
  }

// No Trade Filter (time, spread, news): the framework handles news and Friday
// close; this hook enforces any explicit signal-timeframe and spread ceiling.
bool Strategy_NoTradeFilter()
  {
   if(strategy_signal_timeframe != PERIOD_CURRENT && _Period != strategy_signal_timeframe)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: confirmed two-bar Harami reversal where the first candle touches
// the outer Bollinger Band; bracket is source points or ATR-normalized 2R.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type))
      return false;

   const int signal = Strategy_HaramiSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   if(!Strategy_EmaFilterPasses(side))
      return false;

   const double entry = QM_EntryMarketPrice(side);
   double sl = 0.0;
   double tp = 0.0;
   if(!Strategy_BuildBracket(side, entry, sl, tp))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "TV_HARAMI_BB_LONG" : "TV_HARAMI_BB_SHORT";
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or add-on logic; broker SL/TP manages the bracket.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: no discretionary close in the card; exits are bracket SL/TP and
// framework-level Friday/kill-switch closures.
bool Strategy_ExitSignal()
  {
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
