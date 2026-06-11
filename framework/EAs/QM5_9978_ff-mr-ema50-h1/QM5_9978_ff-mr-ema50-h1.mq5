#property strict
#property version   "5.0"
#property description "QM5_9978 ForexFactory Mr EMA50 H1 Continuation"

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
input int    qm_ea_id                   = 9978;
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
input ENUM_TIMEFRAMES strategy_timeframe                    = PERIOD_H1;
input int             strategy_ema_period                   = 50;
input int             strategy_min_first_open_distance_pips = 10;
input int             strategy_max_first_open_distance_pips = 20;
input int             strategy_invalid_distance_pips        = 40;
input int             strategy_stop_pips                    = 20;
input int             strategy_min_stop_buffer_pips         = 2;
input int             strategy_trail_trigger_pips           = 10;
input int             strategy_trail_distance_pips          = 8;
input int             strategy_time_stop_bars               = 24;
input double          strategy_max_spread_pips              = 2.5;
input double          strategy_max_spread_stop_frac         = 0.08;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double Strategy_PipsToPrice(const double pips)
  {
   const double pip_size = Strategy_PipSize();
   if(pips <= 0.0 || pip_size <= 0.0)
      return 0.0;
   return pips * pip_size;
  }

double Strategy_SpreadDistance()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
      return true;
     }

   return false;
  }

double Strategy_StopDistance()
  {
   const double fixed_stop = Strategy_PipsToPrice((double)strategy_stop_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(fixed_stop <= 0.0 || point <= 0.0)
      return 0.0;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double broker_min = MathMax(0, stops_level) * point;
   const double spread = Strategy_SpreadDistance();
   if(spread > 0.0 && fixed_stop < broker_min + spread)
      return broker_min + Strategy_PipsToPrice((double)strategy_min_stop_buffer_pips);

   return fixed_stop;
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double spread = Strategy_SpreadDistance();
   const double max_spread = Strategy_PipsToPrice(strategy_max_spread_pips);
   const double stop_dist = Strategy_StopDistance();
   if(spread <= 0.0 || max_spread <= 0.0 || stop_dist <= 0.0)
      return false;

   if(spread > max_spread)
      return false;
   if(spread > stop_dist * strategy_max_spread_stop_frac)
      return false;

   return true;
  }

bool Strategy_SecondOpenSetup(const bool want_long)
  {
   if(strategy_ema_period <= 0)
      return false;

   // perf-allowed: this source defines entries by bar opens. These are fixed
   // O(1) reads, with no history scan, and entry calls are framework new-bar gated.
   const double open0 = iOpen(_Symbol, strategy_timeframe, 0); // perf-allowed
   const double open1 = iOpen(_Symbol, strategy_timeframe, 1); // perf-allowed
   const double open2 = iOpen(_Symbol, strategy_timeframe, 2); // perf-allowed
   const double ema0 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 0, PRICE_OPEN);
   const double ema1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1, PRICE_OPEN);
   const double ema2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 2, PRICE_OPEN);
   if(open0 <= 0.0 || open1 <= 0.0 || open2 <= 0.0 || ema0 <= 0.0 || ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double min_dist = Strategy_PipsToPrice((double)strategy_min_first_open_distance_pips);
   const double max_dist = Strategy_PipsToPrice((double)strategy_max_first_open_distance_pips);
   const double invalid_dist = Strategy_PipsToPrice((double)strategy_invalid_distance_pips);
   if(min_dist <= 0.0 || max_dist <= 0.0 || invalid_dist <= 0.0)
      return false;

   if(want_long)
     {
      const double dist = open1 - ema1;
      return (open2 <= ema2 &&
              open1 > ema1 &&
              open0 > ema0 &&
              dist >= min_dist &&
              dist <= max_dist &&
              dist <= invalid_dist);
     }

   const double dist = ema1 - open1;
   return (open2 >= ema2 &&
           open1 < ema1 &&
           open0 < ema0 &&
           dist >= min_dist &&
           dist <= max_dist &&
           dist <= invalid_dist);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by the framework
   // before this hook; the card has no time-of-day gate beyond H1 cadence.
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   ulong ticket;
   if(Strategy_SelectOurPosition(ptype, opened_at, ticket))
      return false;

   if((ENUM_TIMEFRAMES)_Period != strategy_timeframe)
      return true;

   if(strategy_ema_period <= 0 ||
      strategy_min_first_open_distance_pips <= 0 ||
      strategy_max_first_open_distance_pips < strategy_min_first_open_distance_pips ||
      strategy_invalid_distance_pips <= 0 ||
      strategy_stop_pips <= 0 ||
      strategy_trail_trigger_pips <= 0 ||
      strategy_trail_distance_pips <= 0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return true;

   return !Strategy_SpreadAllowsEntry();
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

   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   ulong ticket;
   if(Strategy_SelectOurPosition(ptype, opened_at, ticket))
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double stop_distance = Strategy_StopDistance();
   if(stop_distance <= 0.0)
      return false;

   if(Strategy_SecondOpenSetup(true))
     {
      const double entry = QM_EntryMarketPrice(QM_BUY);
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_distance);
      req.tp = 0.0;
      req.reason = "MR_EMA50_LONG_SECOND_OPEN";
      return (entry > 0.0 && req.sl > 0.0);
     }

   if(Strategy_SecondOpenSetup(false))
     {
      const double entry = QM_EntryMarketPrice(QM_SELL);
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry + stop_distance);
      req.tp = 0.0;
      req.reason = "MR_EMA50_SHORT_SECOND_OPEN";
      return (entry > 0.0 && req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   ulong ticket;
   if(!Strategy_SelectOurPosition(ptype, opened_at, ticket))
      return;

   QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_distance_pips);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   ulong ticket;
   if(!Strategy_SelectOurPosition(ptype, opened_at, ticket))
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(strategy_timeframe);
   if(opened_at > 0 && hold_seconds > 0 && TimeCurrent() - opened_at >= hold_seconds)
      return true;

   if(ptype == POSITION_TYPE_BUY)
      return Strategy_SecondOpenSetup(false);
   if(ptype == POSITION_TYPE_SELL)
      return Strategy_SecondOpenSetup(true);

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
