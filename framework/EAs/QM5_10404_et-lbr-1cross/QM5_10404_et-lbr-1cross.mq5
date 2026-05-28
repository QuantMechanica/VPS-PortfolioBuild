#property strict
#property version   "5.0"
#property description "QM5_10404 Elite Trader LBR First-Cross Pullback"

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
input int    qm_ea_id                   = 10404;
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
input int    strategy_macd_fast         = 3;
input int    strategy_macd_slow         = 10;
input int    strategy_macd_signal       = 16;
input double strategy_stop_pct          = 0.20;
input double strategy_target_pct        = 0.20;
input double strategy_be_trigger_pct    = 0.15;
input bool   strategy_use_ema_filter    = false;
input int    strategy_ema_fast          = 9;
input int    strategy_ema_slow          = 34;
input int    strategy_session_start_hour_broker = 0;
input int    strategy_session_end_hour_broker   = 21;

int  g_macd_regime = 0;
bool g_long_pullback_seen = false;
bool g_short_pullback_seen = false;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_BrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

bool Strategy_InSession()
  {
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour_broker));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour_broker));
   const int hour = Strategy_BrokerHour();
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   return (hour >= start_h || hour < end_h);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return (!Strategy_InSession() && !Strategy_HasOpenPosition());
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_stop_pct <= 0.0 ||
      strategy_target_pct <= 0.0 || strategy_be_trigger_pct < 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double macd_1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_1  = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double sig_2  = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double hist_1 = macd_1 - sig_1;
   const double hist_2 = macd_2 - sig_2;

   if(sig_1 > 0.0 && sig_2 <= 0.0)
     {
      g_macd_regime = 1;
      g_long_pullback_seen = false;
      g_short_pullback_seen = false;
     }
   else if(sig_1 < 0.0 && sig_2 >= 0.0)
     {
      g_macd_regime = -1;
      g_long_pullback_seen = false;
      g_short_pullback_seen = false;
     }

   if(g_macd_regime == 1 && hist_1 < 0.0)
      g_long_pullback_seen = true;
   if(g_macd_regime == -1 && hist_1 > 0.0)
      g_short_pullback_seen = true;

   const double ema_fast = strategy_use_ema_filter ? QM_EMA(_Symbol, tf, strategy_ema_fast, 1) : 0.0;
   const double ema_slow = strategy_use_ema_filter ? QM_EMA(_Symbol, tf, strategy_ema_slow, 1) : 0.0;
   if(strategy_use_ema_filter && (strategy_ema_fast <= 0 || strategy_ema_slow <= strategy_ema_fast ||
      ema_fast <= 0.0 || ema_slow <= 0.0))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_macd_regime == 1 && g_long_pullback_seen && hist_1 > hist_2 && sig_1 > 0.0)
     {
      if(strategy_use_ema_filter && ema_fast <= ema_slow)
         return false;
      const double stop_dist = ask * strategy_stop_pct / 100.0;
      const double target_dist = ask * strategy_target_pct / 100.0;
      req.type = QM_BUY;
      req.sl = Strategy_NormalizePrice(ask - stop_dist);
      req.tp = Strategy_NormalizePrice(ask + target_dist);
      req.reason = "QM5_10404_LBR_FIRST_CROSS_LONG";
      g_long_pullback_seen = false;
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(g_macd_regime == -1 && g_short_pullback_seen && hist_1 < hist_2 && sig_1 < 0.0)
     {
      if(strategy_use_ema_filter && ema_fast >= ema_slow)
         return false;
      const double stop_dist = bid * strategy_stop_pct / 100.0;
      const double target_dist = bid * strategy_target_pct / 100.0;
      req.type = QM_SELL;
      req.sl = Strategy_NormalizePrice(bid + stop_dist);
      req.tp = Strategy_NormalizePrice(bid - target_dist);
      req.reason = "QM5_10404_LBR_FIRST_CROSS_SHORT";
      g_short_pullback_seen = false;
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > bid && req.tp < bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_be_trigger_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double trigger_dist = open_price * strategy_be_trigger_pct / 100.0;
      if(open_price <= 0.0 || trigger_dist <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double px = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double moved = is_buy ? (px - open_price) : (open_price - px);
      if(px <= 0.0 || moved < trigger_dist)
         continue;

      const double target_sl = Strategy_NormalizePrice(open_price);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "QM5_10404_BREAKEVEN_015PCT");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return !Strategy_InSession();
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
