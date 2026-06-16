#property strict
#property version   "5.0"
#property description "QM5_9968 ForexFactory EMA Band Scalp M1"
// rework v2 2026-06-16 — entry fired ~1 trade/yr (Q02 MIN_TRADES) because the
// EMA(50)-high/low band on M1 is only ~1-2 pips wide and the pullback-into-band
// test was required on the SAME closed bar as the fresh stochastic cross (two
// rare events forced to coincide). Faithful fix: allow the band pullback to have
// occurred within the last strategy_stoch_zone_lookback bars (the same recency
// window the card already grants the oversold/overbought touch), while the
// stochastic cross remains the bar-1 trigger. Thresholds/band definition
// unchanged.

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
input int    qm_ea_id                   = 9968;
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
input int    strategy_ema_band_period        = 50;
input int    strategy_ema_trend_period       = 100;
input int    strategy_stoch_k_period         = 14;
input int    strategy_stoch_d_period         = 3;
input int    strategy_stoch_slowing          = 3;
input int    strategy_stoch_zone_lookback    = 3;
input double strategy_stoch_oversold         = 30.0;
input double strategy_stoch_overbought       = 70.0;
input double strategy_stop_buffer_pips       = 3.0;
input double strategy_take_profit_pips       = 10.0;
input double strategy_max_spread_pips        = 1.2;
input double strategy_spread_stop_fraction   = 0.15;
input int    strategy_atr_period             = 14;
input double strategy_max_stop_atr_mult      = 1.2;
input int    strategy_max_hold_bars          = 20;
input int    strategy_session_start_hour     = 8;
input int    strategy_session_end_hour       = 22;

double Strategy_PipDistance(const double pips)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || pips <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

double Strategy_SpreadDistance()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   int start_h = strategy_session_start_hour;
   if(start_h < 0)
      start_h = 0;
   if(start_h > 23)
      start_h = 23;

   int end_h = strategy_session_end_hour;
   if(end_h < 0)
      end_h = 0;
   if(end_h > 23)
      end_h = 23;
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool Strategy_ReadRecentBars(MqlRates &bar1)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // OnTick calls Strategy_EntrySignal only after QM_IsNewBar() returns true.
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates) != 1)
      return false;
   bar1 = rates[0];
   return (bar1.open > 0.0 && bar1.high > 0.0 && bar1.low > 0.0 && bar1.close > 0.0);
  }

bool Strategy_StochCrossUp()
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(!(k1 > d1 && k2 <= d2))
      return false;

   int lookback = strategy_stoch_zone_lookback;
   if(lookback < 1)
      lookback = 1;
   for(int shift = 1; shift <= lookback; ++shift)
      if(QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift) <= strategy_stoch_oversold)
         return true;
   return false;
  }

bool Strategy_StochCrossDown()
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(!(k1 < d1 && k2 >= d2))
      return false;

   int lookback = strategy_stoch_zone_lookback;
   if(lookback < 1)
      lookback = 1;
   for(int shift = 1; shift <= lookback; ++shift)
      if(QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift) >= strategy_stoch_overbought)
         return true;
   return false;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_SpreadAllowed(const double stop_distance)
  {
   const double spread = Strategy_SpreadDistance();
   const double max_abs = Strategy_PipDistance(strategy_max_spread_pips);
   if(spread <= 0.0 || stop_distance <= 0.0 || max_abs <= 0.0)
      return false;
   return (spread <= max_abs || spread <= stop_distance * strategy_spread_stop_fraction);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return !Strategy_InSession(TimeCurrent());
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

   if(_Period != PERIOD_M1)
      return false;

   MqlRates bar1;
   if(!Strategy_ReadRecentBars(bar1))
      return false;

   const double ema50_high  = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_band_period, 1, PRICE_HIGH);
   const double ema50_low   = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_band_period, 1, PRICE_LOW);
   const double ema50_close = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_band_period, 1, PRICE_CLOSE);
   const double ema100      = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_trend_period, 1, PRICE_CLOSE);
   const double atr_m15     = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(ema50_high <= 0.0 || ema50_low <= 0.0 || ema50_close <= 0.0 || ema100 <= 0.0 || atr_m15 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = Strategy_PipDistance(strategy_stop_buffer_pips);
   const double take_distance = Strategy_PipDistance(strategy_take_profit_pips);
   const double min_stop_distance = Strategy_SpreadDistance() * 4.0;
   const double max_stop_distance = atr_m15 * strategy_max_stop_atr_mult;
   if(buffer <= 0.0 || take_distance <= 0.0 || min_stop_distance <= 0.0 || max_stop_distance <= 0.0)
      return false;
   if(min_stop_distance > max_stop_distance)
      return false;

   const bool trend_long = (ema50_high > ema100 && ema50_low > ema100 && ema50_close > ema100);
   const bool pullback_long = (bar1.low <= ema50_high && bar1.close >= ema50_low);
   if(trend_long && pullback_long && Strategy_StochCrossUp())
     {
      double stop_distance = ask - (ema50_low - buffer);
      if(stop_distance < min_stop_distance)
         stop_distance = min_stop_distance;
      if(stop_distance <= 0.0 || stop_distance > max_stop_distance || !Strategy_SpreadAllowed(stop_distance))
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, ask, stop_distance);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, ask, take_distance);
      req.reason = "EMA_BAND_STOCH_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   const bool trend_short = (ema50_high < ema100 && ema50_low < ema100 && ema50_close < ema100);
   const bool pullback_short = (bar1.high >= ema50_low && bar1.close <= ema50_high);
   if(trend_short && pullback_short && Strategy_StochCrossDown())
     {
      double stop_distance = (ema50_high + buffer) - bid;
      if(stop_distance < min_stop_distance)
         stop_distance = min_stop_distance;
      if(stop_distance <= 0.0 || stop_distance > max_stop_distance || !Strategy_SpreadAllowed(stop_distance))
         return false;

      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, bid, stop_distance);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, bid, take_distance);
      req.reason = "EMA_BAND_STOCH_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no break-even, trailing, partial-close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_GetOurPosition(position_type, open_time))
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M1);
   if(open_time > 0 && hold_seconds > 0 && (long)(TimeCurrent() - open_time) >= hold_seconds)
      return true;

   if(position_type == POSITION_TYPE_BUY && Strategy_StochCrossDown())
      return true;
   if(position_type == POSITION_TYPE_SELL && Strategy_StochCrossUp())
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
