#property strict
#property version   "5.0"
#property description "QM5_11716 nico-smi-vq-m15-eurjpy — SMI trigger + VQ/HA/EMA confluence (M15, EURJPY)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11716 nico-smi-vq-m15-eurjpy
// -----------------------------------------------------------------------------
// Source: Nico, "Easy 15min Trading System (#301)", forexstrategiesresources.com
// Card: artifacts/cards_approved/QM5_11716_nico-smi-vq-m15-eurjpy.md (APPROVED).
//
// Mechanics (M15 EURJPY, closed-bar reads at shift 1):
//   Trigger EVENT (ONE per bar):
//     Long : SMI crosses UP out of the oversold zone — SMI[2] < -smi_extreme
//            AND SMI[1] > SMI[2] (curling up from below the extreme).
//     Short: SMI crosses DOWN out of the overbought zone — SMI[2] > +smi_extreme
//            AND SMI[1] < SMI[2].
//   Confirming STATES (must hold on the trigger bar, shift 1):
//     - EMA(5) above/below EMA(6)        (MA-crossover bias)
//     - Heiken-Ashi candle white/red     (HA color filter)
//     - VQ (Volatility Quality) rising/falling (directional-volatility quality)
//   Session STATE: only trade from smi_session_start_h broker-hour onward.
//
//   Stop : 2 x ATR(14).
//   Take : RR-multiple of the stop distance (QM_TakeRR).
//
// SMI is not a native MT5 indicator, so it is computed in-EA via a Blau
// double-EMA chain over the (close - HHLL-midpoint) and (HHLL-range) series.
// VQ is computed per the card's simplified proxy: an ATR-normalized cumulative
// directional-volatility-quality value. Both are recomputed ONCE per closed bar
// (QM_IsNewBar gate) and cached in file scope — the per-tick path is O(1).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached-state advance are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11716;
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
input int    smi_hl_period          = 14;    // SMI: N-bar high/low lookback (%K length)
input int    smi_smooth1            = 10;    // SMI: first EMA smoothing
input int    smi_smooth2            = 14;    // SMI: second EMA smoothing
input double smi_extreme            = 40.0;  // SMI extreme zone (+/-)
input int    ema_fast_period        = 5;     // MA-crossover fast EMA
input int    ema_slow_period        = 6;     // MA-crossover slow EMA
input int    vq_period              = 5;     // VQ ATR-normalization period
input int    atr_period             = 14;    // ATR period (stop / VQ scaling)
input double sl_atr_mult            = 2.0;   // stop distance = mult * ATR
input double tp_rr                  = 1.5;   // take-profit = tp_rr * stop distance
input int    smi_session_start_h    = 7;     // earliest broker hour to take entries
input double spread_pct_of_stop     = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// Index [0] = most recent closed bar (shift 1), [1] = prior closed bar (shift 2).
// -----------------------------------------------------------------------------
double g_smi[2];          // SMI value at closed bars (0=latest, 1=prior)
double g_vq[2];           // VQ value at closed bars (0=latest, 1=prior)
double g_ha_open[2];      // Heiken-Ashi open
double g_ha_close[2];     // Heiken-Ashi close
bool   g_state_ready = false;

// Persistent recursive-state for the SMI double-EMA chain and VQ accumulator.
double g_smi_ema1_num = 0.0;   // EMA1 of (close - HHLL midpoint)
double g_smi_ema2_num = 0.0;   // EMA2 of EMA1_num
double g_smi_ema1_den = 0.0;   // EMA1 of (HHLL range)
double g_smi_ema2_den = 0.0;   // EMA2 of EMA1_den
double g_ha_open_run  = 0.0;   // running Heiken-Ashi open
bool   g_ha_seeded    = false;
double g_vq_run       = 0.0;   // running cumulative VQ value
double g_vq_prev_close = 0.0;
bool   g_vq_seeded    = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Advance the SMI / VQ / Heiken-Ashi cached state by exactly ONE closed bar.
// Called once per new closed bar (after the OnTick QM_IsNewBar gate). Reads the
// last closed bar (shift 1) only — no history scans, O(1) recursive updates.
void AdvanceState_OnNewBar()
  {
   // --- last fully-closed bar (shift 1) raw OHLC. perf-allowed: single reads. ---
   const double o1 = iOpen(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;

   // --- N-bar high/low over the window ending at shift 1 ---
   const int hh_idx = iHighest(_Symbol, _Period, MODE_HIGH, smi_hl_period, 1);
   const int ll_idx = iLowest(_Symbol, _Period, MODE_LOW, smi_hl_period, 1);
   if(hh_idx < 0 || ll_idx < 0)
      return;
   const double hh = iHigh(_Symbol, _Period, hh_idx);
   const double ll = iLow(_Symbol, _Period, ll_idx);
   const double midpoint = 0.5 * (hh + ll);
   const double rel = c1 - midpoint;        // distance from range midpoint
   const double rng = hh - ll;              // range height

   // --- Blau double-EMA smoothing of the SMI numerator/denominator ---
   const double a1 = 2.0 / (smi_smooth1 + 1.0);
   const double a2 = 2.0 / (smi_smooth2 + 1.0);
   if(!g_state_ready)
     {
      g_smi_ema1_num = rel;
      g_smi_ema1_den = rng;
      g_smi_ema2_num = rel;
      g_smi_ema2_den = rng;
     }
   else
     {
      g_smi_ema1_num = g_smi_ema1_num + a1 * (rel - g_smi_ema1_num);
      g_smi_ema1_den = g_smi_ema1_den + a1 * (rng - g_smi_ema1_den);
      g_smi_ema2_num = g_smi_ema2_num + a2 * (g_smi_ema1_num - g_smi_ema2_num);
      g_smi_ema2_den = g_smi_ema2_den + a2 * (g_smi_ema1_den - g_smi_ema2_den);
     }
   double smi_val = 0.0;
   const double half_den = 0.5 * g_smi_ema2_den;
   if(half_den > 0.0)
      smi_val = 100.0 * (g_smi_ema2_num / half_den);

   // --- Heiken-Ashi (recursive open; close = OHLC/4) ---
   const double ha_close = 0.25 * (o1 + h1 + l1 + c1);
   double ha_open;
   if(!g_ha_seeded)
     {
      ha_open    = 0.5 * (o1 + c1);
      g_ha_seeded = true;
     }
   else
      ha_open = 0.5 * (g_ha_open_run + /*prev ha_close*/ g_ha_close[0]);
   g_ha_open_run = ha_open;

   // --- VQ (Volatility Quality, simplified proxy): ATR-normalized cumulative
   //     directional move. Up bars add range/ATR, down bars subtract it. A
   //     rising VQ => bullish directional-volatility quality; falling => bearish. ---
   const double atr_v = QM_ATR(_Symbol, _Period, atr_period, 1);
   double vq_val = g_vq_run;
   if(atr_v > 0.0)
     {
      double dir = 0.0;
      if(g_vq_seeded)
        {
         if(c1 > g_vq_prev_close)      dir = 1.0;
         else if(c1 < g_vq_prev_close) dir = -1.0;
        }
      // smooth the increment with the VQ period to damp noise
      const double incr = dir * (rng / atr_v) / MathMax(1, vq_period);
      vq_val = g_vq_run + incr;
     }
   g_vq_run       = vq_val;
   g_vq_prev_close = c1;
   g_vq_seeded    = true;

   // --- shift cached arrays: [1] <- old [0], [0] <- new ---
   g_smi[1]     = g_smi[0];
   g_vq[1]      = g_vq[0];
   g_ha_open[1] = g_ha_open[0];
   g_ha_close[1] = g_ha_close[0];

   g_smi[0]      = smi_val;
   g_vq[0]       = vq_val;
   g_ha_open[0]  = ha_open;
   g_ha_close[0] = ha_close;

   g_state_ready = true;
  }

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true and state was just advanced.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_ready)
      return false;

   // --- Session STATE: only from smi_session_start_h broker-hour onward ---
   MqlDateTime bt;
   TimeToStruct(iTime(_Symbol, _Period, 0), bt); // current (forming) bar open = broker time
   if(bt.hour < smi_session_start_h)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Confirming STATE: EMA(5) vs EMA(6) on the closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Cached SMI / VQ / Heiken-Ashi states (shift 1 = [0], shift 2 = [1]) ---
   const double smi_now  = g_smi[0];
   const double smi_prev = g_smi[1];
   const double vq_now   = g_vq[0];
   const double vq_prev  = g_vq[1];
   const bool   ha_white = (g_ha_close[0] > g_ha_open[0]);
   const bool   ha_red   = (g_ha_close[0] < g_ha_open[0]);

   // ===================== LONG =====================
   // Trigger EVENT: SMI curling UP out of the oversold extreme.
   const bool smi_long_trigger = (smi_prev < -smi_extreme && smi_now > smi_prev);
   if(smi_long_trigger &&
      ema_fast > ema_slow &&        // MA bias up (STATE)
      ha_white &&                   // Heiken-Ashi white (STATE)
      vq_now > vq_prev)             // VQ rising (STATE)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smi_vq_long";
      return true;
     }

   // ===================== SHORT =====================
   // Trigger EVENT: SMI curling DOWN out of the overbought extreme.
   const bool smi_short_trigger = (smi_prev > smi_extreme && smi_now < smi_prev);
   if(smi_short_trigger &&
      ema_fast < ema_slow &&        // MA bias down (STATE)
      ha_red &&                     // Heiken-Ashi red (STATE)
      vq_now < vq_prev)             // VQ falling (STATE)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smi_vq_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop / RR target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
bool Strategy_ExitSignal()
  {
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

   g_state_ready  = false;
   g_ha_seeded    = false;
   g_vq_seeded    = false;
   g_vq_run       = 0.0;
   g_vq_prev_close = 0.0;

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

   AdvanceState_OnNewBar();

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
