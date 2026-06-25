#property strict
#property version   "5.0"
#property description "QM5_11870 Dead-Time Range Fade"

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
input int    qm_ea_id                   = 11870;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_reference_utc_hour = 20;
input int    strategy_window_end_utc_hour = 0;
input int    strategy_stop_pips = 12;
input int    strategy_take_pips = 12;
input int    strategy_max_spread_pips = 0;

double g_deadtime_reference_price = 0.0;
int    g_deadtime_reference_side = 0;       // +1 = buy limit, -1 = sell limit
int    g_deadtime_reference_session = -1;
int    g_deadtime_order_session = -1;

int Strategy_NormalizeHour(const int hour)
  {
   int normalized = hour % 24;
   if(normalized < 0)
      normalized += 24;
   return normalized;
  }

int Strategy_EffectiveHour(const int configured_hour, const datetime utc_time)
  {
   if(QM_IsUSDSTUTC(utc_time))
      return Strategy_NormalizeHour(configured_hour - 1);
   return Strategy_NormalizeHour(configured_hour);
  }

int Strategy_SessionKey(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);
   return (dt.year * 1000) + dt.day_of_year;
  }

bool Strategy_HourInWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return false;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

int Strategy_SecondsUntilWindowEnd(const datetime utc_time, const int end_hour)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);

   int seconds = ((end_hour - dt.hour) * 3600) - (dt.min * 60) - dt.sec;
   if(seconds <= 0)
      seconds += 24 * 3600;
   return seconds;
  }

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
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
   if(_Period != PERIOD_H1)
      return true;

   if(strategy_reference_utc_hour < 0 || strategy_reference_utc_hour > 23 ||
      strategy_window_end_utc_hour < 0 || strategy_window_end_utc_hour > 23 ||
      strategy_stop_pips <= 0 || strategy_take_pips <= 0)
      return true;

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > 0.0 && bid > 0.0 && ask > bid && cap > 0.0 && (ask - bid) > cap)
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

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: card requires the H1 candle that closed at the UTC reference time; caller already gated this to one read per new bar.
   if(CopyRates(_Symbol, PERIOD_H1, 0, 2, rates) != 2)
      return false;

   const datetime current_bar_utc = QM_BrokerToUTC(rates[0].time);
   MqlDateTime utc_dt;
   ZeroMemory(utc_dt);
   TimeToStruct(current_bar_utc, utc_dt);
   const int reference_hour = Strategy_EffectiveHour(strategy_reference_utc_hour, current_bar_utc);
   const int window_end_hour = Strategy_EffectiveHour(strategy_window_end_utc_hour, current_bar_utc);
   const int session_key = Strategy_SessionKey(current_bar_utc);

   if(utc_dt.hour == reference_hour && utc_dt.min == 0)
     {
      const double reference_open = rates[1].open;
      const double reference_close = rates[1].close;
      if(reference_open <= 0.0 || reference_close <= 0.0 || reference_open == reference_close)
        {
         g_deadtime_reference_price = 0.0;
         g_deadtime_reference_side = 0;
         g_deadtime_reference_session = session_key;
        }
      else
        {
         g_deadtime_reference_price = reference_close;
         g_deadtime_reference_side = (reference_close > reference_open) ? -1 : 1;
         g_deadtime_reference_session = session_key;
        }
     }

   if(g_deadtime_reference_session != session_key ||
      g_deadtime_reference_price <= 0.0 ||
      g_deadtime_reference_side == 0 ||
      g_deadtime_order_session == session_key ||
      !Strategy_HourInWindow(utc_dt.hour, reference_hour, window_end_hour) ||
      Strategy_HasPendingOrder())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   QM_OrderType side = QM_BUY_LIMIT;
   string reason = "";
   if(g_deadtime_reference_side < 0)
     {
      if(ask >= g_deadtime_reference_price - point)
         return false;
      side = QM_SELL_LIMIT;
      reason = "DEADTIME_RANGE_FADE_SHORT";
     }
   else
     {
      if(bid <= g_deadtime_reference_price + point)
         return false;
      side = QM_BUY_LIMIT;
      reason = "DEADTIME_RANGE_FADE_LONG";
     }

   const int seconds_to_expiry = Strategy_SecondsUntilWindowEnd(current_bar_utc, window_end_hour);
   if(seconds_to_expiry <= 0)
      return false;

   const double entry = QM_StopRulesNormalizePrice(_Symbol, g_deadtime_reference_price);
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_take_pips);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = seconds_to_expiry;
   g_deadtime_order_session = session_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or scale-in.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits are fixed SL/TP; unfilled limit orders expire at 00:00 UTC.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Card has no strategy-specific news blackout; defer to the framework.
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
