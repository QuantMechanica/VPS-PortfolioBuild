#property strict
#property version   "5.0"
#property description "QM5_10722 TradingView SMC BTC OB FVG"

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
input int    qm_ea_id                   = 10722;
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
input int    strategy_swing_length        = 10;
input int    strategy_structure_memory    = 5;
input int    strategy_ob_lookback         = 15;
input int    strategy_sweep_memory        = 20;
input double strategy_pd_threshold        = 0.80;
input double strategy_sl_buffer_pct       = 0.003;
input int    strategy_atr_period          = 14;
input double strategy_min_stop_atr        = 0.50;
input double strategy_max_stop_atr        = 5.00;
input double strategy_reward_risk         = 2.00;
input int    strategy_h1_scan_bars        = 90;
input int    strategy_h4_scan_bars        = 90;
input int    strategy_trade_start_hour    = 0;
input int    strategy_trade_end_hour      = 24;
input int    strategy_max_spread_points   = 0;

// -----------------------------------------------------------------------------
// Bounded SMC structure helpers.
// EntrySignal is called only after the framework QM_IsNewBar() gate. The raw
// OHLC access below is a documented perf exception for order-block, FVG, swing,
// and liquidity-sweep structure that has no framework indicator equivalent.
// -----------------------------------------------------------------------------

int CopyStrategyRates(const ENUM_TIMEFRAMES tf, const int requested, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int count = MathMax(requested, 30);
   const int copied = CopyRates(_Symbol, tf, 0, count, rates); // perf-allowed: bounded SMC structural OHLC scan inside closed-bar EntrySignal.
   ArraySetAsSeries(rates, true);
   return copied;
  }

bool ValidRate(const MqlRates &bar)
  {
   return (bar.open > 0.0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0 &&
           bar.high >= bar.low);
  }

bool IsSwingHigh(MqlRates &rates[], const int shift, const int len, const int total)
  {
   if(shift < len + 1 || shift + len >= total || !ValidRate(rates[shift]))
      return false;
   const double value = rates[shift].high;
   for(int k = 1; k <= len; ++k)
     {
      if(rates[shift - k].high >= value || rates[shift + k].high >= value)
         return false;
     }
   return true;
  }

bool IsSwingLow(MqlRates &rates[], const int shift, const int len, const int total)
  {
   if(shift < len + 1 || shift + len >= total || !ValidRate(rates[shift]))
      return false;
   const double value = rates[shift].low;
   for(int k = 1; k <= len; ++k)
     {
      if(rates[shift - k].low <= value || rates[shift + k].low <= value)
         return false;
     }
   return true;
  }

bool FindRecentSwing(MqlRates &rates[], const int total, const int len,
                     const bool want_high, double &price, int &shift)
  {
   price = 0.0;
   shift = -1;
   for(int i = len + 1; i < total - len; ++i)
     {
      const bool ok = want_high ? IsSwingHigh(rates, i, len, total)
                                : IsSwingLow(rates, i, len, total);
      if(ok)
        {
         price = want_high ? rates[i].high : rates[i].low;
         shift = i;
         return true;
        }
     }
   return false;
  }

bool FindPriorSwing(MqlRates &rates[], const int total, const int len,
                    const int newer_shift, const bool want_high, double &price)
  {
   price = 0.0;
   const int first = MathMax(newer_shift + 1, len + 1);
   for(int i = first; i < total - len; ++i)
     {
      const bool ok = want_high ? IsSwingHigh(rates, i, len, total)
                                : IsSwingLow(rates, i, len, total);
      if(ok)
        {
         price = want_high ? rates[i].high : rates[i].low;
         return true;
        }
     }
   return false;
  }

bool RecentStructureBreak(MqlRates &rates[], const int total, const int len,
                          const int memory, const int direction)
  {
   const int max_shift = MathMin(memory, total - len - 2);
   for(int j = 1; j <= max_shift; ++j)
     {
      double swing_price = 0.0;
      if(direction > 0)
        {
         if(FindPriorSwing(rates, total, len, j, true, swing_price) &&
            rates[j].close > swing_price)
            return true;
        }
      else
        {
         if(FindPriorSwing(rates, total, len, j, false, swing_price) &&
            rates[j].close < swing_price)
            return true;
        }
     }
   return false;
  }

bool FindOrderBlock(MqlRates &rates[], const int total, const int lookback,
                    const int direction, double &ob_low, double &ob_high)
  {
   ob_low = 0.0;
   ob_high = 0.0;
   const int max_shift = MathMin(lookback + 1, total - 3);
   for(int i = 2; i <= max_shift; ++i)
     {
      if(!ValidRate(rates[i]))
         continue;
      if(direction > 0 && rates[i].close < rates[i].open)
        {
         ob_low = rates[i].low;
         ob_high = rates[i].high;
         return true;
        }
      if(direction < 0 && rates[i].close > rates[i].open)
        {
         ob_low = rates[i].low;
         ob_high = rates[i].high;
         return true;
        }
     }
   return false;
  }

bool RangesOverlap(const double a_low, const double a_high,
                   const double b_low, const double b_high)
  {
   return (MathMax(a_low, b_low) <= MathMin(a_high, b_high));
  }

bool HasFvgOverlap(MqlRates &rates[], const int total, const int lookback,
                   const int direction, const double ob_low, const double ob_high)
  {
   const int max_shift = MathMin(lookback + 1, total - 3);
   for(int i = 1; i <= max_shift; ++i)
     {
      if(!ValidRate(rates[i]) || !ValidRate(rates[i + 2]))
         continue;
      if(direction > 0 && rates[i].low > rates[i + 2].high)
        {
         if(RangesOverlap(rates[i + 2].high, rates[i].low, ob_low, ob_high))
            return true;
        }
      if(direction < 0 && rates[i].high < rates[i + 2].low)
        {
         if(RangesOverlap(rates[i].high, rates[i + 2].low, ob_low, ob_high))
            return true;
        }
     }
   return false;
  }

bool HasLiquiditySweep(MqlRates &rates[], const int total, const int len,
                       const int memory, const int direction)
  {
   const int max_shift = MathMin(memory, total - len - 2);
   for(int j = 1; j <= max_shift; ++j)
     {
      double swing_price = 0.0;
      if(direction > 0)
        {
         if(FindPriorSwing(rates, total, len, j, false, swing_price) &&
            rates[j].low < swing_price && rates[j].close > swing_price)
            return true;
        }
      else
        {
         if(FindPriorSwing(rates, total, len, j, true, swing_price) &&
            rates[j].high > swing_price && rates[j].close < swing_price)
            return true;
        }
     }
   return false;
  }

bool InDealingRangeZone(MqlRates &h4[], const int total, const int len,
                        const int direction, const double entry_price)
  {
   double swing_high = 0.0;
   double swing_low = 0.0;
   int high_shift = -1;
   int low_shift = -1;
   if(!FindRecentSwing(h4, total, len, true, swing_high, high_shift))
      return false;
   if(!FindRecentSwing(h4, total, len, false, swing_low, low_shift))
      return false;
   if(swing_high <= swing_low)
      return false;

   const double range = swing_high - swing_low;
   const double clamped = MathMax(0.0, MathMin(strategy_pd_threshold, 1.0));
   const double long_ceiling = swing_low + range * clamped;
   const double short_floor = swing_high - range * clamped;
   if(direction > 0)
      return (entry_price <= long_ceiling);
   return (entry_price >= short_floor);
  }

bool SessionAllowsTrade()
  {
   if(strategy_trade_start_hour <= 0 && strategy_trade_end_hour >= 24)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_h = MathMax(0, MathMin(strategy_trade_start_hour, 23));
   const int end_h = MathMax(0, MathMin(strategy_trade_end_hour, 24));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool SpreadAllowsTrade()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread >= 0 && spread <= strategy_max_spread_points);
  }

double NormalizeStrategyPrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!SessionAllowsTrade())
      return true;
   if(!SpreadAllowsTrade())
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

   const int swing_len = MathMax(2, strategy_swing_length);
   const int h1_count = MathMax(strategy_h1_scan_bars, swing_len * 4 + strategy_sweep_memory + 10);
   const int h4_count = MathMax(strategy_h4_scan_bars, swing_len * 4 + strategy_structure_memory + 10);

   MqlRates h1[];
   MqlRates h4[];
   const int h1_total = CopyStrategyRates(PERIOD_H1, h1_count, h1);
   const int h4_total = CopyStrategyRates(PERIOD_H4, h4_count, h4);
   if(h1_total < h1_count / 2 || h4_total < h4_count / 2)
      return false;

   const bool h4_bull = RecentStructureBreak(h4, h4_total, swing_len, strategy_structure_memory, 1);
   const bool h4_bear = RecentStructureBreak(h4, h4_total, swing_len, strategy_structure_memory, -1);
   const bool h1_bull = RecentStructureBreak(h1, h1_total, swing_len, strategy_structure_memory, 1);
   const bool h1_bear = RecentStructureBreak(h1, h1_total, swing_len, strategy_structure_memory, -1);

   int direction = 0;
   if(h4_bull && h1_bull)
      direction = 1;
   else if(h4_bear && h1_bear)
      direction = -1;
   else
      return false;

   double ob_low = 0.0;
   double ob_high = 0.0;
   if(!FindOrderBlock(h1, h1_total, strategy_ob_lookback, direction, ob_low, ob_high))
      return false;
   if(!HasFvgOverlap(h1, h1_total, strategy_ob_lookback, direction, ob_low, ob_high))
      return false;
   if(!HasLiquiditySweep(h1, h1_total, swing_len, strategy_sweep_memory, direction))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (direction > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;
   if(!InDealingRangeZone(h4, h4_total, swing_len, direction, entry))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double buffer = entry * strategy_sl_buffer_pct;
   const double sl = (direction > 0) ? (ob_low - buffer) : (ob_high + buffer);
   const double stop_dist = MathAbs(entry - sl);
   if(stop_dist < strategy_min_stop_atr * atr || stop_dist > strategy_max_stop_atr * atr)
      return false;

   if(direction > 0 && sl >= entry)
      return false;
   if(direction < 0 && sl <= entry)
      return false;

   const double tp = (direction > 0) ? (entry + strategy_reward_risk * stop_dist)
                                     : (entry - strategy_reward_risk * stop_dist);

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeStrategyPrice(sl);
   req.tp = NormalizeStrategyPrice(tp);
   req.reason = (direction > 0) ? "SMC_LONG_OB_FVG_SWEEP" : "SMC_SHORT_OB_FVG_SWEEP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   if(QM_LotsForRisk(_Symbol, stop_dist / SymbolInfoDouble(_Symbol, SYMBOL_POINT)) <= 0.0)
      return false;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed 2R take-profit and structure stop only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits via SL/TP plus framework Friday close.
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
