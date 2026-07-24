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
input int    qm_ea_id                   = 20097;
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
input int    strategy_sma_w1          = 55;
input int    strategy_sma_d1          = 21;
input int    strategy_sma_h4          = 34;
input int    strategy_atr_period      = 14;
input int    strategy_atr_lookback    = 30;
input double strategy_atr_offset_fact = 0.25;
input double strategy_max_sl_pips     = 100.0;

int      g_str103_h_sma_w1            = INVALID_HANDLE;
int      g_str103_h_sma_d1            = INVALID_HANDLE;
int      g_str103_h_sma_h4            = INVALID_HANDLE;
int      g_str103_h_atr               = INVALID_HANDLE;
datetime g_str103_offset_bar_time     = 0;
double   g_str103_offset_price        = 0.0;
double   g_str103_offset_pips         = 0.0;
bool     g_str103_offset_ready        = false;
datetime g_str103_last_data_log_bar   = 0;

bool Strategy103_EnsureHandles()
  {
   if(g_str103_h_sma_w1 == INVALID_HANDLE)
      g_str103_h_sma_w1 = QM_IndMA(_Symbol,
                                   PERIOD_W1,
                                   strategy_sma_w1,
                                   MODE_SMA,
                                   PRICE_CLOSE);
   if(g_str103_h_sma_d1 == INVALID_HANDLE)
      g_str103_h_sma_d1 = QM_IndMA(_Symbol,
                                   PERIOD_D1,
                                   strategy_sma_d1,
                                   MODE_SMA,
                                   PRICE_CLOSE);
   if(g_str103_h_sma_h4 == INVALID_HANDLE)
      g_str103_h_sma_h4 = QM_IndMA(_Symbol,
                                   PERIOD_H4,
                                   strategy_sma_h4,
                                   MODE_SMA,
                                   PRICE_CLOSE);
   if(g_str103_h_atr == INVALID_HANDLE)
      g_str103_h_atr = QM_IndATR(_Symbol,
                                 PERIOD_H4,
                                 strategy_atr_period);
   return (g_str103_h_sma_w1 != INVALID_HANDLE &&
           g_str103_h_sma_d1 != INVALID_HANDLE &&
           g_str103_h_sma_h4 != INVALID_HANDLE &&
           g_str103_h_atr != INVALID_HANDLE);
  }

void Strategy103_LogDataMissing(const string component)
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: O(1) log-dedupe key, reviewer-approved (cross-review 2026-07-24)
   if(bar_time > 0 && bar_time == g_str103_last_data_log_bar)
      return;
   g_str103_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-103\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

bool Strategy103_Offset(double &offset_price,
                        double &offset_pips)
  {
   offset_price = 0.0;
   offset_pips = 0.0;
   if(!Strategy103_EnsureHandles() ||
      strategy_atr_lookback <= 0 ||
      strategy_atr_offset_fact <= 0.0)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1); // perf-allowed: O(1) cache key for per-bar offset, reviewer-approved (cross-review 2026-07-24)
   if(closed_bar <= 0)
      return false;
   if(g_str103_offset_ready &&
      closed_bar == g_str103_offset_bar_time)
     {
      offset_price = g_str103_offset_price;
      offset_pips = g_str103_offset_pips;
      return true;
     }

   double highest = 0.0;
   double lowest = 0.0;
   for(int shift = 1; shift <= strategy_atr_lookback; ++shift)
     {
      const double value =
         QM_IndicatorReadBuffer(g_str103_h_atr, 0, shift);
      if(value <= 0.0)
        {
         g_str103_offset_ready = false;
         return false;
        }
      if(highest <= 0.0 || value > highest)
         highest = value;
      if(lowest <= 0.0 || value < lowest)
         lowest = value;
     }

   const double calculated =
      strategy_atr_offset_fact * (highest + lowest);
   const double one_pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(calculated <= 0.0 || one_pip <= 0.0)
     {
      g_str103_offset_ready = false;
      return false;
     }

   g_str103_offset_bar_time = closed_bar;
   g_str103_offset_price = calculated;
   g_str103_offset_pips = calculated / one_pip;
   g_str103_offset_ready = true;
   offset_price = g_str103_offset_price;
   offset_pips = g_str103_offset_pips;
   return true;
  }

bool Strategy103_HasOwnPosition(ulong &ticket,
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

bool Strategy103_HasOwnPending()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool Strategy103_ClampInitialStop(const QM_OrderType side,
                                  const double entry,
                                  const double cap_distance,
                                  double &stop,
                                  bool &stops_clamped)
  {
   stops_clamped = false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || stop <= 0.0 ||
      cap_distance <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      (stops_level > 0) ? (double)stops_level * point : point;
   const bool is_buy = QM_OrderTypeIsBuy(side);
   const double market_reference =
      is_buy
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_reference <= 0.0)
      return false;

   const double live_distance =
      is_buy ? market_reference - stop : stop - market_reference;
   if(live_distance < minimum)
     {
      const double adjusted =
         is_buy
         ? market_reference - minimum
         : market_reference + minimum;
      const double adjusted_risk = MathAbs(entry - adjusted);
      if(adjusted_risk > cap_distance + point * 0.5)
         return false;
      stop = adjusted;
      stops_clamped = true;
     }

   stop = QM_TM_NormalizePrice(_Symbol, stop);
   if(stop <= 0.0)
      return false;
   if(is_buy)
      return (stop < market_reference &&
              entry - stop <= cap_distance + point * 0.5);
   return (stop > market_reference &&
           stop - entry <= cap_distance + point * 0.5);
  }

bool Strategy103_TrailStopLegal(const ENUM_POSITION_TYPE position_type,
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
      strategy_sma_w1 <= 1 ||
      strategy_sma_d1 <= 1 ||
      strategy_sma_h4 <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_atr_lookback <= 1 ||
      strategy_atr_offset_fact <= 0.0 ||
      strategy_max_sl_pips <= 0.0)
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;

   int h4_needed = strategy_sma_h4;
   const int atr_needed =
      strategy_atr_lookback + strategy_atr_period;
   if(atr_needed > h4_needed)
      h4_needed = atr_needed;
   h4_needed += 5;
   if(Bars(_Symbol, PERIOD_W1) < 60 || // perf-allowed: O(1) warmup counts, reviewer-approved (cross-review 2026-07-24)
      Bars(_Symbol, PERIOD_D1) < 30 || // perf-allowed: O(1) warmup count, reviewer-approved (cross-review 2026-07-24)
      Bars(_Symbol, PERIOD_H4) < h4_needed) // perf-allowed: O(1) warmup count, reviewer-approved (cross-review 2026-07-24)
      return true;
   if(!Strategy103_EnsureHandles())
      return true;
   if(BarsCalculated(g_str103_h_sma_w1) < 60 ||
      BarsCalculated(g_str103_h_sma_d1) < 30 ||
      BarsCalculated(g_str103_h_sma_h4) <
         strategy_sma_h4 + 5 ||
      BarsCalculated(g_str103_h_atr) < atr_needed)
      return true;

   double offset_price = 0.0;
   double offset_pips = 0.0;
   if(!Strategy103_Offset(offset_price, offset_pips))
      return true;
   return (offset_price <= 0.0 || offset_pips <= 0.0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong existing_ticket = 0;
   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy103_HasOwnPosition(existing_ticket, existing_type) ||
      Strategy103_HasOwnPending())
      return false;
   if(!Strategy103_EnsureHandles())
     {
      Strategy103_LogDataMissing("indicator_handles");
      return false;
     }

   MqlRates h4_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H4, 1, h4_bar))
     {
      Strategy103_LogDataMissing("h4_signal_bar");
      return false;
     }
   const double sma_w1 =
      QM_IndicatorReadBuffer(g_str103_h_sma_w1, 0, 1);
   const double sma_d1 =
      QM_IndicatorReadBuffer(g_str103_h_sma_d1, 0, 1);
   const double sma_h4 =
      QM_IndicatorReadBuffer(g_str103_h_sma_h4, 0, 1);
   if(sma_w1 <= 0.0 || sma_d1 <= 0.0 || sma_h4 <= 0.0)
     {
      Strategy103_LogDataMissing("sma_buffers");
      return false;
     }

   const bool long_signal =
      h4_bar.close > sma_w1 &&
      h4_bar.close > sma_d1 &&
      h4_bar.low <= sma_h4 &&
      h4_bar.close > sma_h4;
   const bool short_signal =
      h4_bar.close < sma_w1 &&
      h4_bar.close < sma_d1 &&
      h4_bar.high >= sma_h4 &&
      h4_bar.close < sma_h4;
   if(!long_signal && !short_signal)
      return false;

   double offset_price = 0.0;
   double offset_pips = 0.0;
   if(!Strategy103_Offset(offset_price, offset_pips))
     {
      Strategy103_LogDataMissing("atr_offset");
      return false;
     }

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy103_LogDataMissing("market_price");
      return false;
     }

   double stop =
      long_signal
      ? sma_h4 - offset_price
      : sma_h4 + offset_price;
   const int cap_pips = (int)MathRound(strategy_max_sl_pips);
   const double cap_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, cap_pips);
   if(cap_distance <= 0.0)
     {
      QM_LogEvent(QM_WARN,
                  "SETUP_CONFIG_INVALID",
                  "{\"strategy\":\"STR-103\",\"reason\":\"max_sl_pips\"}");
      return false;
     }

   bool risk_capped = false;
   if(long_signal && entry - stop > cap_distance)
     {
      stop = entry - cap_distance;
      risk_capped = true;
     }
   else if(short_signal && stop - entry > cap_distance)
     {
      stop = entry + cap_distance;
      risk_capped = true;
     }

   bool stops_clamped = false;
   if(!Strategy103_ClampInitialStop(req.type,
                                    entry,
                                    cap_distance,
                                    stop,
                                    stops_clamped))
     {
      QM_LogEvent(
         QM_WARN,
         "VS_SL_UPDATE_FAIL",
         StringFormat(
            "{\"strategy\":\"STR-103\",\"reason\":\"initial_stops_level\",\"entry\":%.8f,\"candidate\":%.8f,\"cap_pips\":%.3f}",
            entry,
            stop,
            strategy_max_sl_pips));
      return false;
     }

   req.price = entry;
   req.sl = stop;
   req.tp = 0.0;
   req.reason =
      long_signal
      ? "STR103_TLP_LONG"
      : "STR103_TLP_SHORT";
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-103\",\"dir\":\"%s\",\"close\":%.8f,\"sma_w1\":%.8f,\"sma_d1\":%.8f,\"sma_h4\":%.8f,\"offset_pips\":%.5f,\"sl\":%.8f,\"capped\":%s,\"stops_clamped\":%s}",
         long_signal ? "LONG" : "SHORT",
         h4_bar.close,
         sma_w1,
         sma_d1,
         sma_h4,
         offset_pips,
         req.sl,
         risk_capped ? "true" : "false",
         stops_clamped ? "true" : "false"));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy103_HasOwnPosition(ticket, position_type))
      return;

   // Safe shared-gate use: only an already-open, no-pyramiding position can
   // consume this H4 edge; the entry path is intentionally dormant then.
   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return;
   if(!Strategy103_EnsureHandles())
     {
      Strategy103_LogDataMissing("manage_handles");
      return;
     }

   const double sma_h4 =
      QM_IndicatorReadBuffer(g_str103_h_sma_h4, 0, 1);
   double offset_price = 0.0;
   double offset_pips = 0.0;
   if(sma_h4 <= 0.0 ||
      !Strategy103_Offset(offset_price, offset_pips))
     {
      Strategy103_LogDataMissing("manage_offset");
      return;
     }

   const double raw_candidate =
      (position_type == POSITION_TYPE_BUY)
      ? sma_h4 - offset_price
      : sma_h4 + offset_price;
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

   if(!Strategy103_TrailStopLegal(position_type, candidate))
     {
      QM_LogEvent(
         QM_INFO,
         "TM_MODIFY_SKIPPED",
         StringFormat(
            "{\"strategy\":\"STR-103\",\"ticket\":%I64u,\"reason\":\"atr_sma_trail_stops_level\",\"candidate\":%.8f}",
            ticket,
            candidate));
      return;
     }
   QM_TM_MoveSL(ticket,
                candidate,
                "STR103_SMA34_ATR_OFFSET_RATCHET");
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
