#property strict
#property version   "5.0"
#property description "QM5_10656 TradingView Order Block Volumatic FVG"

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
input int    qm_ea_id                   = 10656;
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
input int    strategy_fvg_lookback_bars       = 240;
input int    strategy_min_fvg_age_bars        = 20;
input double strategy_long_mitigation_pct     = 60.0;
input double strategy_short_mitigation_pct    = 60.0;
input bool   strategy_candle_confirmation     = false;
input int    strategy_volume_filter_mode      = 2;      // 0=off, 1=min total, 2=min total + directional share
input double strategy_min_tick_volume         = 0.0;
input double strategy_min_directional_share   = 0.55;
input double strategy_stop_percent            = 1.0;
input int    strategy_atr_period              = 14;
input double strategy_atr_stop_cap_mult       = 1.5;
input int    strategy_trailing_trigger_mode   = 1;      // 0=percent, 1=R multiple
input double strategy_trailing_trigger_pct    = 1.0;
input double strategy_trailing_trigger_r      = 1.0;
input double strategy_trailing_atr_mult       = 1.0;
input int    strategy_cooldown_bars           = 5;

datetime g_cooldown_until = 0;

struct FvgCandidate
  {
   bool   found;
   int    direction;
   int    age_bars;
   double lower;
   double upper;
   double mitigation_pct;
   double directional_share;
   double tick_volume;
  };

double Strategy_Clamp(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

void Strategy_ResetCandidate(FvgCandidate &candidate)
  {
   candidate.found = false;
   candidate.direction = 0;
   candidate.age_bars = 0;
   candidate.lower = 0.0;
   candidate.upper = 0.0;
   candidate.mitigation_pct = 0.0;
   candidate.directional_share = 0.0;
   candidate.tick_volume = 0.0;
  }

double Strategy_DirectionalShare(const MqlRates &bar, const int direction)
  {
   const double range = bar.high - bar.low;
   double bull_share = 0.5;
   if(range > 0.0)
      bull_share = Strategy_Clamp((bar.close - bar.low) / range, 0.0, 1.0);
   else if(bar.close > bar.open)
      bull_share = 1.0;
   else if(bar.close < bar.open)
      bull_share = 0.0;

   if(direction > 0)
      return bull_share;
   return 1.0 - bull_share;
  }

bool Strategy_VolumePasses(const MqlRates &bar, const int direction, double &directional_share)
  {
   directional_share = Strategy_DirectionalShare(bar, direction);
   const double total_volume = (double)bar.tick_volume;

   if(strategy_volume_filter_mode >= 1 && total_volume < strategy_min_tick_volume)
      return false;

   if(strategy_volume_filter_mode >= 2 && directional_share < strategy_min_directional_share)
      return false;

   return true;
  }

bool Strategy_CandlePasses(const MqlRates &bar, const int direction)
  {
   if(!strategy_candle_confirmation)
      return true;
   if(direction > 0)
      return (bar.close > bar.open);
   return (bar.close < bar.open);
  }

bool Strategy_FindNewestFvg(const int direction, FvgCandidate &candidate)
  {
   Strategy_ResetCandidate(candidate);
   if(strategy_fvg_lookback_bars < strategy_min_fvg_age_bars + 3)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_needed = strategy_fvg_lookback_bars + 4;
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, bars_needed, rates); // perf-allowed: bounded structural FVG scan, called only from the skeleton's post-QM_IsNewBar entry hook.
   if(copied < strategy_min_fvg_age_bars + 4)
      return false;

   const MqlRates current = rates[1];
   const int max_shift = MathMin(strategy_fvg_lookback_bars, copied - 3);
   for(int shift = strategy_min_fvg_age_bars + 1; shift <= max_shift; ++shift)
     {
      const MqlRates right = rates[shift];
      const MqlRates left = rates[shift + 2];

      double lower = 0.0;
      double upper = 0.0;
      if(direction > 0)
        {
         if(right.low <= left.high)
            continue;
         lower = left.high;
         upper = right.low;
        }
      else
        {
         if(right.high >= left.low)
            continue;
         lower = right.high;
         upper = left.low;
        }

      if(lower <= 0.0 || upper <= lower)
         continue;
      if(current.low > upper || current.high < lower)
         continue;

      const double height = upper - lower;
      double mitigation = 0.0;
      if(direction > 0)
         mitigation = Strategy_Clamp((upper - current.low) / height * 100.0, 0.0, 100.0);
      else
         mitigation = Strategy_Clamp((current.high - lower) / height * 100.0, 0.0, 100.0);

      const double threshold = (direction > 0) ? strategy_long_mitigation_pct : strategy_short_mitigation_pct;
      if(mitigation < threshold)
         continue;

      double share = 0.0;
      if(!Strategy_VolumePasses(current, direction, share))
         continue;
      if(!Strategy_CandlePasses(current, direction))
         continue;

      candidate.found = true;
      candidate.direction = direction;
      candidate.age_bars = shift - 1;
      candidate.lower = lower;
      candidate.upper = upper;
      candidate.mitigation_pct = mitigation;
      candidate.directional_share = share;
      candidate.tick_volume = (double)current.tick_volume;
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

double Strategy_StopDistance(const QM_OrderType type, const double entry_price)
  {
   if(entry_price <= 0.0 || strategy_stop_percent <= 0.0)
      return 0.0;

   double stop_distance = entry_price * strategy_stop_percent * 0.01;
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr > 0.0 && strategy_atr_stop_cap_mult > 0.0)
     {
      const double atr_cap = atr * strategy_atr_stop_cap_mult;
      if(atr_cap > 0.0 && atr_cap < stop_distance)
         stop_distance = atr_cap;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point > 0.0 && stop_distance < point * 5.0)
      stop_distance = point * 5.0;

   return stop_distance;
  }

void Strategy_SetCooldown()
  {
   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar > 0 && strategy_cooldown_bars > 0)
      g_cooldown_until = TimeCurrent() + seconds_per_bar * strategy_cooldown_bars;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(TimeCurrent() < g_cooldown_until)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   FvgCandidate bull;
   FvgCandidate bear;
   Strategy_FindNewestFvg(1, bull);
   Strategy_FindNewestFvg(-1, bear);
   if(!bull.found && !bear.found)
      return false;

   FvgCandidate chosen;
   Strategy_ResetCandidate(chosen);
   if(bull.found && (!bear.found || bull.age_bars <= bear.age_bars))
      chosen = bull;
   else
      chosen = bear;

   req.type = (chosen.direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry_price = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_distance = Strategy_StopDistance(req.type, entry_price);
   if(entry_price <= 0.0 || stop_distance <= 0.0)
      return false;

   req.sl = (req.type == QM_BUY)
            ? QM_StopRulesNormalizePrice(_Symbol, entry_price - stop_distance)
            : QM_StopRulesNormalizePrice(_Symbol, entry_price + stop_distance);
   req.tp = 0.0;
   req.reason = StringFormat("TV_OB_VOL_FVG_%s_age%d_mit%.1f_share%.2f",
                             (chosen.direction > 0) ? "LONG" : "SHORT",
                             chosen.age_bars,
                             chosen.mitigation_pct,
                             chosen.directional_share);
   Strategy_SetCooldown();
   return true;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= 0.0)
         continue;

      double trigger_distance = risk_distance * strategy_trailing_trigger_r;
      if(strategy_trailing_trigger_mode == 0)
         trigger_distance = open_price * strategy_trailing_trigger_pct * 0.01;
      if(trigger_distance <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved >= trigger_distance)
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
