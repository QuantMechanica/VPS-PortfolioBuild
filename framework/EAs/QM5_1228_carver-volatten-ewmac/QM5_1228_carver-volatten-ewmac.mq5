#property strict
#property version   "5.0"
#property description "QM5_1228 carver-volatten-ewmac — Carver volatility-attenuated EWMAC trend (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1228 carver-volatten-ewmac
// -----------------------------------------------------------------------------
// Source: Rob Carver (qoppac blog).
//   - 2015 EWMAC base rule: forecast = (EMA(fast) - EMA(slow)) / price_vol,
//     scaled by a forecast scalar and capped to a bounded band.
//   - 2021 volatility-attenuation post: multiply every raw forecast by an
//     attenuation factor derived from the current volatility percentile, so
//     exposure is cut in high-vol regimes and modestly raised in low-vol ones.
// Card: artifacts/cards_approved/QM5_1228_carver-volatten-ewmac.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift >= 1, evaluated once per new D1 bar):
//   EWMAC      : raw = (EMA(fast) - EMA(slow)) / price_vol.
//   price_vol  : StdDev(close, vol_fast_period) — price-unit daily volatility,
//                scale-correct per symbol (matches the EMA difference units).
//   raw scaled : raw_forecast = raw * forecast_scalar (Carver scalar; tuned so
//                the typical |forecast| sits near 10).
//   vol regime : normalised_vol = short_vol / long_vol, with
//                short_vol = StdDev(close, vol_fast_period),
//                long_vol  = StdDev(close, vol_slow_period) (long-run proxy).
//   vol_quantile : rank fraction of the current normalised_vol within a fixed
//                  rank_window of prior normalised_vol values (bounded port of
//                  Carver's "percentile vs all prior history"; see open_q).
//   attenuation: clamp(2.0 - 1.5 * vol_quantile, atten_lo, atten_hi).
//   forecast   : clamp(raw_forecast * attenuation, -fc_cap, +fc_cap).
//   LONG  if forecast > +entry_threshold.
//   SHORT if forecast < -entry_threshold.
//   Exit LONG  when forecast <= 0 ; exit SHORT when forecast >= 0.
//   Stop       : emergency 2.5 * ATR(20) on entry (both directions).
//   Spread gd  : skip only a genuinely wide spread > spread_pct_of_stop of the
//                stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1228;
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
// EWMAC base rule (Carver: slow = 4 * fast; default fast=16 -> slow=64).
input int    strategy_ewmac_fast        = 16;     // fast EMA span
input int    strategy_ewmac_slow        = 64;     // slow EMA span (= 4 * fast)
input double strategy_forecast_scalar   = 4.1;    // Carver forecast scalar (EWMAC16/64 ~ 4.1)
input double strategy_fc_cap            = 20.0;   // bounded forecast clamp [-cap,+cap]
input double strategy_entry_threshold   = 4.0;    // |forecast| > this => enter (deadband)
// Volatility attenuation.
input int    strategy_vol_fast_period   = 25;     // short price-vol StdDev period (daily vol)
input int    strategy_vol_slow_period   = 100;    // long-run price-vol StdDev period (regime proxy)
input int    strategy_vol_rank_window   = 40;     // bars of prior normalised_vol for the percentile rank
input double strategy_atten_lo          = 0.25;   // attenuation lower bound
input double strategy_atten_hi          = 2.0;    // attenuation upper bound
// Emergency stop.
input int    strategy_atr_period        = 20;     // ATR period for the emergency stop
input double strategy_sl_atr_mult       = 2.5;    // emergency stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: continuous Carver forecast for a given closed-bar shift.
// Returns true on success and writes the bounded forecast into out_fc.
// All reads are closed-bar (shift >= 1) via pooled QM_* handles, so this is
// safe to call a bounded number of times per new bar.
// -----------------------------------------------------------------------------
bool ComputeForecastAtShift(const int shift, double &out_fc)
  {
   if(shift < 1)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ewmac_fast, shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ewmac_slow, shift);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // Price-unit daily volatility (same units as the EMA difference).
   const double price_vol = QM_StdDev(_Symbol, _Period, strategy_vol_fast_period, shift);
   if(price_vol <= 0.0)
      return false;

   // Raw EWMAC, normalised by price vol, scaled by the Carver forecast scalar.
   const double raw          = (ema_fast - ema_slow) / price_vol;
   const double raw_forecast = raw * strategy_forecast_scalar;

   // Volatility regime: short vol vs long-run vol.
   const double long_vol = QM_StdDev(_Symbol, _Period, strategy_vol_slow_period, shift);
   if(long_vol <= 0.0)
      return false;
   const double norm_vol = price_vol / long_vol;

   // Volatility percentile rank within a bounded window of PRIOR normalised_vol
   // values (shifts shift+1 .. shift+rank_window). Bounded port of Carver's
   // "percentile vs all prior history": rank = fraction of prior values below
   // the current one, in [0,1].
   int counted = 0;
   int below   = 0;
   for(int k = 1; k <= strategy_vol_rank_window; ++k)
     {
      const int s = shift + k;
      const double sv = QM_StdDev(_Symbol, _Period, strategy_vol_fast_period, s);
      const double lv = QM_StdDev(_Symbol, _Period, strategy_vol_slow_period, s);
      if(sv <= 0.0 || lv <= 0.0)
         continue;
      const double nv = sv / lv;
      counted++;
      if(nv < norm_vol)
         below++;
     }
   // Default to neutral quantile (0.5 -> attenuation 1.25) until window fills.
   double vol_quantile = 0.5;
   if(counted > 0)
      vol_quantile = (double)below / (double)counted;

   // Attenuation: high vol (high quantile) -> small factor; low vol -> larger.
   double attenuation = 2.0 - 1.5 * vol_quantile;
   if(attenuation < strategy_atten_lo) attenuation = strategy_atten_lo;
   if(attenuation > strategy_atten_hi) attenuation = strategy_atten_hi;

   // Final bounded forecast.
   double fc = raw_forecast * attenuation;
   if(fc >  strategy_fc_cap) fc =  strategy_fc_cap;
   if(fc < -strategy_fc_cap) fc = -strategy_fc_cap;

   out_fc = fc;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — forecast work is on the
// closed-bar entry/exit path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// LONG  if forecast > +threshold ; SHORT if forecast < -threshold.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double forecast = 0.0;
   if(!ComputeForecastAtShift(1, forecast))
      return false;

   QM_OrderType side;
   if(forecast > strategy_entry_threshold)
      side = QM_BUY;
   else if(forecast < -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // trend rule: no fixed TP; exit on forecast sign flip
   req.reason = (side == QM_BUY) ? "ewmac_volatten_long" : "ewmac_volatten_short";
   return true;
  }

// No active trade management beyond the fixed emergency ATR stop. The
// forecast-sign exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: close LONG when forecast <= 0 ; close SHORT when forecast >= 0.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double forecast = 0.0;
   if(!ComputeForecastAtShift(1, forecast))
      return false;

   // Determine current net direction for this magic.
   bool has_long  = false;
   bool has_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  has_long  = true;
      if(ptype == POSITION_TYPE_SELL) has_short = true;
     }

   if(has_long && forecast <= 0.0)
      return true;
   if(has_short && forecast >= 0.0)
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
