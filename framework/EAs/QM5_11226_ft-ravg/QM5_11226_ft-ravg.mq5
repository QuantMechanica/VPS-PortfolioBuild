#property strict
#property version   "5.0"
#property description "QM5_11226 ft-ravg — Freqtrade Reinforced Average (EMA8/21 cross + 48h SMA gate, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11226 ft-ravg
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies ReinforcedAverageStrategy.py (Gert Wohlgemuth).
// Card: artifacts/cards_approved/QM5_11226_ft-ravg.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1, base TF = H4):
//   Trigger EVENT : EMA(fast) crosses ABOVE EMA(slow)  (one event/bar).
//   Trend STATE   : close > resampled-48h SMA(sma_period).
//                   The source resamples H4 -> 48h (factor 12) then takes
//                   SMA50 on the resampled close. A 48h SMA50-on-close is
//                   reproduced on the native H4 series as an SMA over
//                   (resample_factor * sma_period) H4 bars on PRICE_CLOSE —
//                   same close prices, same window, no per-tick resampling
//                   (see open_questions / SPEC §1).
//   Exit EVENT    : EMA(slow) crosses ABOVE EMA(fast)  (bearish fast/slow cross).
//   Stop          : entry - sl_atr_mult * ATR(atr_period)   (V5 baseline).
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_stop of
//                   the stop distance (fail-open on .DWX zero modeled spread).
//   One open position per symbol/magic. Warmup: needs >= fast/slow + the
//   resampled-SMA window of H4 bars before the trend gate is valid.
//
// Source notes intentionally NOT reimplemented (mechanical-only, framework risk):
//   - source 50% ROI cap is unreachable on DWX symbols and is not a mechanical
//     rule -> omitted (framework TP/Friday-close govern exits).
//   - source -20% disaster stop sits far below the ATR(14,2.0) stop and never
//     binds -> omitted; the ATR stop is the operative stop.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11226;
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
input int    strategy_ema_fast_period    = 8;     // fast EMA (source EMA8)
input int    strategy_ema_slow_period    = 21;    // slow EMA (source EMA21)
input int    strategy_resample_factor    = 12;    // H4 -> 48h resample factor (12 x H4)
input int    strategy_sma_period         = 50;    // SMA period on the resampled close
input int    strategy_atr_period         = 14;    // ATR period (stop)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// Effective H4-bar window that reproduces the 48h SMA(sma_period) on close.
int StrategyTrendSmaBars()
  {
   const int bars = strategy_resample_factor * strategy_sma_period;
   return (bars > 1 ? bars : 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

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

   // --- Trigger EVENT: EMA(fast) crosses ABOVE EMA(slow) (one event/bar) ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_up = (fast_prev <= slow_prev && fast_now > slow_now);
   if(!crossed_up)
      return false;

   // --- Trend STATE: close > resampled-48h SMA(sma_period) on close ---
   // Reproduced on the H4 series as an SMA over (resample_factor*sma_period) H4
   // bars on PRICE_CLOSE. Same close prices, same 48h*sma_period window.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double trend_sma = QM_SMA(_Symbol, _Period, StrategyTrendSmaBars(), 1, PRICE_CLOSE);
   if(trend_sma <= 0.0)
      return false; // warmup not complete — no valid trend gate yet
   if(!(close1 > trend_sma))
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit on bearish EMA cross / Friday close
   req.reason = "ft_ravg_ema_cross_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit is the bearish
// EMA cross in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit EVENT: EMA(slow) crosses ABOVE EMA(fast) (bearish fast/slow cross).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // slow crosses above fast == fast crosses below slow.
   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   return crossed_down;
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
