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
input int    qm_ea_id                   = 11234;
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
input int    strategy_ema_fast          = 9;
input int    strategy_ema_pullback      = 16;
input int    strategy_ema_trend_slow    = 200;
input int    strategy_rsi_period        = 16;
input double strategy_rsi_bounce_level  = 35.0;
input double strategy_rsi_overbought    = 78.0;
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input double strategy_volume_factor     = 0.80;
input int    strategy_volume_lookback   = 20;
input int    strategy_obv_ema_period    = 20;
input int    strategy_obv_warmup_bars   = 220;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 3.0;
input double strategy_source_stop_pct   = 6.0;
input double strategy_trail_start_pct   = 5.0;
input double strategy_trail_pct         = 3.0;

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
   req.reason = "FT_TR_RSI_BOUNCE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int rates_needed = MathMax(strategy_obv_warmup_bars, strategy_volume_lookback + 2);
   MqlRates rates[];
   ArrayResize(rates, rates_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, rates_needed, rates); // perf-allowed: closed-bar hook computes OBV and tick-volume ratio unavailable as QM helpers.
   if(copied != rates_needed)
      return false;

   const double close1 = rates[0].close;
   const double open1 = rates[0].open;
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   const double ema200 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 1);
   if(ema200 <= 0.0 || close1 <= ema200)
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   if(!(rsi_prev < strategy_rsi_bounce_level && rsi_now > strategy_rsi_bounce_level))
      return false;

   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_lower <= 0.0 || close1 <= bb_lower)
      return false;
   if(close1 <= open1)
      return false;

   if(strategy_volume_lookback <= 0 || rates_needed < strategy_volume_lookback + 1)
      return false;

   double volume_sum = 0.0;
   for(int i = 1; i <= strategy_volume_lookback; ++i)
      volume_sum += (double)rates[i].tick_volume;
   const double avg_volume = volume_sum / (double)strategy_volume_lookback;
   if(avg_volume <= 0.0 || (double)rates[0].tick_volume <= avg_volume * strategy_volume_factor)
      return false;

   if(rates_needed < strategy_obv_ema_period + 2)
      return false;

   const double alpha = 2.0 / ((double)strategy_obv_ema_period + 1.0);
   double obv = 0.0;
   double obv_ema = 0.0;
   bool seeded = false;
   for(int i = rates_needed - 2; i >= 0; --i)
     {
      if(rates[i].close > rates[i + 1].close)
         obv += (double)rates[i].tick_volume;
      else if(rates[i].close < rates[i + 1].close)
         obv -= (double)rates[i].tick_volume;

      if(!seeded)
        {
         obv_ema = obv;
         seeded = true;
        }
      else
         obv_ema = alpha * obv + (1.0 - alpha) * obv_ema;
     }
   if(!(obv > obv_ema))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   const double source_stop_distance = ask * (strategy_source_stop_pct / 100.0);
   const double atr_stop_distance = atr * strategy_atr_stop_mult;
   const double stop_distance = MathMin(source_stop_distance, atr_stop_distance);
   if(stop_distance <= 0.0)
      return false;

   req.sl = NormalizeDouble(ask - stop_distance, _Digits);
   req.tp = 0.0;
   return (req.sl > 0.0 && req.sl < ask);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(open_price <= 0.0 || bid <= 0.0)
         continue;

      const double profit_pct = 100.0 * (bid - open_price) / open_price;
      if(profit_pct < strategy_trail_start_pct)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double target_sl = NormalizeDouble(bid * (1.0 - strategy_trail_pct / 100.0), _Digits);
      if(target_sl <= 0.0)
         continue;
      if(current_sl <= 0.0 || target_sl > current_sl + _Point * 0.5)
         QM_TM_MoveSL(ticket, target_sl, "source_trail_3pct_after_5pct");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const double profit_pct = (open_price > 0.0 && bid > 0.0) ? 100.0 * (bid - open_price) / open_price : 0.0;
      const double hours_open = (opened_at > 0) ? ((double)(TimeCurrent() - opened_at) / 3600.0) : 0.0;

      if(hours_open >= 24.0)
         return true;
      if(hours_open >= 16.0 && profit_pct < 1.0)
         return true;
      if(hours_open >= 8.0 && profit_pct < 0.5)
         return true;
      if(hours_open >= 4.0 && profit_pct < 0.0)
         return true;
      if(hours_open >= 2.0 && profit_pct < -1.5)
         return true;

      const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
      if(rsi > strategy_rsi_overbought)
         return true;

      const double ema9_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
      const double ema16_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pullback, 1);
      const double ema9_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 2);
      const double ema16_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pullback, 2);
      const double macd_main = QM_MACD_Main(_Symbol, PERIOD_H1, 12, 26, 9, 1);
      const double macd_signal = QM_MACD_Signal(_Symbol, PERIOD_H1, 12, 26, 9, 1);
      const double macd_hist = macd_main - macd_signal;
      if(ema9_now < ema16_now && ema9_prev >= ema16_prev && macd_hist < 0.0 && rsi > 50.0)
         return true;

      MqlRates rates[];
      ArrayResize(rates, 3);
      ArraySetAsSeries(rates, true);
      const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 3, rates); // perf-allowed: closed-bar cross checks need OHLC values not exposed as QM readers.
      if(copied != 3)
         return false;

      const double ema200_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 1);
      const double ema200_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_trend_slow, 2);
      if(rates[0].close < ema200_now * 0.99 && rates[1].close >= ema200_prev * 0.99)
         return true;

      const double macd_main_prev = QM_MACD_Main(_Symbol, PERIOD_H1, 12, 26, 9, 2);
      const double macd_signal_prev = QM_MACD_Signal(_Symbol, PERIOD_H1, 12, 26, 9, 2);
      const double macd_hist_prev = macd_main_prev - macd_signal_prev;
      if(rates[0].close < ema200_now * 0.995 && rsi > 72.0 && macd_hist < macd_hist_prev)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
