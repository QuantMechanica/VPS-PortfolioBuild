#property strict
#property version   "5.0"
#property description "QM5_10774 TradingView Liquidity Day PDH/PDL Breakout"

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
input int    qm_ea_id                   = 10774;
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
input bool   strategy_london_enabled       = true;
input int    strategy_london_start_hour    = 8;
input int    strategy_london_end_hour      = 17;
input bool   strategy_newyork_enabled      = true;
input int    strategy_newyork_start_hour   = 14;
input int    strategy_newyork_end_hour     = 22;
input double strategy_stop_percent         = 0.50;
input double strategy_target_percent       = 1.00;
input int    strategy_atr_period           = 14;
input bool   strategy_min_atr_gate_enabled = false;
input double strategy_min_atr_points       = 0.0;
input int    strategy_max_spread_points    = 50;

datetime g_strategy_day_start = 0;
double   g_prior_day_high = 0.0;
double   g_prior_day_low = 0.0;
bool     g_long_taken_today = false;
bool     g_short_taken_today = false;

bool Strategy_ReadCurrentAndPriorDay()
  {
   MqlRates day_rates[];
   ArraySetAsSeries(day_rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, day_rates) != 2) // perf-allowed: D1 PDH/PDL structural read, called only from closed-bar entry path.
      return false;

   if(day_rates[0].time != g_strategy_day_start)
     {
      g_strategy_day_start = day_rates[0].time;
      g_prior_day_high = day_rates[1].high;
      g_prior_day_low = day_rates[1].low;
      g_long_taken_today = false;
      g_short_taken_today = false;
     }

   return (g_prior_day_high > 0.0 && g_prior_day_low > 0.0 && g_prior_day_high > g_prior_day_low);
  }

bool Strategy_ReadClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates) != 1) // perf-allowed: one closed-bar read, gated by framework QM_IsNewBar before Strategy_EntrySignal.
      return false;
   bar = rates[0];
   return (bar.close > 0.0);
  }

bool Strategy_HourInWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool Strategy_InsideEnabledSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(strategy_london_enabled &&
      Strategy_HourInWindow(dt.hour, strategy_london_start_hour, strategy_london_end_hour))
      return true;

   if(strategy_newyork_enabled &&
      Strategy_HourInWindow(dt.hour, strategy_newyork_start_hour, strategy_newyork_end_hour))
      return true;

   return false;
  }

bool Strategy_AfterNewYorkClose(const datetime broker_time)
  {
   if(!strategy_newyork_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(strategy_newyork_start_hour < strategy_newyork_end_hour)
      return (dt.hour >= strategy_newyork_end_hour || dt.hour < strategy_london_start_hour);

   return (dt.hour >= strategy_newyork_end_hour && dt.hour < strategy_newyork_start_hour);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }

   return false;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double Strategy_StopDistance(const double entry_price)
  {
   if(entry_price <= 0.0 || strategy_stop_percent <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   double stop_distance = entry_price * strategy_stop_percent * 0.01;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = (stops_level > 0) ? (stops_level * point) : point;

   if(stop_distance < min_stop_distance)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      stop_distance = MathMax(min_stop_distance, atr);
     }

   return stop_distance;
  }

bool Strategy_BuildRequest(QM_EntryRequest &req, const QM_OrderType side, const double entry_price)
  {
   const double stop_distance = Strategy_StopDistance(entry_price);
   if(stop_distance <= 0.0 || strategy_target_percent <= 0.0 || strategy_stop_percent <= 0.0)
      return false;

   const double rr = strategy_target_percent / strategy_stop_percent;
   const double target_distance = stop_distance * rr;

   req.type = side;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(side == QM_BUY)
     {
      req.sl = Strategy_NormalizePrice(entry_price - stop_distance);
      req.tp = Strategy_NormalizePrice(entry_price + target_distance);
      req.reason = "TV_LIQ_DAY_PDH_BREAK";
     }
   else
     {
      req.sl = Strategy_NormalizePrice(entry_price + stop_distance);
      req.tp = Strategy_NormalizePrice(entry_price - target_distance);
      req.reason = "TV_LIQ_DAY_PDL_BREAK";
     }

   return (req.sl > 0.0 && req.tp > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   if(!Strategy_InsideEnabledSession(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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

   if(!Strategy_InsideEnabledSession(TimeCurrent()))
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_ReadCurrentAndPriorDay())
      return false;

   if(strategy_min_atr_gate_enabled && strategy_min_atr_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(point <= 0.0 || atr <= 0.0 || (atr / point) < strategy_min_atr_points)
         return false;
     }

   MqlRates closed_bar;
   if(!Strategy_ReadClosedBar(closed_bar))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(!g_long_taken_today && closed_bar.close > g_prior_day_high)
     {
      if(Strategy_BuildRequest(req, QM_BUY, ask))
        {
         g_long_taken_today = true;
         return true;
        }
     }

   if(!g_short_taken_today && closed_bar.close < g_prior_day_low)
     {
      if(Strategy_BuildRequest(req, QM_SELL, bid))
        {
         g_short_taken_today = true;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed percentage SL/TP only; no trailing, BE, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   if(Strategy_AfterNewYorkClose(TimeCurrent()))
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Framework two-axis news filter handles the card's news/no-news policy.
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
