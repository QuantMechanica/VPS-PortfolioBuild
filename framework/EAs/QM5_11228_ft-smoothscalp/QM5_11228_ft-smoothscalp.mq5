#property strict
#property version   "5.0"
#property description "QM5_11228 ft-smoothscalp — Freqtrade SmoothScalp M1 oversold-reversal scalp (long-only)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11228 ft-smoothscalp
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies "SmoothScalp.py" (berlinguyinca), GitHub
//   commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4.
// Card: artifacts/cards_approved/QM5_11228_ft-smoothscalp.md (g0_status APPROVED).
//
// Mechanics (long-only M1 oversold-reversal scalp, closed-bar reads at shift 1):
//   Entry (one EVENT + several STATES on the trigger bar):
//     STATE  open(1)  < EMA5(low)        -- bar opened below the EMA of lows
//     STATE  ADX(14)  > adx_min          -- trend strength present
//     STATE  MFI(14)  < mfi_max          -- money-flow oversold
//     STATE  FastK    < stoch_max  AND  FastD < stoch_max
//     EVENT  FastK crosses above FastD   -- the single fresh-cross trigger
//     STATE  CCI(20)  < cci_entry_max    -- deep CCI oversold
//   Stop  : QM_StopATR(atr_period, sl_atr_mult)  (baseline ATR(14) x 1.0).
//   Take  : QM_TakeRR(rr) relative to the ATR stop distance (source 1% ROI proxy).
//   Exit  : CCI(20) > cci_exit_min  AND ( open(1) >= EMA5(high) OR FastK > stoch_exit_hi )
//           Source's "cross above 70" relaxed to a >70 STATE to avoid requiring two
//           cross EVENTS on one bar (.DWX zero-trade invariant #4).
//   Spread: fail-open on .DWX zero modeled spread; block only a genuinely wide
//           spread > spread_pct_of_stop of the ATR stop distance.
//
// One open position per symbol/magic (source's many-parallel-trades assumption is
// explicitly NOT adopted — see card HR14 note). No ML / grid / martingale.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11228;
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
input int    strategy_ema_period         = 5;      // EMA period on high/low (EMA5)
input int    strategy_stoch_k            = 5;      // Fast Stochastic %K period
input int    strategy_stoch_d            = 3;      // Fast Stochastic %D period
input int    strategy_stoch_slowing      = 3;      // Fast Stochastic slowing
input int    strategy_adx_period         = 14;     // ADX period
input double strategy_adx_min            = 30.0;   // ADX trend-strength floor
input int    strategy_mfi_period         = 14;     // MFI period
input double strategy_mfi_max            = 30.0;   // MFI oversold ceiling (entry)
input double strategy_stoch_max          = 30.0;   // FastK/FastD oversold ceiling (entry)
input int    strategy_cci_period         = 20;     // CCI period
input double strategy_cci_entry_max      = -150.0; // CCI entry oversold ceiling
input double strategy_cci_exit_min       = 150.0;  // CCI exit overbought floor
input double strategy_stoch_exit_hi      = 70.0;   // FastK overbought exit level
input int    strategy_atr_period         = 14;     // ATR period (stop)
input double strategy_sl_atr_mult        = 1.0;    // stop distance = mult * ATR
input double strategy_tp_rr              = 1.0;    // take-profit reward:risk multiple
input double strategy_spread_pct_of_stop = 4.0;    // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; entry/regime work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

   // --- STATE: bar opened below the EMA of lows (EMA5 on PRICE_LOW) ---
   const double ema_low = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_LOW);
   if(ema_low <= 0.0)
      return false;
   const double open1 = iOpen(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(open1 <= 0.0)
      return false;
   if(!(open1 < ema_low))
      return false;

   // --- STATE: ADX trend strength ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_min))
      return false;

   // --- STATE: MFI oversold ---
   const double mfi = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi <= 0.0)
      return false;
   if(!(mfi < strategy_mfi_max))
      return false;

   // --- STATE: CCI deeply oversold ---
   const double cci = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   if(!(cci < strategy_cci_entry_max))
      return false;

   // --- STATE: FastK and FastD both oversold + EVENT: FastK crosses above FastD ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d_now  = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || d_now <= 0.0)
      return false;
   if(!(k_now < strategy_stoch_max && d_now < strategy_stoch_max))
      return false;
   // The single fresh-cross EVENT: %K was at/below %D, now above it.
   const bool k_crosses_up = (k_prev <= d_prev && k_now > d_now);
   if(!k_crosses_up)
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
   req.reason = "smoothscalp_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / RR target. The signal
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exit: CCI overbought AND (bar opened above EMA5(high) OR FastK overbought).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double cci = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   if(!(cci > strategy_cci_exit_min))
      return false;

   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_HIGH);
   const double open1    = iOpen(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const bool   above_ema_high = (ema_high > 0.0 && open1 > 0.0 && open1 >= ema_high);

   const double k_now = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const bool   stoch_overbought = (k_now > strategy_stoch_exit_hi);

   return (above_ema_high || stoch_overbought);
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
