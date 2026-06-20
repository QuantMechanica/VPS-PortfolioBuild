#property strict
#property version   "5.0"
#property description "QM5_9460 gh-gold-orb H1 opening range breakout"

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
input int    qm_ea_id                   = 9460;
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
input int    strategy_session_open_hour_broker  = 1;
input int    strategy_session_close_hour_broker = 23;
input int    strategy_consolidation_bars        = 3;
input int    strategy_stop_loss_pips            = 400;
input int    strategy_take_profit_pips          = 1200;
input int    strategy_max_spread_points         = 0;

int    g_session_date_key       = 0;
double g_range_high             = 0.0;
double g_range_low              = 0.0;
int    g_inside_bar_count       = 0;
bool   g_range_active           = false;
bool   g_range_final            = false;
bool   g_trade_taken_this_day   = false;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

void ResetSessionState(const int date_key)
  {
   g_session_date_key = date_key;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_inside_bar_count = 0;
   g_range_active = false;
   g_range_final = false;
   g_trade_taken_this_day = false;
  }

bool BuildFixedStops(const QM_OrderType side, double &out_sl, double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   out_sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_loss_pips);
   out_tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_take_profit_pips);
   return (out_sl > 0.0 && out_tp > 0.0);
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

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0)
        {
         const double spread_points = (ask - bid) / point;
         if(spread_points > (double)strategy_max_spread_points)
            return true;
        }
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

   if(strategy_consolidation_bars < 1 ||
      strategy_stop_loss_pips <= 0 ||
      strategy_take_profit_pips <= 0)
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar ORB session timestamp.
   if(bar_time <= 0)
      return false;

   const int date_key = DateKey(bar_time);
   if(date_key != g_session_date_key)
      ResetSessionState(date_key);

   const int bar_hour = HourOf(bar_time);
   if(strategy_session_close_hour_broker > strategy_session_open_hour_broker &&
      bar_hour >= strategy_session_close_hour_broker)
      return false;

   const double bar_high = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: bespoke opening-range high.
   const double bar_low = iLow(_Symbol, PERIOD_H1, 1); // perf-allowed: bespoke opening-range low.
   const double bar_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar breakout confirmation.
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low || bar_close <= 0.0)
      return false;

   if(bar_hour == strategy_session_open_hour_broker)
     {
      g_range_high = bar_high;
      g_range_low = bar_low;
      g_inside_bar_count = 0;
      g_range_active = true;
      g_range_final = false;
      g_trade_taken_this_day = false;
      return false;
     }

   if(!g_range_active)
      return false;

   if(!g_range_final)
     {
      const bool inside_range = (bar_high <= g_range_high && bar_low >= g_range_low);
      if(inside_range)
        {
         g_inside_bar_count++;
         if(g_inside_bar_count >= strategy_consolidation_bars)
            g_range_final = true;
        }
      else
        {
         if(bar_high > g_range_high)
            g_range_high = bar_high;
         if(bar_low < g_range_low)
            g_range_low = bar_low;
         g_inside_bar_count = 0;
        }
      return false;
     }

   if(g_trade_taken_this_day)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(bar_close > g_range_high)
     {
      req.type = QM_BUY;
      if(!BuildFixedStops(req.type, req.sl, req.tp))
         return false;
      req.reason = "GOLD_ORB_LONG_BREAKOUT";
      g_trade_taken_this_day = true;
      return true;
     }

   if(bar_close < g_range_low)
     {
      req.type = QM_SELL;
      if(!BuildFixedStops(req.type, req.sl, req.tp))
         return false;
      req.reason = "GOLD_ORB_SHORT_BREAKOUT";
      g_trade_taken_this_day = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, scaling, or partial close logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const int hour_now = HourOf(broker_now);
   if(strategy_session_close_hour_broker > strategy_session_open_hour_broker &&
      hour_now >= strategy_session_close_hour_broker)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to the framework news filter for P8 News Impact phase.
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
