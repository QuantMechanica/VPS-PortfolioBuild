#property strict
#property version   "5.0"
#property description "QM5_9976 ForexFactory EMA Fibonacci RSI Stochastic"

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
input int    qm_ea_id                   = 9976;
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
input int    strategy_ema_period              = 20;
input int    strategy_atr_period              = 20;
input double strategy_fibo_stop_atr_mult      = 0.382;
input double strategy_fibo_tp_atr_mult        = 0.618;
input int    strategy_rsi_period              = 10;
input double strategy_rsi_midline             = 50.0;
input int    strategy_stoch_k                 = 10;
input int    strategy_stoch_d                 = 3;
input int    strategy_stoch_slowing           = 3;
input int    strategy_fixed_stop_pips         = 10;
input int    strategy_min_fx_stop_pips        = 5;
input double strategy_max_spread_stop_fraction = 0.10;
input int    strategy_no_entry_last_minutes   = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

double Strategy_PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * factor;
  }

bool Strategy_ReadClosedBars(MqlRates &bar1, MqlRates &bar2)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 1, 2, rates) != 2) // perf-allowed: fixed two closed bars for EMA bounce/close tests.
      return false;

   bar1 = rates[0];
   bar2 = rates[1];
   return (bar1.close > 0.0 && bar2.close > 0.0);
  }

bool Strategy_IsFXSymbol()
  {
   return (StringFind(_Symbol, "XAU") < 0 &&
           StringFind(_Symbol, "XAG") < 0 &&
           StringFind(_Symbol, "XTI") < 0 &&
           StringFind(_Symbol, "XNG") < 0);
  }

bool Strategy_StochCrossesAnyLevel(const bool bullish,
                                   const double k_now,
                                   const double d_now,
                                   const double k_prev,
                                   const double d_prev)
  {
   if(bullish)
     {
      if(!(k_prev <= d_prev && k_now > d_now))
         return false;
      return ((k_prev < 20.0 && k_now >= 20.0) ||
              (k_prev < 40.0 && k_now >= 40.0) ||
              (k_prev < 60.0 && k_now >= 60.0) ||
              (k_prev < 80.0 && k_now >= 80.0));
     }

   if(!(k_prev >= d_prev && k_now < d_now))
      return false;
   return ((k_prev > 80.0 && k_now <= 80.0) ||
           (k_prev > 60.0 && k_now <= 60.0) ||
           (k_prev > 40.0 && k_now <= 40.0) ||
           (k_prev > 20.0 && k_now <= 20.0));
  }

double Strategy_NormalizePrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double Strategy_EnforceStopDistance(const QM_OrderType side,
                                    const double entry,
                                    const double raw_price,
                                    const bool is_stop)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || raw_price <= 0.0)
      return 0.0;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_dist = MathMax((double)stops_level * point, point);
   double price = raw_price;

   if(QM_OrderTypeIsBuy(side))
     {
      if(is_stop && entry - price < min_dist)
         price = entry - min_dist;
      if(!is_stop && price - entry < min_dist)
         price = entry + min_dist;
     }
   else
     {
      if(is_stop && price - entry < min_dist)
         price = entry + min_dist;
      if(!is_stop && entry - price < min_dist)
         price = entry - min_dist;
     }

   return Strategy_NormalizePrice(price);
  }

bool Strategy_GetOpenPositionType(ENUM_POSITION_TYPE &ptype)
  {
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_no_entry_last_minutes <= 0)
      return false;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(_Period == PERIOD_H1)
      return (now.min >= 60 - strategy_no_entry_last_minutes);

   const int period_minutes = PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60;
   if(period_minutes <= 0)
      return false;

   const int minute_in_period = (now.hour * 60 + now.min) % period_minutes;
   return (period_minutes - minute_in_period <= strategy_no_entry_last_minutes);
  }

bool Strategy_BuildRequest(const QM_OrderType side,
                           const double ema_now,
                           const double atr_now,
                           QM_EntryRequest &req)
  {
   const double pip = Strategy_PipDistance();
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr_now <= 0.0 || pip <= 0.0)
      return false;

   const double fibo_stop_dist = strategy_fibo_stop_atr_mult * atr_now;
   const double fixed_stop_dist = strategy_fixed_stop_pips * pip;
   const double min_fx_stop_dist = strategy_min_fx_stop_pips * pip;

   double level_stop = 0.0;
   double fixed_stop = 0.0;
   if(side == QM_BUY)
     {
      level_stop = ema_now - fibo_stop_dist;
      if(Strategy_IsFXSymbol() && entry - level_stop < min_fx_stop_dist)
         level_stop = entry - min_fx_stop_dist;
      fixed_stop = entry - fixed_stop_dist;
      req.sl = MathMin(level_stop, fixed_stop);
      req.tp = entry + strategy_fibo_tp_atr_mult * atr_now;
      req.reason = "EMA20_FIBO_RSI_STOCH_LONG";
     }
   else
     {
      level_stop = ema_now + fibo_stop_dist;
      if(Strategy_IsFXSymbol() && level_stop - entry < min_fx_stop_dist)
         level_stop = entry + min_fx_stop_dist;
      fixed_stop = entry + fixed_stop_dist;
      req.sl = MathMax(level_stop, fixed_stop);
      req.tp = entry - strategy_fibo_tp_atr_mult * atr_now;
      req.reason = "EMA20_FIBO_RSI_STOCH_SHORT";
     }

   req.type = side;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.sl = Strategy_EnforceStopDistance(side, entry, req.sl, true);
   req.tp = Strategy_EnforceStopDistance(side, entry, req.tp, false);

   const double stop_distance = MathAbs(entry - req.sl);
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(stop_distance <= 0.0 || spread < 0.0)
      return false;
   if(spread > stop_distance * strategy_max_spread_stop_fraction)
      return false;

   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   MqlRates bar1;
   MqlRates bar2;
   if(!Strategy_ReadClosedBars(bar1, bar2))
      return false;

   const double ema_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 2);
   const double atr_now = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double rsi_now = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2);
   const double k_now = QM_Stoch_K(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d_now = QM_Stoch_D(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d_prev = QM_Stoch_D(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   if(ema_now <= 0.0 || ema_prev <= 0.0 || atr_now <= 0.0)
      return false;

   const bool long_ema_cross = (bar2.close <= ema_prev && bar1.close > ema_now);
   const bool long_ema_bounce = (bar1.low <= ema_now && bar1.close > ema_now && bar2.close > ema_prev);
   const bool long_rsi = (rsi_prev <= strategy_rsi_midline && rsi_now > strategy_rsi_midline);
   const bool long_stoch = Strategy_StochCrossesAnyLevel(true, k_now, d_now, k_prev, d_prev);
   if((long_ema_cross || long_ema_bounce) && long_rsi && long_stoch)
      return Strategy_BuildRequest(QM_BUY, ema_now, atr_now, req);

   const bool short_ema_cross = (bar2.close >= ema_prev && bar1.close < ema_now);
   const bool short_ema_bounce = (bar1.high >= ema_now && bar1.close < ema_now && bar2.close < ema_prev);
   const bool short_rsi = (rsi_prev >= strategy_rsi_midline && rsi_now < strategy_rsi_midline);
   const bool short_stoch = Strategy_StochCrossesAnyLevel(false, k_now, d_now, k_prev, d_prev);
   if((short_ema_cross || short_ema_bounce) && short_rsi && short_stoch)
      return Strategy_BuildRequest(QM_SELL, ema_now, atr_now, req);

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_GetOpenPositionType(ptype))
      return false;

   MqlRates bar1;
   MqlRates bar2;
   if(!Strategy_ReadClosedBars(bar1, bar2))
      return false;

   const double ema_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double rsi_now = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2);
   if(ema_now <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (bar1.close < ema_now && rsi_prev >= strategy_rsi_midline && rsi_now < strategy_rsi_midline);
   if(ptype == POSITION_TYPE_SELL)
      return (bar1.close > ema_now && rsi_prev <= strategy_rsi_midline && rsi_now > strategy_rsi_midline);

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
