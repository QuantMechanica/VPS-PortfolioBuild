#property strict
#property version   "5.0"
#property description "QM5_9977 ForexFactory Simplicity Heiken Ashi EMA100"

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
input int    qm_ea_id                   = 9977;
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
input int    strategy_ema_period              = 100;
input int    strategy_atr_period              = 14;
input double strategy_min_stop_atr_mult       = 0.40;
input int    strategy_stop_buffer_pips        = 2;
input double strategy_take_profit_rr          = 1.0;
input int    strategy_session_start_utc       = 6;
input int    strategy_session_end_utc         = 15;
input double strategy_max_spread_stop_fraction = 0.08;
input int    strategy_ha_warmup_bars          = 80;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool     g_trade_taken_this_session = false;
int      g_session_day_key = -1;

double Strategy_PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

int Strategy_UtcDayKey(const datetime utc_now)
  {
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool Strategy_InUtcSession(const datetime utc_now)
  {
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   if(strategy_session_start_utc == strategy_session_end_utc)
      return true;
   if(strategy_session_start_utc < strategy_session_end_utc)
      return (dt.hour >= strategy_session_start_utc && dt.hour < strategy_session_end_utc);
   return (dt.hour >= strategy_session_start_utc || dt.hour < strategy_session_end_utc);
  }

void Strategy_RefreshSessionState()
  {
   const int day_key = Strategy_UtcDayKey(TimeGMT());
   if(day_key != g_session_day_key)
     {
      g_session_day_key = day_key;
      g_trade_taken_this_session = false;
     }
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;

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

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      g_trade_taken_this_session = true;
      return true;
     }

   return false;
  }

bool Strategy_HeikenAshiOpenClose(const int shift, double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   if(shift < 1)
      return false;

   const int warmup = MathMax(strategy_ha_warmup_bars, shift + 2);
   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;

   for(int s = warmup; s >= shift; --s)
     {
      const double o = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, s);   // perf-allowed: bounded closed-bar Heiken Ashi structural math
      const double h = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, s);   // perf-allowed: bounded closed-bar Heiken Ashi structural math
      const double l = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, s);    // perf-allowed: bounded closed-bar Heiken Ashi structural math
      const double c = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, s);  // perf-allowed: bounded closed-bar Heiken Ashi structural math
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
         return false;

      const double cur_ha_close = (o + h + l + c) / 4.0;
      const double cur_ha_open = (s == warmup) ? ((o + c) / 2.0) : ((prev_ha_open + prev_ha_close) / 2.0);

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;
      if(s == shift)
        {
         ha_open = cur_ha_open;
         ha_close = cur_ha_close;
         return true;
        }
     }

   return false;
  }

int Strategy_HeikenAshiColor(const int shift)
  {
   double ha_open = 0.0;
   double ha_close = 0.0;
   if(!Strategy_HeikenAshiOpenClose(shift, ha_open, ha_close))
      return 0;
   if(ha_close > ha_open)
      return 1;
   if(ha_close < ha_open)
      return -1;
   return 0;
  }

bool Strategy_SpreadWithinStop(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0)
      return false;

   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_fraction);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_RefreshSessionState();

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   if(Strategy_SelectOurPosition(ticket, position_type))
      return false;

   if(!Strategy_InUtcSession(TimeGMT()))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

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

   Strategy_RefreshSessionState();
   if(g_trade_taken_this_session)
      return false;
   if(!Strategy_InUtcSession(TimeGMT()))
      return false;
   if(strategy_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_min_stop_atr_mult <= 0.0 || strategy_stop_buffer_pips < 0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: card requires closed signal candle close vs EMA100
   const double low_1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);     // perf-allowed: card stop is signal candle low minus buffer
   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);   // perf-allowed: card stop is signal candle high plus buffer
   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double atr_1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(close_1 <= 0.0 || low_1 <= 0.0 || high_1 <= 0.0 || ema_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   const int ha_1 = Strategy_HeikenAshiColor(1);
   const int ha_2 = Strategy_HeikenAshiColor(2);
   if(ha_1 == 0 || ha_2 == 0)
      return false;

   const bool long_signal = (close_1 > ema_1 && ha_2 < 0 && ha_1 > 0);
   const bool short_signal = (close_1 < ema_1 && ha_2 > 0 && ha_1 < 0);
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   const double pip = Strategy_PipDistance();
   if(entry <= 0.0 || pip <= 0.0)
      return false;

   const double buffer = strategy_stop_buffer_pips * pip;
   const double min_stop_distance = atr_1 * strategy_min_stop_atr_mult;
   if(long_signal)
     {
      req.sl = QM_StopRulesNormalizePrice(_Symbol, low_1 - buffer);
      if(entry - req.sl < min_stop_distance)
         req.sl = QM_StopRulesNormalizePrice(_Symbol, entry - min_stop_distance);
      req.reason = "HA_EMA100_LONG";
     }
   else
     {
      req.sl = QM_StopRulesNormalizePrice(_Symbol, high_1 + buffer);
      if(req.sl - entry < min_stop_distance)
         req.sl = QM_StopRulesNormalizePrice(_Symbol, entry + min_stop_distance);
      req.reason = "HA_EMA100_SHORT";
     }

   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(!Strategy_SpreadWithinStop(entry, req.sl))
      return false;

   g_trade_taken_this_session = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline: no partial close, break-even, or trailing in P2.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(ticket, position_type))
      return false;

   const int ha_1 = Strategy_HeikenAshiColor(1);
   const int ha_2 = Strategy_HeikenAshiColor(2);
   if(ha_1 == 0 || ha_2 == 0)
      return false;

   if(position_type == POSITION_TYPE_BUY && ha_2 > 0 && ha_1 < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && ha_2 < 0 && ha_1 > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
      return true;
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
