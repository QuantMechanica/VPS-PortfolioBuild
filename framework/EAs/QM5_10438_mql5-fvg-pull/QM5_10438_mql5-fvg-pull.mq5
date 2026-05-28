#property strict
#property version   "5.0"
#property description "QM5_10438 MQL5 FVG Pullback Regime Filter"

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
input int    qm_ea_id                   = 10438;
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
input int             strategy_atr_period        = 14;
input double          strategy_atr_sl_mult       = 1.5;
input double          strategy_rr                = 2.0;
input ENUM_TIMEFRAMES strategy_regime_tf         = PERIOD_H1;
input int             strategy_ema_fast          = 50;
input int             strategy_ema_slow          = 200;
input int             strategy_adx_period        = 14;
input double          strategy_adx_min           = 20.0;
input double          strategy_h1_atr_stop_cap   = 3.0;
input double          strategy_spread_stop_frac  = 0.10;
input int             strategy_session_start_h   = 7;
input int             strategy_session_end_h     = 20;

struct FvgZone
  {
   bool     active;
   bool     traded;
   int      direction;
   double   lower;
   double   upper;
   datetime created_bar_time;
  };

#define STRATEGY_MAX_FVG_ZONES 64
FvgZone g_fvg_zones[STRATEGY_MAX_FVG_ZONES];
int     g_fvg_next_slot = 0;

int Strategy_BrokerHour(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

bool Strategy_CloseInsideZone(const double close_price, const FvgZone &zone)
  {
   return (close_price >= zone.lower && close_price <= zone.upper);
  }

void Strategy_StoreFvg(const int direction,
                       const double lower,
                       const double upper,
                       const datetime created_bar_time)
  {
   if(lower <= 0.0 || upper <= 0.0 || lower >= upper)
      return;

   for(int i = 0; i < STRATEGY_MAX_FVG_ZONES; ++i)
     {
      if(g_fvg_zones[i].active && g_fvg_zones[i].created_bar_time == created_bar_time &&
         g_fvg_zones[i].direction == direction)
         return;
     }

   const int slot = g_fvg_next_slot;
   g_fvg_zones[slot].active = true;
   g_fvg_zones[slot].traded = false;
   g_fvg_zones[slot].direction = direction;
   g_fvg_zones[slot].lower = lower;
   g_fvg_zones[slot].upper = upper;
   g_fvg_zones[slot].created_bar_time = created_bar_time;

   g_fvg_next_slot = (g_fvg_next_slot + 1) % STRATEGY_MAX_FVG_ZONES;
  }

void Strategy_DetectLatestFvg()
  {
   const datetime latest_closed_time = iTime(_Symbol, _Period, 1);
   if(latest_closed_time <= 0)
      return;

   const double old_high = iHigh(_Symbol, _Period, 3);
   const double old_low = iLow(_Symbol, _Period, 3);
   const double latest_high = iHigh(_Symbol, _Period, 1);
   const double latest_low = iLow(_Symbol, _Period, 1);
   if(old_high <= 0.0 || old_low <= 0.0 || latest_high <= 0.0 || latest_low <= 0.0)
      return;

   if(old_high < latest_low)
      Strategy_StoreFvg(1, old_high, latest_low, latest_closed_time);
   if(old_low > latest_high)
      Strategy_StoreFvg(-1, latest_high, old_low, latest_closed_time);
  }

bool Strategy_RegimeAllows(const int direction)
  {
   const double ema_fast = QM_EMA(_Symbol, strategy_regime_tf, strategy_ema_fast, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_regime_tf, strategy_ema_slow, 1);
   const double adx = QM_ADX(_Symbol, strategy_regime_tf, strategy_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, strategy_regime_tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, strategy_regime_tf, strategy_adx_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || adx <= 0.0 || plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   if(direction > 0)
      return (ema_fast > ema_slow && adx >= strategy_adx_min && plus_di > minus_di);
   return (ema_fast < ema_slow && adx >= strategy_adx_min && minus_di > plus_di);
  }

bool Strategy_StopAndSpreadAllowed(const double stop_distance)
  {
   if(stop_distance <= 0.0)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_h1 <= 0.0 || stop_distance > strategy_h1_atr_stop_cap * atr_h1)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask <= 0.0 || bid <= 0.0 || spread < 0.0)
      return false;

   return (spread <= strategy_spread_stop_frac * stop_distance);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int hour = Strategy_BrokerHour(TimeCurrent());
   if(strategy_session_start_h == strategy_session_end_h)
      return false;
   if(strategy_session_start_h < strategy_session_end_h)
      return (hour < strategy_session_start_h || hour >= strategy_session_end_h);
   return (hour < strategy_session_start_h && hour >= strategy_session_end_h);
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

   Strategy_DetectLatestFvg();

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return false;

   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stop_distance = strategy_atr_sl_mult * atr_m15;
   if(!Strategy_StopAndSpreadAllowed(stop_distance))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   for(int i = 0; i < STRATEGY_MAX_FVG_ZONES; ++i)
     {
      if(!g_fvg_zones[i].active || g_fvg_zones[i].traded)
         continue;
      if(g_fvg_zones[i].created_bar_time == iTime(_Symbol, _Period, 1))
         continue;
      if(!Strategy_CloseInsideZone(close1, g_fvg_zones[i]))
         continue;
      if(!Strategy_RegimeAllows(g_fvg_zones[i].direction))
         continue;

      g_fvg_zones[i].traded = true;

      if(g_fvg_zones[i].direction > 0)
        {
         req.type = QM_BUY;
         req.price = ask;
         req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr);
         req.reason = "QM5_10438_BULL_FVG_PULLBACK";
        }
      else
        {
         req.type = QM_SELL;
         req.price = bid;
         req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr);
         req.reason = "QM5_10438_BEAR_FVG_PULLBACK";
        }

      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline excludes partial close, break-even, and trailing.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Exits are handled by the initial SL/TP and framework Friday close.
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
