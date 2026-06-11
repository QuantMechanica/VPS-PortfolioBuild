#property strict
#property version   "5.0"
#property description "QM5_9940 ForexFactory HA MA Fractal H1"

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
input int    qm_ea_id                   = 9940;
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
input int    strategy_ha_first_period   = 6;      // Heiken-Ashi Smoothed first pass period; method fixed to SMMA per card (2).
input int    strategy_ha_second_period  = 2;      // Heiken-Ashi Smoothed second pass period; method fixed to LWMA per card (3).
input int    strategy_lwma_period       = 24;     // LWMA on HL/2 trend gate and SL anchor.
input int    strategy_atr_period        = 14;     // ATR period for distance cap and non-JPY port.
input int    strategy_fractal_lookback  = 60;     // Latest confirmed 5-bar fractal search window.
input double strategy_jpy_price_offset  = 0.20;   // JPY-pair fixed price offset for TP/SL.
input double strategy_nonjpy_tp_atr     = 1.50;   // Non-JPY TP distance from entry.
input double strategy_nonjpy_sl_atr     = 0.80;   // Non-JPY SL offset from LWMA.
input double strategy_max_sl_atr        = 2.20;   // Skip entries whose entry-to-SL distance is too wide.

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_IsJPYPair()
  {
   return (StringFind(_Symbol, "JPY") >= 0);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_HASmoothed(const int shift, double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   if(shift < 1 || strategy_ha_first_period < 1 || strategy_ha_second_period < 1)
      return false;

   const int warmup = MathMax(12, strategy_ha_first_period * 3 + strategy_ha_second_period + 4);
   const int start_shift = shift + warmup;
   double prev_open = 0.0;
   double prev_close = 0.0;
   bool seeded = false;
   double weighted_open = 0.0;
   double weighted_close = 0.0;
   double weight_sum = 0.0;

   for(int s = start_shift; s >= shift; --s)
     {
      const double o = QM_SMMA(_Symbol, PERIOD_H1, strategy_ha_first_period, s, PRICE_OPEN);
      const double h = QM_SMMA(_Symbol, PERIOD_H1, strategy_ha_first_period, s, PRICE_HIGH);
      const double l = QM_SMMA(_Symbol, PERIOD_H1, strategy_ha_first_period, s, PRICE_LOW);
      const double c = QM_SMMA(_Symbol, PERIOD_H1, strategy_ha_first_period, s, PRICE_CLOSE);
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
         return false;

      const double raw_close = (o + h + l + c) / 4.0;
      const double raw_open = seeded ? ((prev_open + prev_close) / 2.0) : ((o + c) / 2.0);
      prev_open = raw_open;
      prev_close = raw_close;
      seeded = true;

      if(s >= shift && s < shift + strategy_ha_second_period)
        {
         const double weight = (double)(strategy_ha_second_period - (s - shift));
         weighted_open += raw_open * weight;
         weighted_close += raw_close * weight;
         weight_sum += weight;
        }
     }

   if(weight_sum <= 0.0)
      return false;
   ha_open = weighted_open / weight_sum;
   ha_close = weighted_close / weight_sum;
   return true;
  }

int Strategy_HAColor(const int shift)
  {
   double ha_open = 0.0;
   double ha_close = 0.0;
   if(!Strategy_HASmoothed(shift, ha_open, ha_close))
      return 0;
   if(ha_close > ha_open)
      return 1;
   if(ha_close < ha_open)
      return -1;
   return 0;
  }

bool Strategy_LatestUpperFractal(double &price)
  {
   price = 0.0;
   const int lookback = MathMax(5, strategy_fractal_lookback);
   for(int shift = 3; shift <= lookback; ++shift)
     {
      const double center = iHigh(_Symbol, PERIOD_H1, shift);     // perf-allowed: confirmed 5-bar fractal structural logic.
      const double r1 = iHigh(_Symbol, PERIOD_H1, shift - 1);     // perf-allowed: confirmed 5-bar fractal structural logic.
      const double r2 = iHigh(_Symbol, PERIOD_H1, shift - 2);     // perf-allowed: confirmed 5-bar fractal structural logic.
      const double l1 = iHigh(_Symbol, PERIOD_H1, shift + 1);     // perf-allowed: confirmed 5-bar fractal structural logic.
      const double l2 = iHigh(_Symbol, PERIOD_H1, shift + 2);     // perf-allowed: confirmed 5-bar fractal structural logic.
      if(center <= 0.0 || r1 <= 0.0 || r2 <= 0.0 || l1 <= 0.0 || l2 <= 0.0)
         continue;
      if(center > r1 && center > r2 && center > l1 && center > l2)
        {
         price = center;
         return true;
        }
     }
   return false;
  }

bool Strategy_LatestLowerFractal(double &price)
  {
   price = 0.0;
   const int lookback = MathMax(5, strategy_fractal_lookback);
   for(int shift = 3; shift <= lookback; ++shift)
     {
      const double center = iLow(_Symbol, PERIOD_H1, shift);      // perf-allowed: confirmed 5-bar fractal structural logic.
      const double r1 = iLow(_Symbol, PERIOD_H1, shift - 1);      // perf-allowed: confirmed 5-bar fractal structural logic.
      const double r2 = iLow(_Symbol, PERIOD_H1, shift - 2);      // perf-allowed: confirmed 5-bar fractal structural logic.
      const double l1 = iLow(_Symbol, PERIOD_H1, shift + 1);      // perf-allowed: confirmed 5-bar fractal structural logic.
      const double l2 = iLow(_Symbol, PERIOD_H1, shift + 2);      // perf-allowed: confirmed 5-bar fractal structural logic.
      if(center <= 0.0 || r1 <= 0.0 || r2 <= 0.0 || l1 <= 0.0 || l2 <= 0.0)
         continue;
      if(center < r1 && center < r2 && center < l1 && center < l2)
        {
         price = center;
         return true;
        }
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type)
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

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H1)
      return false;
   if(Strategy_HasOurPendingOrder())
      return false;

   const int c3 = Strategy_HAColor(3);
   const int c2 = Strategy_HAColor(2);
   const int c1 = Strategy_HAColor(1);
   if(c1 == 0 || c2 == 0 || c3 == 0)
      return false;

   const double prev_close = QM_SMA(_Symbol, PERIOD_H1, 1, 1, PRICE_CLOSE);
   const double lwma = QM_LWMA(_Symbol, PERIOD_H1, strategy_lwma_period, 1, PRICE_MEDIAN);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(prev_close <= 0.0 || lwma <= 0.0 || atr <= 0.0)
      return false;

   const bool is_jpy = Strategy_IsJPYPair();
   const double stop_offset = is_jpy ? strategy_jpy_price_offset : (strategy_nonjpy_sl_atr * atr);
   const double take_distance = is_jpy ? strategy_jpy_price_offset : (strategy_nonjpy_tp_atr * atr);
   if(stop_offset <= 0.0 || take_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(c3 < 0 && c2 > 0 && c1 > 0 && prev_close > lwma)
     {
      double upper = 0.0;
      if(!Strategy_LatestUpperFractal(upper) || upper <= ask)
         return false;

      const double sl = Strategy_NormalizePrice(lwma - stop_offset);
      const double tp = Strategy_NormalizePrice(upper + take_distance);
      if(sl <= 0.0 || tp <= 0.0 || sl >= upper || tp <= upper)
         return false;
      if(MathAbs(upper - sl) > strategy_max_sl_atr * atr)
         return false;

      req.type = QM_BUY_STOP;
      req.price = Strategy_NormalizePrice(upper);
      req.sl = sl;
      req.tp = tp;
      req.reason = "HA_MA_FRACTAL_BUY_STOP";
      return true;
     }

   if(c3 > 0 && c2 < 0 && c1 < 0 && prev_close < lwma)
     {
      double lower = 0.0;
      if(!Strategy_LatestLowerFractal(lower) || lower >= bid)
         return false;

      const double sl = Strategy_NormalizePrice(lwma + stop_offset);
      const double tp = Strategy_NormalizePrice(lower - take_distance);
      if(sl <= 0.0 || tp <= 0.0 || sl <= lower || tp >= lower)
         return false;
      if(MathAbs(sl - lower) > strategy_max_sl_atr * atr)
         return false;

      req.type = QM_SELL_STOP;
      req.price = Strategy_NormalizePrice(lower);
      req.sl = sl;
      req.tp = tp;
      req.reason = "HA_MA_FRACTAL_SELL_STOP";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int latest_color = Strategy_HAColor(1);
   if(latest_color == 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP && latest_color < 0)
         QM_TM_RemovePendingOrder(ticket, "ha_flip_before_buy_trigger");
      else if(type == ORDER_TYPE_SELL_STOP && latest_color > 0)
         QM_TM_RemovePendingOrder(ticket, "ha_flip_before_sell_trigger");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(position_type))
      return false;

   const int c1 = Strategy_HAColor(1);
   const int c2 = Strategy_HAColor(2);
   if(c1 == 0 || c2 == 0)
      return false;

   if(position_type == POSITION_TYPE_BUY && c1 < 0 && c2 < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && c1 > 0 && c2 > 0)
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
