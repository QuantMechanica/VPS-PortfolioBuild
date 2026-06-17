#property strict
#property version   "5.0"
#property description "QM5_11054 pst-accel — pysystemtrade volatility-normalised EWMAC acceleration (D1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11054 pst-accel
// -----------------------------------------------------------------------------
// Source: Rob Carver / pysystemtrade `rob_system` acceleration rule.
//   systems/provided/rules/accel.py + rob_system/config.yaml (accel16/32/64).
// Card: artifacts/cards_approved/QM5_11054_pst-accel.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; long AND short):
//   For each Lfast in {16,32,64} with Lslow = 4*Lfast:
//     ewmac(s)  = (EMA(close,Lfast,s) - EMA(close,Lslow,s)) / vol(s)
//                 vol = ATR(vol_period) as the daily price-volatility scale.
//     accel     = ewmac(1) - ewmac(1 + Lfast)
//     component = clamp(accel * scalar, -fcap, +fcap)     scalar per horizon
//   combined    = mean of the three components.
//   Enter LONG  when combined >= +entry_threshold.
//   Enter SHORT when combined <= -entry_threshold.
//   Exit  LONG  when combined <= +exit_buffer.
//   Exit  SHORT when combined >= -exit_buffer.
//   Emergency stop: stop_atr_mult * ATR(stop_atr_period) from entry. Primary
//     exit is signal reversal; the stop only bounds MT5 worst-case risk.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//     modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11054;
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
input int    strategy_lfast_a           = 16;        // acceleration horizon A (Lfast)
input int    strategy_lfast_b           = 32;        // acceleration horizon B (Lfast)
input int    strategy_lfast_c           = 64;        // acceleration horizon C (Lfast)
input double strategy_scalar_a          = 7.817071;  // forecast scalar, accel16
input double strategy_scalar_b          = 5.563487;  // forecast scalar, accel32
input double strategy_scalar_c          = 3.896721;  // forecast scalar, accel64
input double strategy_forecast_cap      = 20.0;      // per-component clamp [-cap,+cap]
input double strategy_entry_threshold   = 5.0;       // |combined| >= this to enter
input double strategy_exit_buffer       = 1.0;       // close when combined decays to +/- this
input int    strategy_vol_period        = 20;        // ATR period = daily price-volatility scale
input int    strategy_stop_atr_period   = 20;        // ATR period for emergency stop
input double strategy_stop_atr_mult     = 3.0;       // emergency stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;     // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: one volatility-normalised EWMAC acceleration component.
// Returns the capped forecast component for the given horizon, or 0 on bad data
// (signalled via ok=false so callers can abort the whole evaluation cleanly).
// -----------------------------------------------------------------------------
double AccelComponent(const int lfast, const double scalar, bool &ok)
  {
   ok = false;
   if(lfast <= 0)
      return 0.0;
   const int lslow = 4 * lfast;

   // ewmac at shift 1 (most recent closed bar).
   const double vol1 = QM_ATR(_Symbol, _Period, strategy_vol_period, 1);
   if(vol1 <= 0.0)
      return 0.0;
   const double fast1 = QM_EMA(_Symbol, _Period, lfast, 1);
   const double slow1 = QM_EMA(_Symbol, _Period, lslow, 1);
   if(fast1 <= 0.0 || slow1 <= 0.0)
      return 0.0;
   const double ewmac1 = (fast1 - slow1) / vol1;

   // ewmac at shift 1 + lfast (lfast bars before the most recent closed bar).
   const int lag_shift = 1 + lfast;
   const double vol2 = QM_ATR(_Symbol, _Period, strategy_vol_period, lag_shift);
   if(vol2 <= 0.0)
      return 0.0;
   const double fast2 = QM_EMA(_Symbol, _Period, lfast, lag_shift);
   const double slow2 = QM_EMA(_Symbol, _Period, lslow, lag_shift);
   if(fast2 <= 0.0 || slow2 <= 0.0)
      return 0.0;
   const double ewmac2 = (fast2 - slow2) / vol2;

   double comp = (ewmac1 - ewmac2) * scalar;
   if(comp >  strategy_forecast_cap) comp =  strategy_forecast_cap;
   if(comp < -strategy_forecast_cap) comp = -strategy_forecast_cap;

   ok = true;
   return comp;
  }

// Combined equal-weight forecast across the three horizons. Returns false if
// any horizon has insufficient/invalid data (warmup not reached).
bool CombinedForecast(double &combined)
  {
   combined = 0.0;
   bool ok_a = false, ok_b = false, ok_c = false;
   const double ca = AccelComponent(strategy_lfast_a, strategy_scalar_a, ok_a);
   const double cb = AccelComponent(strategy_lfast_b, strategy_scalar_b, ok_b);
   const double cc = AccelComponent(strategy_lfast_c, strategy_scalar_c, ok_c);
   if(!ok_a || !ok_b || !ok_c)
      return false;
   combined = (ca + cb + cc) / 3.0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double combined = 0.0;
   if(!CombinedForecast(combined))
      return false; // warmup not reached / invalid data

   const bool go_long  = (combined >=  strategy_entry_threshold);
   const bool go_short = (combined <= -strategy_entry_threshold);
   if(!go_long && !go_short)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target — exit is signal reversal
      req.reason = "pst_accel_long";
      return true;
     }

   // go_short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "pst_accel_short";
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. Primary exit
// is the signal-reversal close in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-decay exit: close long when combined decays to <= +exit_buffer; close
// short when combined recovers to >= -exit_buffer. Evaluated per closed bar via
// the framework new-bar gate (forecast reads closed bars only).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double combined = 0.0;
   if(!CombinedForecast(combined))
      return false;

   // Determine current position direction for this EA's magic.
   bool is_long = false, is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   if(is_long  && combined <=  strategy_exit_buffer)
      return true;
   if(is_short && combined >= -strategy_exit_buffer)
      return true;
   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
