#property strict
#property version   "5.0"
#property description "QM5_11227 ft-rsmooth — Reinforced Smooth Scalp (long-only, M1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11227 ft-rsmooth
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies ReinforcedSmoothScalp.py (berlinguyinca), GitHub
//   commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4.
// Card: artifacts/cards_approved/QM5_11227_ft-rsmooth.md (g0_status APPROVED).
//
// Mechanics (long-only M1, closed-bar reads at shift 1; M5 SMA trend gate):
//   Trend STATE  : SMA50 on PERIOD_M5 (resample_sma) < close  (price above the
//                  higher-TF mean — the "reinforced" trend gate).
//   Oscillator   : Fast Stochastic(5,3,3) -> FastK, FastD.
//   Filters STATE: MFI(period) < buy_mfi  AND  FastD < buy_fastd  AND
//                  ADX(period) > buy_adx  AND  volume(shift 1) > 0.
//   Trigger EVENT: FastK crosses up through FastD (the ONE fresh event; all
//                  other conditions are states — per .DWX invariant #4).
//   Stop         : QM_StopATR(atr_period, sl_atr_mult). Card baseline 14 / 1.0.
//   Take profit  : QM_TakeRR(rr) — source ROI 2% target expressed as an RR-cap
//                  off the ATR stop so the scalp realises a bounded gain.
//   Exit (signal): open > EMA5(high)  AND  FastD > sell_fastd  AND
//                  FastK > sell_fastk  AND  CCI20 > sell_cci  AND volume>0
//                  (source overbought exhaustion exit).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread). M1
//                  scalp => tight 4% baseline.
//
// One open position per symbol/magic (source's many-parallel-trades assumption
// is explicitly NOT implemented — card constraint, HR14).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11227;
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
// --- Trend gate (higher TF mean) ---
input ENUM_TIMEFRAMES strategy_resample_tf  = PERIOD_M5;  // resample TF for SMA trend gate
input int    strategy_resample_sma_period   = 50;         // SMA50 on the resample TF
// --- Fast Stochastic(5,3,3) ---
input int    strategy_stoch_k_period        = 5;
input int    strategy_stoch_d_period        = 3;
input int    strategy_stoch_slowing         = 3;
// --- Entry filters (source hyperopt defaults) ---
input double strategy_buy_mfi               = 22.0;   // MFI must be below
input double strategy_buy_fastd             = 30.0;   // FastD must be below
input double strategy_buy_adx               = 32.0;   // ADX must be above
input int    strategy_mfi_period            = 14;     // MFI lookback
input int    strategy_adx_period            = 14;     // ADX lookback
// --- Exit filters (source hyperopt defaults) ---
input int    strategy_ema_exit_period       = 5;      // EMA on HIGH for the exit gate
input double strategy_sell_fastd            = 79.0;   // FastD must exceed
input double strategy_sell_fastk            = 70.0;   // FastK must exceed
input double strategy_sell_cci              = 183.0;  // CCI20 must exceed
input int    strategy_cci_period            = 20;     // CCI lookback for the exit
// --- Stop / target ---
input int    strategy_atr_period            = 14;     // ATR period for the stop
input double strategy_sl_atr_mult           = 1.0;    // stop distance = mult * ATR
input double strategy_tp_rr                 = 2.0;    // take-profit RR multiple (bounded scalp gain)
input double strategy_spread_pct_of_stop    = 4.0;    // skip if spread > this % of stop distance (M1 scalp)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- volume STATE: require traded ticks on the last closed bar ---
   const double vol1 = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(vol1 <= 0.0)
      return false;

   // --- Trend STATE: resample SMA below close (price above higher-TF mean) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double resample_sma = QM_SMA(_Symbol, strategy_resample_tf, strategy_resample_sma_period, 1);
   if(resample_sma <= 0.0)
      return false;
   if(!(resample_sma < close1))
      return false;

   // --- Oscillator filter STATES ---
   const double mfi = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi <= 0.0)            // 0/invalid read — wait for warmup
      return false;
   if(!(mfi < strategy_buy_mfi))
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_buy_adx))
      return false;

   const double fastd_now = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                       strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(fastd_now <= 0.0)
      return false;
   if(!(fastd_now < strategy_buy_fastd))
      return false;

   // --- Trigger EVENT: FastK crosses up through FastD (one fresh event) ---
   const double fastk_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                        strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double fastk_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                        strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double fastd_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                        strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(fastk_now <= 0.0 || fastk_prev <= 0.0 || fastd_prev <= 0.0)
      return false;
   const bool crossed_up = (fastk_prev <= fastd_prev && fastk_now > fastd_now);
   if(!crossed_up)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ft_rsmooth_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / RR target. The
// overbought-exhaustion exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Overbought-exhaustion exit (source signal exit). One state check per closed
// bar via the framework new-bar gate in OnTick.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double vol1 = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(vol1 <= 0.0)
      return false;

   const double open0 = iOpen(_Symbol, _Period, 0); // perf-allowed: current bar open
   if(open0 <= 0.0)
      return false;
   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_exit_period, 1, PRICE_HIGH);
   if(ema_high <= 0.0)
      return false;
   if(!(open0 > ema_high))
      return false;

   const double fastd = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double fastk = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(fastd <= 0.0 || fastk <= 0.0)
      return false;
   if(!(fastd > strategy_sell_fastd))
      return false;
   if(!(fastk > strategy_sell_fastk))
      return false;

   const double cci = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   if(!(cci > strategy_sell_cci))
      return false;

   return true;
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
