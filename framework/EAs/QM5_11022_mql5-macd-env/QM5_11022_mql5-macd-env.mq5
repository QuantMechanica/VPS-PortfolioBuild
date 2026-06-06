#property strict
#property version   "5.0"
#property description "QM5_11022 MQL5 MACD Envelopes Bounce"

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
input int    qm_ea_id                   = 11022;
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
input int    strategy_macd_fast_ema        = 15;
input int    strategy_macd_slow_ema        = 26;
input int    strategy_macd_signal_period   = 1;
input int    strategy_envelopes_period     = 22;
input double strategy_envelopes_deviation  = 0.3;
input int    strategy_sl_points            = 160;
input int    strategy_tp_points            = 310;
input int    strategy_trailing_points      = 50;
input int    strategy_max_spread_points    = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_ReadClosedH1Bar(MqlRates &bar)
  {
   MqlRates rates[1];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, rates) != 1) // perf-allowed: one closed H1 bar, called only from framework-gated signal paths.
      return false;
   bar = rates[0];
   return true;
  }

double Strategy_EnvelopeLower(const int shift)
  {
   const double middle = QM_SMA(_Symbol, PERIOD_H1, strategy_envelopes_period, shift, PRICE_CLOSE);
   if(middle <= 0.0)
      return 0.0;
   return middle * (1.0 - (strategy_envelopes_deviation / 100.0));
  }

double Strategy_EnvelopeUpper(const int shift)
  {
   const double middle = QM_SMA(_Symbol, PERIOD_H1, strategy_envelopes_period, shift, PRICE_CLOSE);
   if(middle <= 0.0)
      return 0.0;
   return middle * (1.0 + (strategy_envelopes_deviation / 100.0));
  }

int Strategy_OppositeSignal()
  {
   if(strategy_macd_fast_ema <= 0 ||
      strategy_macd_slow_ema <= strategy_macd_fast_ema ||
      strategy_macd_signal_period <= 0 ||
      strategy_envelopes_period <= 0 ||
      strategy_envelopes_deviation <= 0.0)
      return 0;

   MqlRates bar;
   if(!Strategy_ReadClosedH1Bar(bar))
      return 0;

   const double lower = Strategy_EnvelopeLower(1);
   const double upper = Strategy_EnvelopeUpper(1);
   if(lower <= 0.0 || upper <= 0.0 || bar.open <= 0.0 || bar.close <= 0.0)
      return 0;

   const double macd1 = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_macd_fast_ema, strategy_macd_slow_ema, strategy_macd_signal_period, 1, PRICE_CLOSE);
   const double macd2 = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_macd_fast_ema, strategy_macd_slow_ema, strategy_macd_signal_period, 2, PRICE_CLOSE);
   const double macd3 = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_macd_fast_ema, strategy_macd_slow_ema, strategy_macd_signal_period, 3, PRICE_CLOSE);
   if(macd1 == 0.0 || macd2 == 0.0 || macd3 == 0.0)
      return 0;

   const bool long_signal = (bar.open < lower && bar.close > lower && macd1 > macd2 && macd2 > macd3);
   if(long_signal)
      return 1;

   const bool short_signal = (bar.open > upper && bar.close < upper && macd1 < macd2 && macd2 < macd3);
   if(short_signal)
      return -1;

   return 0;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

double Strategy_PointsToDistance(const int points)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(points <= 0 || point <= 0.0)
      return 0.0;
   return points * point;
  }

bool Strategy_StopDistanceAllowed()
  {
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level <= 0)
      return true;
   return (strategy_sl_points >= stops_level && strategy_tp_points >= stops_level);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_StopDistanceAllowed())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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

   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(Strategy_HasOpenPosition(pos_type))
      return false;

   const int signal = Strategy_OppositeSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   const double sl_distance = Strategy_PointsToDistance(strategy_sl_points);
   const double tp_distance = Strategy_PointsToDistance(strategy_tp_points);
   if(entry <= 0.0 || sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, (signal > 0) ? (entry - sl_distance) : (entry + sl_distance));
   req.tp = QM_StopRulesNormalizePrice(_Symbol, (signal > 0) ? (entry + tp_distance) : (entry - tp_distance));
   req.reason = (signal > 0) ? "MQL5_MACD_ENV_LONG" : "MQL5_MACD_ENV_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_points <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double trail_distance = Strategy_PointsToDistance(strategy_trailing_points);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(trail_distance <= 0.0 || open_price <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, bid - trail_distance);
         if(bid - open_price >= trail_distance && (current_sl <= 0.0 || new_sl > current_sl))
            QM_TM_MoveSL(ticket, new_sl, "MQL5_MACD_ENV_POINT_TRAIL");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, ask + trail_distance);
         if(open_price - ask >= trail_distance && (current_sl <= 0.0 || new_sl < current_sl))
            QM_TM_MoveSL(ticket, new_sl, "MQL5_MACD_ENV_POINT_TRAIL");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(!Strategy_HasOpenPosition(pos_type))
      return false;

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
      return false;

   const int signal = Strategy_OppositeSignal();
   if(pos_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && signal > 0)
      return true;

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
