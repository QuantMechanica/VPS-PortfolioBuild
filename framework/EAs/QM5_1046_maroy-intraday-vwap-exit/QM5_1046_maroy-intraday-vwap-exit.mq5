#property strict
#property version   "5.0"
#property description "QM5_1046 Maroy intraday VWAP exit"

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
input int    qm_ea_id                   = 1046;
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
enum MaroyExitVariant
  {
   EXIT_VWAP   = 0,
   EXIT_LADDER = 1,
   EXIT_HYBRID = 2
  };

input ENUM_TIMEFRAMES strategy_vwap_tf       = PERIOD_M5;
input ENUM_TIMEFRAMES strategy_boundary_tf   = PERIOD_M30;
input int    strategy_lookback_days          = 14;
input double strategy_vol_k                  = 1.0;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 3.0;
input MaroyExitVariant strategy_exit_variant = EXIT_VWAP;
input double strategy_ladder_long_mfe_pct    = 1.0;
input double strategy_ladder_short_mfe_pct   = 2.0;
input double strategy_ladder_close_pct       = 75.0;
input double strategy_session_dd_cap_pct     = 20.0;
input int    strategy_session_start_hour     = 16;
input int    strategy_session_start_minute   = 30;
input int    strategy_session_end_hour       = 23;
input int    strategy_session_end_minute     = 0;
input int    strategy_max_spread_points      = 80;

double g_session_vwap = 0.0;
double g_vwap_pv_sum = 0.0;
double g_vwap_volume_sum = 0.0;
double g_upper_t = 0.0;
double g_lower_t = 0.0;
double g_session_open_price = 0.0;
double g_session_high_equity = 0.0;
double g_prev_closed_vwap_close = 0.0;
double g_last_closed_vwap_close = 0.0;
double g_prev_session_vwap = 0.0;
bool   g_session_dd_blocked = false;
bool   g_ladder_scaled = false;
bool   g_vwap_exit_signal = false;
int    g_session_yyyymmdd = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int Strategy_BrokerDateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_IsCashSession(const datetime t)
  {
   const int minute = Strategy_MinutesOfDay(t);
   const int start_minute = strategy_session_start_hour * 60 + strategy_session_start_minute;
   const int end_minute = strategy_session_end_hour * 60 + strategy_session_end_minute;
   return (minute >= start_minute && minute < end_minute);
  }

bool Strategy_IsSessionEnd(const datetime t)
  {
   const int minute = Strategy_MinutesOfDay(t);
   const int end_minute = strategy_session_end_hour * 60 + strategy_session_end_minute;
   return (minute >= end_minute);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_ResetSession(const datetime broker_time)
  {
   g_session_yyyymmdd = Strategy_BrokerDateKey(broker_time);
   g_session_vwap = 0.0;
   g_vwap_pv_sum = 0.0;
   g_vwap_volume_sum = 0.0;
   g_upper_t = 0.0;
   g_lower_t = 0.0;
   g_session_open_price = 0.0;
   g_session_high_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_prev_closed_vwap_close = 0.0;
   g_last_closed_vwap_close = 0.0;
   g_prev_session_vwap = 0.0;
   g_session_dd_blocked = false;
   g_ladder_scaled = false;
   g_vwap_exit_signal = false;
  }

double Strategy_RollingLogReturnSigma()
  {
   const int n = MathMax(2, MathMin(strategy_lookback_days, 60));
   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;

   for(int shift = 1; shift <= n; ++shift)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, shift);     // perf-allowed: D1 HV, N<=60, closed-bar gate
      const double c1 = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: D1 HV, N<=60, closed-bar gate
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;

      const double r = MathLog(c0 / c1);
      sum += r;
      sum_sq += r * r;
      samples++;
     }

   if(samples < 2)
      return 0.0;

   const double mean = sum / samples;
   const double variance = MathMax(0.0, (sum_sq / samples) - mean * mean);
   return MathSqrt(variance);
  }

void Strategy_AdvanceVwapState()
  {
   const datetime closed_bar_time = iTime(_Symbol, strategy_vwap_tf, 1); // perf-allowed: one closed M5 bar after QM_IsNewBar gate
   if(closed_bar_time <= 0)
      return;

   if(!Strategy_IsCashSession(closed_bar_time))
      return;

   const int date_key = Strategy_BrokerDateKey(closed_bar_time);
   if(g_session_yyyymmdd != date_key)
      Strategy_ResetSession(closed_bar_time);

   const double high = iHigh(_Symbol, strategy_vwap_tf, 1);     // perf-allowed: single closed bar for VWAP
   const double low = iLow(_Symbol, strategy_vwap_tf, 1);       // perf-allowed: single closed bar for VWAP
   const double close = iClose(_Symbol, strategy_vwap_tf, 1);   // perf-allowed: single closed bar for VWAP
   const double volume = (double)iVolume(_Symbol, strategy_vwap_tf, 1); // perf-allowed: single closed bar for VWAP
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || volume <= 0.0)
      return;

   if(g_session_open_price <= 0.0)
      g_session_open_price = close;

   g_prev_closed_vwap_close = g_last_closed_vwap_close;
   g_last_closed_vwap_close = close;
   g_prev_session_vwap = g_session_vwap;

   const double typical = (high + low + close) / 3.0;
   g_vwap_pv_sum += typical * volume;
   g_vwap_volume_sum += volume;
   if(g_vwap_volume_sum > 0.0)
      g_session_vwap = NormalizeDouble(g_vwap_pv_sum / g_vwap_volume_sum, _Digits);

   g_vwap_exit_signal = false;
   if(g_prev_closed_vwap_close > 0.0 && g_prev_session_vwap > 0.0 && g_session_vwap > 0.0)
     {
      const bool crossed_down = (g_prev_closed_vwap_close >= g_prev_session_vwap &&
                                 g_last_closed_vwap_close < g_session_vwap);
      const bool crossed_up = (g_prev_closed_vwap_close <= g_prev_session_vwap &&
                               g_last_closed_vwap_close > g_session_vwap);
      if(crossed_down || crossed_up)
         g_vwap_exit_signal = true;
     }
  }

void Strategy_AdvanceSessionRisk()
  {
   const datetime now = TimeCurrent();
   if(g_session_yyyymmdd != Strategy_BrokerDateKey(now))
      Strategy_ResetSession(now);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_session_high_equity <= 0.0 || equity > g_session_high_equity)
      g_session_high_equity = equity;

   if(g_session_high_equity > 0.0 && strategy_session_dd_cap_pct > 0.0)
     {
      const double dd_pct = 100.0 * (g_session_high_equity - equity) / g_session_high_equity;
      if(dd_pct >= strategy_session_dd_cap_pct)
         g_session_dd_blocked = true;
     }
  }

bool Strategy_BuildBoundaries()
  {
   g_upper_t = 0.0;
   g_lower_t = 0.0;
   if(g_session_open_price <= 0.0)
      return false;

   const double sigma_t = Strategy_RollingLogReturnSigma();
   if(sigma_t <= 0.0 || strategy_vol_k <= 0.0)
      return false;

   g_upper_t = NormalizeDouble(g_session_open_price * MathExp(strategy_vol_k * sigma_t), _Digits);
   g_lower_t = NormalizeDouble(g_session_open_price * MathExp(-strategy_vol_k * sigma_t), _Digits);
   return (g_upper_t > 0.0 && g_lower_t > 0.0 && g_upper_t > g_lower_t);
  }

double Strategy_AtrStop(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, strategy_boundary_tf, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return 0.0;

   const double distance = atr * strategy_atr_sl_mult;
   const double stop = QM_OrderTypeIsBuy(side) ? (entry - distance) : (entry + distance);
   return NormalizeDouble(stop, _Digits);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_AdvanceSessionRisk();

   if(QM_IsNewBar(_Symbol, strategy_vwap_tf))
      Strategy_AdvanceVwapState();

   const datetime broker_now = TimeCurrent();
   const bool has_position = Strategy_HasOpenPosition();
   if(!Strategy_IsCashSession(broker_now) && !has_position)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_max_spread_points > 0 && !has_position && ask > 0.0 && bid > 0.0 && point > 0.0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > strategy_max_spread_points)
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

   if(g_session_dd_blocked || Strategy_HasOpenPosition() || !Strategy_IsCashSession(TimeCurrent()))
      return false;
   if(!Strategy_BuildBoundaries())
      return false;

   const double close = iClose(_Symbol, strategy_boundary_tf, 1); // perf-allowed: one M30 closed-bar boundary check
   if(close <= 0.0)
      return false;

   QM_OrderType side;
   if(close > g_upper_t)
      side = QM_BUY;
   else if(close < g_lower_t)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = Strategy_AtrStop(side, entry);
   if(entry <= 0.0 || sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "MAROY_BOUNDARY_LONG" : "MAROY_BOUNDARY_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_exit_variant == EXIT_VWAP)
      return;

   const int magic = QM_FrameworkMagic();
   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found_position = true;
      if(g_ladder_scaled)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0 || volume <= 0.0)
         continue;

      const double move_pct = is_buy ? (100.0 * (market - open_price) / open_price)
                                     : (100.0 * (open_price - market) / open_price);
      const double target_pct = is_buy ? strategy_ladder_long_mfe_pct : strategy_ladder_short_mfe_pct;
      if(move_pct < target_pct)
         continue;

      const double close_pct = MathMax(0.0, MathMin(strategy_ladder_close_pct, 100.0));
      const double lots_to_close = volume * close_pct / 100.0;
      if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
         g_ladder_scaled = true;
     }

   if(!found_position)
      g_ladder_scaled = false;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found_position = true;
      if(Strategy_IsSessionEnd(TimeCurrent()))
         return true;

      if(strategy_exit_variant == EXIT_LADDER)
         continue;
      if(!g_vwap_exit_signal || g_session_vwap <= 0.0)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      if((is_buy && market < g_session_vwap) || (!is_buy && market > g_session_vwap))
         return true;
     }

   if(!found_position)
     {
      g_ladder_scaled = false;
      g_vwap_exit_signal = false;
     }

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
