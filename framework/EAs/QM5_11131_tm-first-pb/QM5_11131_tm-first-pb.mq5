#property strict
#property version   "5.0"
#property description "QM5_11131 TradingMarkets First Pullback index limit"

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
input int    qm_ea_id                   = 11131;
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
input int    strategy_sma_exit_period            = 5;
input int    strategy_sma_pullback_period        = 5;
input int    strategy_sma_trend_fast             = 20;
input int    strategy_sma_trend_mid              = 50;
input int    strategy_sma_trend_slow             = 100;
input int    strategy_sma_trend_long             = 200;
input int    strategy_atr_period                 = 14;
input double strategy_us_limit_depth_pct         = 4.0;
input double strategy_non_us_limit_atr_mult      = 1.0;
input int    strategy_limit_valid_bars           = 3;
input double strategy_stop_atr_mult              = 2.5;
input int    strategy_max_hold_bars              = 7;
input int    strategy_exit_mode                  = 0;     // 0=SMA5, 1=ConnorsRSI>50, 2=ConnorsRSI>70
input int    strategy_connors_rsi_period         = 3;
input int    strategy_connors_streak_rsi_period  = 2;
input int    strategy_connors_rank_period        = 100;
input double strategy_max_spread_atr_frac        = 0.25;

bool Strategy_ReadClosedRates(const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   return (CopyRates(_Symbol, PERIOD_D1, 1, count, rates) == count); // perf-allowed
  }

bool Strategy_LastClosedClose(double &close_out)
  {
   MqlRates rates[];
   if(!Strategy_ReadClosedRates(1, rates))
      return false;
   close_out = rates[0].close;
   return (close_out > 0.0);
  }

bool Strategy_IsNonUsIndex()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "GER40") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0);
  }

bool Strategy_SpreadOk()
  {
   if(strategy_max_spread_atr_frac <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(atr <= 0.0 || point <= 0.0 || spread_points < 0)
      return false;

   return ((double)spread_points * point <= atr * strategy_max_spread_atr_frac);
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT)
         return true;
     }
   return false;
  }

bool Strategy_GetOurPositionOpenTime(datetime &open_time)
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

      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

double Strategy_StreakAt(const MqlRates &rates[], const int idx)
  {
   const int total = ArraySize(rates);
   if(idx + 1 >= total)
      return 0.0;

   const double first_diff = rates[idx].close - rates[idx + 1].close;
   if(first_diff == 0.0)
      return 0.0;

   const int direction = (first_diff > 0.0) ? 1 : -1;
   int streak = direction;
   for(int i = idx + 1; i + 1 < total; ++i)
     {
      const double diff = rates[i].close - rates[i + 1].close;
      if((direction > 0 && diff > 0.0) || (direction < 0 && diff < 0.0))
         streak += direction;
      else
         break;
     }
   return (double)streak;
  }

double Strategy_RSIFromSeries(const double &values[], const int period)
  {
   if(period < 1 || ArraySize(values) < period + 1)
      return 0.0;

   double gains = 0.0;
   double losses = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double change = values[i] - values[i + 1];
      if(change > 0.0)
         gains += change;
      else
         losses -= change;
     }

   if(losses <= 0.0)
      return 100.0;
   const double rs = gains / losses;
   return 100.0 - (100.0 / (1.0 + rs));
  }

double Strategy_ConnorsRSI()
  {
   const int need = MathMax(strategy_connors_rank_period + 2,
                            strategy_connors_streak_rsi_period + 8);
   MqlRates rates[];
   if(!Strategy_ReadClosedRates(need, rates))
      return 0.0;

   const double price_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_connors_rsi_period, 1);
   if(price_rsi <= 0.0)
      return 0.0;

   double streak_values[];
   ArrayResize(streak_values, strategy_connors_streak_rsi_period + 1);
   for(int i = 0; i <= strategy_connors_streak_rsi_period; ++i)
      streak_values[i] = Strategy_StreakAt(rates, i);
   const double streak_rsi = Strategy_RSIFromSeries(streak_values, strategy_connors_streak_rsi_period);

   const double today_return = (rates[0].close - rates[1].close) / rates[1].close;
   int lower_count = 0;
   for(int i = 1; i <= strategy_connors_rank_period; ++i)
     {
      const double prior_return = (rates[i].close - rates[i + 1].close) / rates[i + 1].close;
      if(today_return > prior_return)
         lower_count++;
     }
   const double percent_rank = 100.0 * (double)lower_count / (double)strategy_connors_rank_period;
   return (price_rsi + streak_rsi + percent_rank) / 3.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card spread filter is entry-only; exits and position management must keep running.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "TM_FIRST_PULLBACK_BUY_LIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_pullback_period < 1 ||
      strategy_sma_trend_fast < 1 ||
      strategy_sma_trend_mid < 1 ||
      strategy_sma_trend_slow < 1 ||
      strategy_sma_trend_long < 1 ||
      strategy_atr_period < 1 ||
      strategy_limit_valid_bars < 1 ||
      strategy_stop_atr_mult <= 0.0)
      return false;

   if(!Strategy_SpreadOk())
      return false;
   if(Strategy_HasOurPendingOrder())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double close1 = 0.0;
   if(!Strategy_LastClosedClose(close1))
      return false;

   const double sma5 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_pullback_period, 1);
   const double sma20 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_trend_fast, 1);
   const double sma50 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_trend_mid, 1);
   const double sma100 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_trend_slow, 1);
   const double sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_trend_long, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma5 <= 0.0 || sma20 <= 0.0 || sma50 <= 0.0 || sma100 <= 0.0 || sma200 <= 0.0 || atr <= 0.0)
      return false;

   if(!(close1 > sma200 && close1 > sma100 && close1 > sma50 && close1 > sma20 && close1 < sma5))
      return false;

   const double limit_distance = Strategy_IsNonUsIndex()
                                 ? atr * strategy_non_us_limit_atr_mult
                                 : close1 * (strategy_us_limit_depth_pct / 100.0);
   if(limit_distance <= 0.0)
      return false;

   req.price = close1 - limit_distance;
   req.sl = req.price - (atr * strategy_stop_atr_mult);
   req.tp = 0.0;
   req.expiration_seconds = strategy_limit_valid_bars * PeriodSeconds(PERIOD_D1);
   return (req.price > 0.0 && req.sl > 0.0 && req.price > req.sl);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_GetOurPositionOpenTime(open_time))
      return false;

   if(strategy_max_hold_bars > 0)
     {
      const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_D1);
      if(hold_seconds > 0 && TimeCurrent() - open_time >= hold_seconds)
         return true;
     }

   if(strategy_exit_mode == 1 || strategy_exit_mode == 2)
     {
      const double threshold = (strategy_exit_mode == 1) ? 50.0 : 70.0;
      const double crsi = Strategy_ConnorsRSI();
      return (crsi > threshold);
     }

   double close1 = 0.0;
   if(!Strategy_LastClosedClose(close1))
      return false;
   const double sma_exit = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_exit_period, 1);
   if(sma_exit <= 0.0)
      return false;
   return (close1 > sma_exit);
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
