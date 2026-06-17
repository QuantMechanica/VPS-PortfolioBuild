#property strict
#property version   "5.0"
#property description "QM5_11229 ft-freinforced — Freqtrade FReinforced: M5 EMA cross in H1 SMA regime, ADX exit (long/short, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11229 ft-freinforced
// -----------------------------------------------------------------------------
// Source: FReinforcedStrategy.py, freqtrade-strategies (GitHub, commit
//   dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4).
// Card: artifacts/cards_approved/QM5_11229_ft-freinforced.md (g0_status APPROVED).
//
// Mechanics (long/short symmetric, closed-bar reads at shift 1, base TF = M5):
//   Regime STATE : H1 SMA(resample_sma_period) on the resampled (H1) close.
//                  The framework reads the H1 series natively via
//                  QM_SMA(_Symbol, PERIOD_H1, ...) — equivalent to the source's
//                  "resample 12 x M5 -> 1h, SMA on the resampled close".
//   Trigger EVENT: EMA(short) crosses EMA(long) on the M5 series. The cross is
//                  the single per-bar event; the H1 regime is a STATE filter.
//     Long  : close(M5) > H1 SMA50  AND  EMA8 crosses ABOVE EMA21.
//     Short : close(M5) < H1 SMA50  AND  EMA8 crosses BELOW EMA21.
//   Exit  EVENT  : ADX14 (M5) < adx_exit_max (source uses pos_entry_adx=30).
//                  Mirrors the freqtrade signal exit for both directions.
//   Stop         : QM_StopATR(atr_period, sl_atr_mult). Source -5% retained as a
//                  disaster cap via the framework's fixed-fraction stop; the ATR
//                  stop is the operative MT5 baseline.
//   Take profit  : ATR-multiple TP. The source ROI ladder (5% / 10%@30m /
//                  7.5%@60m) is NON-MONOTONIC and not portable to a single MT5
//                  TP; per the card's "normalize or disable" note it is replaced
//                  by a clean monotonic ATR target. ADX exit + stop carry exits.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-OPEN on .DWX zero modeled spread).
//
// One open position per symbol/magic; never simultaneous long + short.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11229;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_short_period   = 8;       // fast EMA on M5 (source default)
input int    strategy_ema_long_period    = 21;      // slow EMA on M5 (source default)
input int    strategy_adx_period         = 14;      // ADX period on M5
input double strategy_adx_exit_max       = 30.0;    // exit when ADX < this (source pos_entry_adx)
input int    strategy_resample_sma_period = 50;     // SMA period on the H1 (resampled) series
input int    strategy_atr_period         = 14;      // ATR period (stop / target)
input double strategy_sl_atr_mult        = 1.5;     // stop distance = mult * ATR (card baseline)
input double strategy_tp_atr_mult        = 3.0;     // target distance = mult * ATR (monotonic ROI replacement)
input double strategy_spread_pct_of_stop = 15.0;    // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar entry path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short symmetric entry. Caller guarantees QM_IsNewBar() == true (M5 close).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (no simultaneous long + short).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- M5 EMA cross EVENT (short EMA vs long EMA), prev shift 2 / now shift 1 ---
   const double ema_fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 1);
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 2);
   if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
      return false;

   const bool crossed_up   = (ema_fast_prev <= ema_slow_prev && ema_fast_now >  ema_slow_now);
   const bool crossed_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now <  ema_slow_now);
   if(!crossed_up && !crossed_down)
      return false;

   // --- H1 SMA regime STATE (resampled-close SMA read natively on PERIOD_H1) ---
   const double h1_sma = QM_SMA(_Symbol, PERIOD_H1, strategy_resample_sma_period, 1);
   if(h1_sma <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // ATR for stop / target sizing.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, (crossed_up ? SYMBOL_ASK : SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   // --- Long: close above H1 regime AND fresh bullish cross ---
   if(crossed_up && close1 > h1_sma)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ft_freinforced_long";
      return true;
     }

   // --- Short: close below H1 regime AND fresh bearish cross ---
   if(crossed_down && close1 < h1_sma)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ft_freinforced_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target. The ADX-weakness
// exit lives in Strategy_ExitSignal (symmetric for long and short).
void Strategy_ManageOpenPosition()
  {
  }

// Source signal exit: ADX14 weakening below adx_exit_max closes the position
// for both directions. One closed-bar read.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double adx_now = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx_now <= 0.0)
      return false;

   return (adx_now < strategy_adx_exit_max);
  }

// Defer to the central news filter.
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
