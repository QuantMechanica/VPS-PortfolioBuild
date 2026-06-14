#property strict
#property version   "5.0"
#property description "QM5_10733 TradingView Xiznit Universal ORB"

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
input int    qm_ea_id                   = 10733;
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
input int             strategy_or_start_hhmm       = 1630;
input int             strategy_or_end_hhmm         = 1645;
input int             strategy_session_end_hhmm    = 2300;
input int             strategy_rsi_period          = 14;
input int             strategy_atr_period          = 20;
input int             strategy_atr_avg_bars        = 20;
input double          strategy_atr_min_ratio       = 0.70;
input double          strategy_atr_max_ratio       = 1.80;
input int             strategy_volume_sma_bars     = 20;
input double          strategy_volume_mult         = 1.20;
input ENUM_TIMEFRAMES strategy_htf                 = PERIOD_M15;
input int             strategy_htf_ema_period      = 50;
input double          strategy_take_profit_rr      = 2.00;
input int             strategy_min_stop_points     = 20;
input int             strategy_max_spread_points   = 0;

int    g_or_day_key = 0;
bool   g_or_started = false;
bool   g_or_complete = false;
bool   g_trade_taken_session = false;
double g_or_high = 0.0;
double g_or_low = 0.0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_HhmmInRange(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

void Strategy_ResetSession(const int day_key)
  {
   g_or_day_key = day_key;
   g_or_started = false;
   g_or_complete = false;
   g_trade_taken_session = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

void Strategy_AdvanceOpeningRange()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: bounded closed-bar ORB session state
   if(bar_time <= 0)
      return;

   const int day_key = Strategy_DayKey(bar_time);
   if(day_key != g_or_day_key)
      Strategy_ResetSession(day_key);

   const int hhmm = Strategy_Hhmm(bar_time);
   if(Strategy_HhmmInRange(hhmm, strategy_or_start_hhmm, strategy_or_end_hhmm))
     {
      const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar OR high update
      const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar OR low update
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
         return;

      if(!g_or_started)
        {
         g_or_high = bar_high;
         g_or_low = bar_low;
         g_or_started = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar_high);
         g_or_low = MathMin(g_or_low, bar_low);
        }
     }

   if(g_or_started && !g_or_complete && !Strategy_HhmmInRange(hhmm, strategy_or_start_hhmm, strategy_or_end_hhmm) && hhmm >= strategy_or_end_hhmm)
      g_or_complete = true;
  }

bool Strategy_VolumeConfirms()
  {
   if(strategy_volume_sma_bars <= 0 || strategy_volume_mult <= 0.0)
      return true;

   const long signal_volume = iVolume(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB volume confirmation
   if(signal_volume <= 0)
      return false;

   double volume_sum = 0.0;
   int samples = 0;
   for(int shift = 2; shift < 2 + strategy_volume_sma_bars; ++shift)
     {
      const long v = iVolume(_Symbol, _Period, shift); // perf-allowed: bounded 20-bar tick-volume SMA on new bar only
      if(v <= 0)
         continue;
      volume_sum += (double)v;
      samples++;
     }

   if(samples <= 0)
      return false;
   return ((double)signal_volume > strategy_volume_mult * (volume_sum / samples));
  }

bool Strategy_AtrNormal()
  {
   const double atr_now = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr_now <= 0.0 || strategy_atr_avg_bars <= 0)
      return false;

   double atr_sum = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= strategy_atr_avg_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      atr_sum += atr;
      samples++;
     }

   if(samples <= 0)
      return false;

   const double ratio = atr_now / (atr_sum / samples);
   return (ratio >= strategy_atr_min_ratio && ratio <= strategy_atr_max_ratio);
  }

bool Strategy_IsInsideBar()
  {
   const double h1 = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar inside-bar filter
   const double l1 = iLow(_Symbol, _Period, 1); // perf-allowed: closed-bar inside-bar filter
   const double h2 = iHigh(_Symbol, _Period, 2); // perf-allowed: closed-bar inside-bar filter
   const double l2 = iLow(_Symbol, _Period, 2); // perf-allowed: closed-bar inside-bar filter
   if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return true;
   return (h1 < h2 && l1 > l2);
  }

bool Strategy_StopValid(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && sl <= entry)
      return false;
   return (MathAbs(entry - sl) / point >= strategy_min_stop_points);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

   if(Strategy_HasOpenPosition())
      return false;

   const int hhmm = Strategy_Hhmm(TimeCurrent());
   if(!Strategy_HhmmInRange(hhmm, strategy_or_start_hhmm, strategy_session_end_hhmm))
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

   Strategy_AdvanceOpeningRange();

   if(g_trade_taken_session || Strategy_HasOpenPosition())
      return false;
   if(!g_or_complete || g_or_high <= 0.0 || g_or_low <= 0.0 || g_or_high <= g_or_low)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar session-end entry guard
   if(bar_time <= 0)
      return false;
   const int hhmm = Strategy_Hhmm(bar_time);
   if(!Strategy_HhmmInRange(hhmm, strategy_or_end_hhmm, strategy_session_end_hhmm))
      return false;

   const double close_confirm = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar smart-breakout confirmation
   const double open_confirm = iOpen(_Symbol, _Period, 1); // perf-allowed: closed-bar smart-breakout confirmation
   const double high_confirm = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar stop candidate
   const double low_confirm = iLow(_Symbol, _Period, 1); // perf-allowed: closed-bar stop candidate
   const double close_breakout = iClose(_Symbol, _Period, 2); // perf-allowed: prior closed-bar breakout detection
   if(close_confirm <= 0.0 || open_confirm <= 0.0 || high_confirm <= 0.0 || low_confirm <= 0.0 || close_breakout <= 0.0)
      return false;

   if(Strategy_IsInsideBar())
      return false;
   if(!Strategy_AtrNormal())
      return false;
   if(!Strategy_VolumeConfirms())
      return false;

   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const double htf_ema = QM_EMA(_Symbol, strategy_htf, strategy_htf_ema_period, 1);
   if(rsi <= 0.0 || htf_ema <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close_breakout > g_or_high && close_confirm > g_or_high && close_confirm > open_confirm &&
      rsi >= 50.0 && close_confirm > htf_ema)
     {
      req.type = QM_BUY;
      req.price = ask;
      const double entry_extreme_sl = low_confirm;
      const double selected_sl = (entry_extreme_sl > g_or_low && entry_extreme_sl < req.price) ? entry_extreme_sl : g_or_low;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, selected_sl);
      if(!Strategy_StopValid(req.type, req.price, req.sl))
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "XIZNIT_ORB_LONG_CONFIRM";
      g_trade_taken_session = true;
      return true;
     }

   if(close_breakout < g_or_low && close_confirm < g_or_low && close_confirm < open_confirm &&
      rsi <= 50.0 && close_confirm < htf_ema)
     {
      req.type = QM_SELL;
      req.price = bid;
      const double entry_extreme_sl = high_confirm;
      const double selected_sl = (entry_extreme_sl < g_or_high && entry_extreme_sl > req.price) ? entry_extreme_sl : g_or_high;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, selected_sl);
      if(!Strategy_StopValid(req.type, req.price, req.sl))
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "XIZNIT_ORB_SHORT_CONFIRM";
      g_trade_taken_session = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      if(initial_risk <= point)
         continue;

      const double favorable = is_buy ? (market - open_price) : (open_price - market);
      if(favorable < initial_risk)
         continue;

      const bool improves = is_buy ? (current_sl < open_price) : (current_sl > open_price);
      if(improves)
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "xiznit_orb_move_to_breakeven_1r");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int hhmm = Strategy_Hhmm(TimeCurrent());
   if(!Strategy_HhmmInRange(hhmm, strategy_or_start_hhmm, strategy_session_end_hhmm))
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
