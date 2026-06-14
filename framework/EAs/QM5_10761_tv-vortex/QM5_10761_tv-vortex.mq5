#property strict
#property version   "5.0"
#property description "QM5_10761 TradingView Vortex Confluence Protocol"

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
input int    qm_ea_id                   = 10761;
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
input bool   strategy_enable_longs      = true;
input bool   strategy_enable_shorts     = true;
input int    strategy_min_score         = 3;
input int    strategy_pivot_strength    = 5;
input bool   strategy_require_bos       = true;
input bool   strategy_require_fvg       = false;
input int    strategy_rsi_period        = 14;
input int    strategy_volume_ma_period  = 20;
input double strategy_volume_threshold  = 1.0;
input bool   strategy_adx_filter_enabled = true;
input int    strategy_adx_period        = 14;
input double strategy_adx_min           = 20.0;
input ENUM_TIMEFRAMES strategy_mtf_timeframe = PERIOD_H4;
input int    strategy_mtf_trend_length  = 50;
input bool   strategy_session_enabled   = true;
input int    strategy_session_start_hour = 0;
input int    strategy_session_end_hour  = 24;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_structure_atr_buffer = 0.2;
input double strategy_rr_target         = 2.0;
input int    strategy_swing_lookback    = 20;
input bool   strategy_trailing_enabled  = false;
input double strategy_trailing_atr_mult = 1.5;
input int    strategy_max_spread_points = 0;

// -----------------------------------------------------------------------------
// Strategy helpers — structural layers use one bounded CopyRates call on the
// framework new-bar cadence only. This is the documented perf-allowed exception
// for BOS / sweep / FVG / tick-volume logic that has no QM_* reader.
// -----------------------------------------------------------------------------

bool LoadClosedRates(MqlRates &rates[], const int needed)
  {
   if(needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, needed, rates); // perf-allowed: bounded structural BOS/FVG/volume read after framework new-bar gate
   return (copied >= needed);
  }

double HighestRateHigh(const MqlRates &rates[], const int start, const int count)
  {
   double highest = -DBL_MAX;
   for(int i = start; i < start + count; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double LowestRateLow(const MqlRates &rates[], const int start, const int count)
  {
   double lowest = DBL_MAX;
   for(int i = start; i < start + count; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

bool SessionAllowsTrade()
  {
   if(!strategy_session_enabled)
      return true;

   int start_h = strategy_session_start_hour;
   int end_h = strategy_session_end_hour;
   if(start_h < 0)
      start_h = 0;
   if(start_h > 23)
      start_h = 23;
   if(end_h < 0)
      end_h = 0;
   if(end_h > 24)
      end_h = 24;

   if(start_h == 0 && end_h == 24)
      return true;
   if(start_h == end_h)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

int StructureDirection(const MqlRates &rates[])
  {
   const int p = MathMax(2, strategy_pivot_strength);
   const double prior_high = HighestRateHigh(rates, 1, p);
   const double prior_low = LowestRateLow(rates, 1, p);

   if(rates[0].close > prior_high)
      return 1;
   if(rates[0].close < prior_low)
      return -1;
   if(rates[0].close > rates[p].close)
      return 1;
   if(rates[0].close < rates[p].close)
      return -1;
   return 0;
  }

int BosDirection(const MqlRates &rates[])
  {
   const int p = MathMax(2, strategy_pivot_strength);
   const double prior_high = HighestRateHigh(rates, 1, p);
   const double prior_low = LowestRateLow(rates, 1, p);

   if(rates[0].close > prior_high)
      return 1;
   if(rates[0].close < prior_low)
      return -1;
   return 0;
  }

int MomentumDirection()
  {
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return 0;
   if(rsi > 50.0)
      return 1;
   if(rsi < 50.0)
      return -1;
   return 0;
  }

int MtfTrendDirection()
  {
   if(strategy_mtf_trend_length <= 1)
      return 0;
   return QM_Sig_Price_Above_MA(_Symbol,
                                strategy_mtf_timeframe,
                                strategy_mtf_trend_length,
                                0.0,
                                1);
  }

bool VolumeConfirms(const MqlRates &rates[])
  {
   const int n = MathMax(2, strategy_volume_ma_period);
   double sum = 0.0;
   for(int i = 1; i <= n; ++i)
      sum += (double)rates[i].tick_volume;

   const double avg = sum / (double)n;
   if(avg <= 0.0)
      return false;
   return ((double)rates[0].tick_volume >= avg * strategy_volume_threshold);
  }

int LiquiditySweepDirection(const MqlRates &rates[])
  {
   const int p = MathMax(2, strategy_pivot_strength);
   const double prior_high = HighestRateHigh(rates, 1, p);
   const double prior_low = LowestRateLow(rates, 1, p);

   if(rates[0].low < prior_low && rates[0].close > prior_low)
      return 1;
   if(rates[0].high > prior_high && rates[0].close < prior_high)
      return -1;
   return 0;
  }

int SmartMoneyDirection(const MqlRates &rates[])
  {
   const double range = rates[0].high - rates[0].low;
   if(range <= 0.0)
      return 0;

   const double close_pos = (rates[0].close - rates[0].low) / range;
   const bool volume_ok = VolumeConfirms(rates);
   if(volume_ok && close_pos >= 0.65)
      return 1;
   if(volume_ok && close_pos <= 0.35)
      return -1;
   return 0;
  }

int FvgDirection(const MqlRates &rates[])
  {
   if(rates[0].low > rates[2].high)
      return 1;
   if(rates[0].high < rates[2].low)
      return -1;
   return 0;
  }

bool RegimeAllowsTrade()
  {
   if(!strategy_adx_filter_enabled)
      return true;
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   return (adx >= strategy_adx_min);
  }

int ConfluenceScore(const int side,
                    const int structure_dir,
                    const int momentum_dir,
                    const int mtf_dir,
                    const bool volume_ok,
                    const int sweep_dir,
                    const int smart_dir,
                    const int fvg_dir)
  {
   int score = 0;
   if(structure_dir == side)
      ++score;
   if(momentum_dir == side)
      ++score;
   if(mtf_dir == side)
      ++score;
   if(volume_ok)
      ++score;
   if(sweep_dir == side)
      ++score;
   if(smart_dir == side)
      ++score;
   if(fvg_dir == side)
      ++score;
   if(RegimeAllowsTrade())
      ++score;
   return score;
  }

double ConservativeStop(const QM_OrderType side,
                        const double entry,
                        const MqlRates &rates[],
                        const double atr)
  {
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;

   const int lookback = MathMax(2, strategy_swing_lookback);
   const double atr_stop = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(atr_stop <= 0.0)
      return 0.0;

   const double swing_low = LowestRateLow(rates, 1, lookback);
   const double swing_high = HighestRateHigh(rates, 1, lookback);
   double structure_stop = 0.0;
   if(QM_OrderTypeIsBuy(side))
      structure_stop = swing_low - atr * strategy_structure_atr_buffer;
   else
      structure_stop = swing_high + atr * strategy_structure_atr_buffer;

   structure_stop = QM_StopRulesNormalizePrice(_Symbol, structure_stop);
   if(structure_stop <= 0.0)
      return atr_stop;

   if(QM_OrderTypeIsBuy(side))
      return MathMax(atr_stop, structure_stop);
   return MathMin(atr_stop, structure_stop);
  }

bool HasBearishConflict(const int side,
                        const int momentum_dir,
                        const int mtf_dir,
                        const int smart_dir)
  {
   const int opposite = -side;
   return (momentum_dir == opposite || mtf_dir == opposite || smart_dir == opposite);
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

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
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

   if(strategy_min_score < 1 ||
      strategy_pivot_strength < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0)
      return false;

   const int needed = MathMax(strategy_swing_lookback + 2,
                              MathMax(strategy_volume_ma_period + 2,
                                      strategy_pivot_strength + 3));
   MqlRates rates[];
   if(!LoadClosedRates(rates, needed))
      return false;

   const int structure_dir = StructureDirection(rates);
   const int bos_dir = BosDirection(rates);
   const int momentum_dir = MomentumDirection();
   const int mtf_dir = MtfTrendDirection();
   const bool volume_ok = VolumeConfirms(rates);
   const int sweep_dir = LiquiditySweepDirection(rates);
   const int smart_dir = SmartMoneyDirection(rates);
   const int fvg_dir = FvgDirection(rates);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || !RegimeAllowsTrade())
      return false;

   int side = 0;
   if(strategy_enable_longs && structure_dir > 0)
      side = 1;
   else if(strategy_enable_shorts && structure_dir < 0)
      side = -1;
   else
      return false;

   if(strategy_require_bos && bos_dir != side)
      return false;
   if(strategy_require_fvg && fvg_dir != side)
      return false;
   if(HasBearishConflict(side, momentum_dir, mtf_dir, smart_dir))
      return false;

   const int score = ConfluenceScore(side,
                                     structure_dir,
                                     momentum_dir,
                                     mtf_dir,
                                     volume_ok,
                                     sweep_dir,
                                     smart_dir,
                                     fvg_dir);
   if(score < strategy_min_score)
      return false;

   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (side > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = ConservativeStop(req.type, entry, rates, atr);
   if(req.sl <= 0.0)
      return false;
   if((req.type == QM_BUY && req.sl >= entry) || (req.type == QM_SELL && req.sl <= entry))
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
   if(req.tp <= 0.0)
      return false;

   req.reason = (side > 0) ? "TV_VORTEX_LONG" : "TV_VORTEX_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trailing_enabled)
      return;

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

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trailing_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
