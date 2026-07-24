#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 20096;
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
input int    strategy_sma_period        = 100;
input int    strategy_stoch_k           = 8;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_zone        = 50.0;
input int    strategy_pullback_min_bars = 2;
input double strategy_sl_pips           = 50.0;
input int    strategy_cross_window     = 3;    // stoch cross within last N closed bars (variant HASTOCH_097_XWIN3)

int      g_str097_h_sma              = INVALID_HANDLE;
int      g_str097_h_stoch            = INVALID_HANDLE;
datetime g_str097_last_data_log_bar  = 0;

bool Strategy097_EnsureHandles()
  {
   if(g_str097_h_sma == INVALID_HANDLE)
      g_str097_h_sma = QM_IndMA(_Symbol,
                                PERIOD_H4,
                                strategy_sma_period,
                                MODE_SMA,
                                PRICE_CLOSE);
   if(g_str097_h_stoch == INVALID_HANDLE)
      g_str097_h_stoch = QM_IndStoch(_Symbol,
                                    PERIOD_H4,
                                    strategy_stoch_k,
                                    strategy_stoch_d,
                                    strategy_stoch_slowing);
   return (g_str097_h_sma != INVALID_HANDLE &&
           g_str097_h_stoch != INVALID_HANDLE);
  }

void Strategy097_LogDataMissing(const string component)
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: O(1) log-dedupe key, reviewer-approved (cross-review 2026-07-24)
   if(bar_time > 0 && bar_time == g_str097_last_data_log_bar)
      return;
   g_str097_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-097\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

bool Strategy097_LoadHA(double &ha_open[],
                        double &ha_high[],
                        double &ha_low[],
                        double &ha_close[])
  {
   int bars_needed = 150;
   const int pattern_needed = strategy_pullback_min_bars + 3;
   if(pattern_needed > bars_needed)
      bars_needed = pattern_needed;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded closed-bar HA recursion, only on new-bar paths (cross-review 2026-07-24)
                                PERIOD_H4,
                                1,
                                bars_needed,
                                rates);
   if(copied < bars_needed)
      return false;

   if(ArrayResize(ha_open, copied) != copied ||
      ArrayResize(ha_high, copied) != copied ||
      ArrayResize(ha_low, copied) != copied ||
      ArrayResize(ha_close, copied) != copied)
      return false;
   ArraySetAsSeries(ha_open, true);
   ArraySetAsSeries(ha_high, true);
   ArraySetAsSeries(ha_low, true);
   ArraySetAsSeries(ha_close, true);

   double prior_ha_open = 0.0;
   double prior_ha_close = 0.0;
   for(int i = copied - 1; i >= 0; --i)
     {
      const double raw_open = rates[i].open;
      const double raw_high = rates[i].high;
      const double raw_low = rates[i].low;
      const double raw_close = rates[i].close;
      if(raw_open <= 0.0 ||
         raw_high <= 0.0 ||
         raw_low <= 0.0 ||
         raw_close <= 0.0 ||
         raw_high < raw_low)
         return false;

      const double next_ha_close =
         (raw_open + raw_high + raw_low + raw_close) * 0.25;
      const double next_ha_open =
         (i == copied - 1)
         ? (raw_open + raw_close) * 0.5
         : (prior_ha_open + prior_ha_close) * 0.5;

      ha_open[i] = next_ha_open;
      ha_close[i] = next_ha_close;
      ha_high[i] = MathMax(raw_high,
                           MathMax(next_ha_open, next_ha_close));
      ha_low[i] = MathMin(raw_low,
                          MathMin(next_ha_open, next_ha_close));
      prior_ha_open = next_ha_open;
      prior_ha_close = next_ha_close;
     }
   return true;
  }

int Strategy097_HAColor(const double &ha_open[],
                        const double &ha_close[],
                        const int closed_shift)
  {
   const int index = closed_shift - 1;
   if(index < 0 ||
      index >= ArraySize(ha_open) ||
      index >= ArraySize(ha_close))
      return 0;
   if(ha_close[index] > ha_open[index])
      return 1;
   if(ha_close[index] < ha_open[index])
      return -1;
   return 0;
  }

bool Strategy097_HasOwnPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy097_StopLegal(const ENUM_POSITION_TYPE position_type,
                           const double candidate)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      (stops_level > 0) ? (double)stops_level * point : point;
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid - candidate >= minimum);
     }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 && candidate - ask >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4 ||
      strategy_sma_period <= 1 ||
      strategy_stoch_k <= 0 ||
      strategy_stoch_d <= 0 ||
      strategy_stoch_slowing <= 0 ||
      strategy_stoch_zone <= 0.0 ||
      strategy_stoch_zone >= 100.0 ||
      strategy_pullback_min_bars < 1 ||
      strategy_sl_pips <= 0.0)
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;

   int bars_needed = 150;
   const int indicator_needed = strategy_sma_period + 5;
   if(indicator_needed > bars_needed)
      bars_needed = indicator_needed;
   if(Bars(_Symbol, PERIOD_H4) < bars_needed) // perf-allowed: O(1) warmup count, reviewer-approved (cross-review 2026-07-24)
      return true;
   if(!Strategy097_EnsureHandles())
      return true;
   if(BarsCalculated(g_str097_h_sma) < indicator_needed ||
      BarsCalculated(g_str097_h_stoch) <
         strategy_stoch_k + strategy_stoch_d +
         strategy_stoch_slowing + 5)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong existing_ticket = 0;
   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy097_HasOwnPosition(existing_ticket, existing_type))
      return false;
   if(!Strategy097_EnsureHandles())
     {
      Strategy097_LogDataMissing("indicator_handles");
      return false;
     }

   double ha_open[];
   double ha_high[];
   double ha_low[];
   double ha_close[];
   if(!Strategy097_LoadHA(ha_open, ha_high, ha_low, ha_close))
     {
      Strategy097_LogDataMissing("heiken_ashi_rates");
      return false;
     }

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H4, 1, signal_bar))
     {
      Strategy097_LogDataMissing("signal_bar");
      return false;
     }

   const double sma1 =
      QM_IndicatorReadBuffer(g_str097_h_sma, 0, 1);
   const double k1 =
      QM_IndicatorReadBuffer(g_str097_h_stoch, 0, 1);
   const double d1 =
      QM_IndicatorReadBuffer(g_str097_h_stoch, 1, 1);
   if(sma1 <= 0.0 || (k1 == 0.0 && d1 == 0.0))
     {
      Strategy097_LogDataMissing("indicator_buffers");
      return false;
     }

   // Variant HASTOCH_097_XWIN3 (reconciliation amendment 2026-07-24): the HA
   // flip lags the stochastic cross by design (HA is smoothed), so requiring
   // the cross on the flip bar itself produced an EMPTY strategy (0 trades,
   // GBPUSD H4 2024 smoke, zone-independent). Source prose couples flip and a
   // recent "smooth cross"; mechanized as: cross occurred within the last
   // strategy_cross_window closed bars, is still in force on the flip bar, and
   // the zone test applies at the cross bar.
   int  long_cross_bar = 0;
   int  short_cross_bar = 0;
   for(int c = 1; c <= strategy_cross_window && long_cross_bar == 0; ++c)
     {
      const double kc = QM_IndicatorReadBuffer(g_str097_h_stoch, 0, c);
      const double dc = QM_IndicatorReadBuffer(g_str097_h_stoch, 1, c);
      const double kp = QM_IndicatorReadBuffer(g_str097_h_stoch, 0, c + 1);
      const double dp = QM_IndicatorReadBuffer(g_str097_h_stoch, 1, c + 1);
      if(kc > dc && kp <= dp && dc < strategy_stoch_zone)
         long_cross_bar = c;
     }
   for(int c = 1; c <= strategy_cross_window && short_cross_bar == 0; ++c)
     {
      const double kc = QM_IndicatorReadBuffer(g_str097_h_stoch, 0, c);
      const double dc = QM_IndicatorReadBuffer(g_str097_h_stoch, 1, c);
      const double kp = QM_IndicatorReadBuffer(g_str097_h_stoch, 0, c + 1);
      const double dp = QM_IndicatorReadBuffer(g_str097_h_stoch, 1, c + 1);
      if(kc < dc && kp >= dp && dc > 100.0 - strategy_stoch_zone)
         short_cross_bar = c;
     }

   bool long_pullback = (Strategy097_HAColor(ha_open, ha_close, 1) == 1);
   bool short_pullback = (Strategy097_HAColor(ha_open, ha_close, 1) == -1);
   for(int shift = 2;
       shift <= strategy_pullback_min_bars + 1;
       ++shift)
     {
      if(Strategy097_HAColor(ha_open, ha_close, shift) != -1)
         long_pullback = false;
      if(Strategy097_HAColor(ha_open, ha_close, shift) != 1)
         short_pullback = false;
     }

   const bool long_signal =
      signal_bar.close > sma1 &&
      long_pullback &&
      long_cross_bar > 0 &&
      k1 > d1;
   const bool short_signal =
      signal_bar.close < sma1 &&
      short_pullback &&
      short_cross_bar > 0 &&
      k1 < d1;
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy097_LogDataMissing("market_price");
      return false;
     }

   const int sl_pips = (int)MathRound(strategy_sl_pips);
   req.price = entry;
   req.sl = QM_StopFixedPips(_Symbol,
                             req.type,
                             entry,
                             sl_pips);
   req.tp = 0.0;
   req.reason =
      long_signal
      ? "STR097_HA_STOCH_LONG"
      : "STR097_HA_STOCH_SHORT";
   if(req.sl <= 0.0 ||
      (long_signal && req.sl >= entry) ||
      (short_signal && req.sl <= entry))
     {
      QM_LogEvent(QM_WARN,
                  "SETUP_CONFIG_INVALID",
                  StringFormat("{\"strategy\":\"STR-097\",\"reason\":\"initial_sl\",\"entry\":%.8f,\"sl\":%.8f}",
                               entry,
                               req.sl));
      return false;
     }

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-097\",\"dir\":\"%s\",\"close\":%.8f,\"sma\":%.8f,\"k\":%.5f,\"d\":%.5f,\"ha_pattern\":\"flip_after_%d\",\"sl\":%.8f}",
         long_signal ? "LONG" : "SHORT",
         signal_bar.close,
         sma1,
         k1,
         d1,
         strategy_pullback_min_bars,
         req.sl));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy097_HasOwnPosition(ticket, position_type))
      return;

   // Safe use of the shared framework gate: this branch runs only while an
   // owned position exists, when the no-pyramiding entry path must be blocked.
   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;

   double ha_open[];
   double ha_high[];
   double ha_low[];
   double ha_close[];
   if(!Strategy097_LoadHA(ha_open, ha_high, ha_low, ha_close))
     {
      Strategy097_LogDataMissing("heiken_ashi_manage");
      return;
     }

   const int color1 = Strategy097_HAColor(ha_open, ha_close, 1);
   const bool flip_against =
      (position_type == POSITION_TYPE_BUY && color1 == -1) ||
      (position_type == POSITION_TYPE_SELL && color1 == 1);
   if(flip_against)
     {
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-097\",\"ticket\":%I64u,\"reason\":\"ha_flip\",\"ha_color\":%d}",
            ticket,
            color1));
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return;
     }

   if(ArraySize(ha_low) < 2 || ArraySize(ha_high) < 2)
     {
      Strategy097_LogDataMissing("ha_trail_anchor");
      return;
     }
   const double raw_candidate =
      (position_type == POSITION_TYPE_BUY) ? ha_low[1] : ha_high[1];
   const double candidate =
      QM_TM_NormalizePrice(_Symbol, raw_candidate);
   if(!PositionSelectByTicket(ticket) || candidate <= 0.0)
      return;
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool improves =
      (current_sl <= 0.0) ||
      (position_type == POSITION_TYPE_BUY
       ? candidate > current_sl + point * 0.5
       : candidate < current_sl - point * 0.5);
   if(!improves)
      return;

   if(!Strategy097_StopLegal(position_type, candidate))
     {
      QM_LogEvent(
         QM_INFO,
         "TM_MODIFY_SKIPPED",
         StringFormat(
            "{\"strategy\":\"STR-097\",\"ticket\":%I64u,\"reason\":\"ha_trail_stops_level\",\"candidate\":%.8f}",
            ticket,
            candidate));
      return;
     }
   QM_TM_MoveSL(ticket, candidate, "STR097_HA2_RATCHET");
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
