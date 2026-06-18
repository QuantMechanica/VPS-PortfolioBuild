#property strict
#property version   "5.0"
#property description "QM5_1230 Carver Dynamic-Vol Starter MAV"

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
input int    qm_ea_id                   = 1230;
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
input int    strategy_fast_ema_period      = 16;
input int    strategy_slow_ema_period      = 64;
input int    strategy_daily_vol_period     = 25;
input double strategy_stop_gap_vol_mult    = 8.0;
input int    strategy_min_d1_bars          = 100;
input int    strategy_cooldown_bars        = 20;
input bool   strategy_exit_on_ma_flip      = true;
input bool   strategy_dynamic_derisk       = true;
input double strategy_derisk_step          = 0.10;
input int    strategy_spread_cap_points    = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_spread_cap_points)
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

   static bool had_position = false;
   static int last_position_direction = 0;
   static int cooldown_direction = 0;
   static int cooldown_remaining = 0;

   bool have_position = false;
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

      have_position = true;
      last_position_direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }

   if(!have_position && had_position)
     {
      cooldown_direction = last_position_direction;
      cooldown_remaining = strategy_cooldown_bars;
     }
   had_position = have_position;

   if(have_position)
      return false;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_daily_vol_period <= 1 ||
      strategy_stop_gap_vol_mult <= 0.0 ||
      strategy_min_d1_bars < strategy_slow_ema_period)
      return false;

   const double warmup_close = iClose(_Symbol, PERIOD_D1, strategy_min_d1_bars + 1); // perf-allowed: one D1 warmup probe inside framework new-bar gate.
   if(warmup_close <= 0.0)
      return false;

   const double fast_ma = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_ema_period, 1);
   const double slow_ma = QM_EMA(_Symbol, PERIOD_D1, strategy_slow_ema_period, 1);
   if(fast_ma <= 0.0 || slow_ma <= 0.0)
      return false;

   int raw_signal = 0;
   if(fast_ma > slow_ma)
      raw_signal = 1;
   else if(fast_ma < slow_ma)
      raw_signal = -1;
   if(raw_signal == 0)
      return false;

   if(cooldown_remaining > 0)
     {
      if(raw_signal == cooldown_direction)
        {
         cooldown_remaining--;
         return false;
        }
      cooldown_remaining = 0;
      cooldown_direction = 0;
     }

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= strategy_daily_vol_period; ++shift)
     {
      const double c_now = iClose(_Symbol, PERIOD_D1, shift);       // perf-allowed: 25-bar close-difference volatility, gated by Strategy_EntrySignal new-bar caller.
      const double c_prev = iClose(_Symbol, PERIOD_D1, shift + 1);  // perf-allowed: paired previous close for card-defined daily close-to-close changes.
      if(c_now <= 0.0 || c_prev <= 0.0)
         continue;
      const double diff = c_now - c_prev;
      sum += diff;
      sum_sq += diff * diff;
      samples++;
     }
   if(samples < strategy_daily_vol_period)
      return false;

   const double mean = sum / (double)samples;
   const double variance = (sum_sq / (double)samples) - mean * mean;
   if(variance <= 0.0)
      return false;

   const double daily_vol = MathSqrt(variance);
   const double stop_gap = strategy_stop_gap_vol_mult * daily_vol;
   if(stop_gap <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 close used as fallback entry anchor.
   double entry_price = 0.0;
   if(raw_signal > 0)
     {
      req.type = QM_BUY;
      entry_price = (ask > 0.0) ? ask : close_last;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_price - stop_gap);
      req.reason = "carver_dynvol_mav_long";
     }
   else
     {
      req.type = QM_SELL;
      entry_price = (bid > 0.0) ? bid : close_last;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_price + stop_gap);
      req.reason = "carver_dynvol_mav_short";
     }

   if(entry_price <= 0.0 || req.sl <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   static ulong tracked_ticket = 0;
   static double initial_vol = 0.0;
   static double initial_lots = 0.0;

   if(strategy_daily_vol_period <= 1 || strategy_stop_gap_vol_mult <= 0.0)
      return;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= strategy_daily_vol_period; ++shift)
     {
      const double c_now = iClose(_Symbol, PERIOD_D1, shift);       // perf-allowed: bounded 25-bar daily-vol recompute; O(25), no CopyRates.
      const double c_prev = iClose(_Symbol, PERIOD_D1, shift + 1);  // perf-allowed: card requires close-to-close price changes.
      if(c_now <= 0.0 || c_prev <= 0.0)
         continue;
      const double diff = c_now - c_prev;
      sum += diff;
      sum_sq += diff * diff;
      samples++;
     }
   if(samples < strategy_daily_vol_period)
      return;

   const double mean = sum / (double)samples;
   const double variance = (sum_sq / (double)samples) - mean * mean;
   if(variance <= 0.0)
      return;

   const double current_vol = MathSqrt(variance);
   const double stop_gap = strategy_stop_gap_vol_mult * current_vol;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(current_vol <= 0.0 || stop_gap <= 0.0 || point <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found = true;
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      if(ticket != tracked_ticket)
        {
         tracked_ticket = ticket;
         initial_vol = current_vol;
         initial_lots = lots;
        }

      const double target_sl = QM_StopRulesNormalizePrice(_Symbol, is_buy ? (market_price - stop_gap) : (market_price + stop_gap));
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(target_sl > 0.0 && improves)
         QM_TM_MoveSL(ticket, target_sl, "carver_dynvol_watermark_stop");

      if(strategy_dynamic_derisk && initial_vol > 0.0 && initial_lots > 0.0 &&
         current_vol > initial_vol * (1.0 + strategy_derisk_step))
        {
         double target_lots = initial_lots * initial_vol / current_vol;
         if(target_lots < min_lot)
            target_lots = min_lot;
         if(lots > target_lots + min_lot * 0.5)
           {
            const double excess = QM_TM_NormalizeVolume(_Symbol, lots - target_lots);
            if(excess >= min_lot && lots - excess >= min_lot)
               QM_TM_PartialClose(ticket, excess, QM_EXIT_PARTIAL);
           }
        }
     }

   if(!found)
     {
      tracked_ticket = 0;
      initial_vol = 0.0;
      initial_lots = 0.0;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_exit_on_ma_flip)
      return false;

   const double fast_ma = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_ema_period, 1);
   const double slow_ma = QM_EMA(_Symbol, PERIOD_D1, strategy_slow_ema_period, 1);
   if(fast_ma <= 0.0 || slow_ma <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && fast_ma < slow_ma)
         return true;
      if(position_type == POSITION_TYPE_SELL && fast_ma > slow_ma)
         return true;
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
