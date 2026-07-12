#property strict
#property version   "5.3"
#property description "QM5_13204 Std-Dev Reversal off the First Significant Swing (ICT/SMC mechanization, v2 confluence)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA  —  QM5_13204 sd-first-swing-rev
// -----------------------------------------------------------------------------
// MECHANIZATION of the ICT/SMC "standard-deviation off the first significant
// swing" method (video zw_J5RP31cA, docs/research/VIDEO_zw_J5RP31cA_ANALYSIS_2026-07-12.md).
// The video's core input ("first SIGNIFICANT swing") is explicitly discretionary
// ("train your eyes… it'll stand out like a sore thumb"), so this is a CONCRETE
// HYPOTHESIS, not a faithful port. Operationalization:
//   - swing extreme  = lowest low / highest high over `swing_lookback` closed bars
//   - "significant"  = the first-swing leg range R >= sig_atr_mult * ATR
//   - sweep          = last closed bar wicks BEYOND the swing extreme by
//                      <= sweep_atr_mult * ATR and CLOSES back inside (reclaim)
//   - entry          = market on the reclaim (liquidity grab + reversal)
//   - SL             = beyond the sweep wick (sl_buffer_atr * ATR)
//   - TP             = tp_r_mult * R projected from entry (the std-dev target)
//   - time stop      = flat after max_hold_bars
// Single position, single target. No grid/martingale/averaging. No ML.
// v2: higher-TF PD-array confluence gate (new-day opening gap + directional HTF
// FVG) at the sweep — the video's central "HTF support/resistance" element.
// Toggle strategy_use_confluence (default true); false reproduces v1.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13204;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_lookback    = 30;    // closed bars to locate the swing extreme
input int    strategy_atr_period        = 14;
input double strategy_sig_atr_mult      = 1.5;   // first-swing leg R must be >= this * ATR ("significant")
input double strategy_sweep_atr_mult    = 0.6;   // max wick beyond the extreme (liquidity grab)
input double strategy_sl_buffer_atr     = 0.3;   // stop beyond the sweep wick
input double strategy_tp_r_mult         = 2.0;   // take-profit = this * R (std-dev target)
input int    strategy_max_hold_bars     = 48;    // time stop
input double strategy_max_spread_stop_pct = 15.0;// reject if spread > this % of SL distance
input bool   strategy_allow_long        = true;
input bool   strategy_allow_short       = true;

input group "Confluence (v2 — the video's PD-array gate)"
input bool             strategy_use_confluence   = true;   // require HTF PD-array at the sweep
input ENUM_TIMEFRAMES  strategy_conf_htf         = PERIOD_H1; // higher timeframe for FVG scan
input int              strategy_conf_fvg_lookback = 40;     // HTF bars scanned for an FVG
input double           strategy_conf_atr_mult    = 0.5;     // sweep must be within this*ATR of a PD-array

input group "Fade (v3 — contra-indicator test)"
input bool             strategy_invert           = false;  // FADE the setup: emit the opposite
                                                            // direction with risk-symmetric stops.
                                                            // Tests OWNER's "confluence = contra-
                                                            // indicator" hypothesis (fade the reversal).

input group "Trailing exit (v4 — let continuations run)"
input bool             strategy_use_trail        = false;  // ATR trailing stop (for continuation moves)
input double           strategy_trail_atr_mult   = 2.0;    // trail distance = this * ATR

// -----------------------------------------------------------------------------
// helpers
// -----------------------------------------------------------------------------

// Confluence: is price level `px` within `tol` of a higher-TF PD-array on the
// correct side — a new-day opening gap (D1) or a directional higher-TF fair-value
// gap. This is the video's "higher-timeframe support/resistance at the sweep" gate.
bool QM13204_HasConfluence(const double px, const double tol, const bool is_long)
  {
   // 1) New-day opening gap (D1 open vs prior D1 close) — precise, D1-derived.
   const double d1o  = iOpen(_Symbol,  PERIOD_D1, 0);
   const double d1pc = iClose(_Symbol, PERIOD_D1, 1);
   if(d1o > 0.0 && d1pc > 0.0 && d1o != d1pc)
     {
      const double lo = MathMin(d1o, d1pc);
      const double hi = MathMax(d1o, d1pc);
      if(px >= lo - tol && px <= hi + tol)
         return true;
     }
   // 2) Higher-TF fair-value gap (3-bar imbalance) on the correct side.
   const int nb = strategy_conf_fvg_lookback + 3;
   MqlRates h[];
   ArraySetAsSeries(h, true);
   if(CopyRates(_Symbol, strategy_conf_htf, 1, nb, h) >= nb)
     {
      for(int i = 0; i + 2 < nb; ++i)
        {
         if(is_long)
           {
            // bullish FVG (support): older-bar high (i+2) below newer-bar low (i)
            if(h[i + 2].high < h[i].low)
              {
               const double zlo = h[i + 2].high;
               const double zhi = h[i].low;
               if(px >= zlo - tol && px <= zhi + tol)
                  return true;
              }
           }
         else
           {
            // bearish FVG (resistance): older-bar low (i+2) above newer-bar high (i)
            if(h[i + 2].low > h[i].high)
              {
               const double zlo = h[i].high;
               const double zhi = h[i + 2].low;
               if(px >= zlo - tol && px <= zhi + tol)
                  return true;
              }
           }
        }
     }
   return false;
  }

// Validate SL/TP: correct side, respect broker stops level, spread sanity.
bool QM13204_StopsOk(const double entry, const double sl, const double tp, const QM_OrderType side)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double sl_dist = MathAbs(entry - sl);
   const double tp_dist = MathAbs(tp - entry);
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;
   const double min_dist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(min_dist > 0.0 && (sl_dist < min_dist || tp_dist < min_dist))
      return false;
   if(side == QM_BUY  && (sl >= entry || tp <= entry))
      return false;
   if(side == QM_SELL && (sl <= entry || tp >= entry))
      return false;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   if((spread / sl_dist) * 100.0 > strategy_max_spread_stop_pct)
      return false;
   return true;
  }

// Emit the order for a detected setup. `nat_type` = the natural (reversal) direction,
// `nat_sl` = the natural structural stop, `R` = the first-swing leg range (for the TP).
// If strategy_invert, FADE it: opposite direction, risk-symmetric stop, TP = tp_r_mult*R
// the other way. Returns false if the broker stops guard rejects.
bool QM13204_Emit(QM_EntryRequest &req, const QM_OrderType nat_type,
                  const double nat_sl, const double R, const int digits)
  {
   QM_OrderType otype = nat_type;
   string rsn = (nat_type == QM_BUY) ? "SD_FIRST_SWING_LONG_SWEEP" : "SD_FIRST_SWING_SHORT_SWEEP";
   double entry = (nat_type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   double sl = nat_sl;
   double tp = (nat_type == QM_BUY) ? entry + strategy_tp_r_mult * R
                                    : entry - strategy_tp_r_mult * R;
   if(strategy_invert)
     {
      otype = (nat_type == QM_BUY) ? QM_SELL : QM_BUY;
      rsn = (nat_type == QM_BUY) ? "SD_FIRST_SWING_LONGSETUP_FADED"
                                 : "SD_FIRST_SWING_SHORTSETUP_FADED";
      entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double risk = MathAbs(entry - nat_sl);            // same risk, opposite side
      sl = (otype == QM_BUY) ? entry - risk : entry + risk;
      tp = (otype == QM_BUY) ? entry + strategy_tp_r_mult * R
                             : entry - strategy_tp_r_mult * R;
     }
   if(!QM13204_StopsOk(entry, sl, tp, otype))
      return false;
   req.type = otype;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, digits);
   req.tp = NormalizeDouble(tp, digits);
   req.reason = rsn;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;   // MANDATORY (uninit -> silent zero-trades)
   req.expiration_seconds = 0;

   if(strategy_swing_lookback < 5 || strategy_atr_period <= 0 ||
      strategy_sig_atr_mult <= 0.0 || strategy_tp_r_mult <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int N = strategy_swing_lookback;
   const int need = N + 2;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   // start_pos=1 => r[0] is the last CLOSED bar (the sweep candidate), r[1..N] the swing window.
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, need, r);
   if(copied < need)
      return false;

   // ---- LONG: down-swing low swept and reclaimed ----
   if(strategy_allow_long)
     {
      int iL = -1;
      double SL = DBL_MAX;
      for(int i = 1; i <= N; ++i)
         if(r[i].low < SL) { SL = r[i].low; iL = i; }
      if(iL >= 2)
        {
         double SH = -DBL_MAX;
         for(int i = 1; i < iL; ++i)          // rally high AFTER the low (more recent bars)
            if(r[i].high > SH) SH = r[i].high;
         const double R = SH - SL;
         const double sweep_depth = SL - r[0].low;
         if(R >= strategy_sig_atr_mult * atr &&
            r[0].low < SL && r[0].close > SL &&
            sweep_depth >= 0.0 && sweep_depth <= strategy_sweep_atr_mult * atr &&
            (!strategy_use_confluence ||
             QM13204_HasConfluence(r[0].low, strategy_conf_atr_mult * atr, true)))
           {
            const double sl = r[0].low - strategy_sl_buffer_atr * atr;
            if(QM13204_Emit(req, QM_BUY, sl, R, digits))
               return true;
           }
        }
     }

   // ---- SHORT: up-swing high swept and reclaimed ----
   if(strategy_allow_short)
     {
      int iH = -1;
      double SH = -DBL_MAX;
      for(int i = 1; i <= N; ++i)
         if(r[i].high > SH) { SH = r[i].high; iH = i; }
      if(iH >= 2)
        {
         double SL = DBL_MAX;
         for(int i = 1; i < iH; ++i)          // drop low AFTER the high (more recent bars)
            if(r[i].low < SL) SL = r[i].low;
         const double R = SH - SL;
         const double sweep_depth = r[0].high - SH;
         if(R >= strategy_sig_atr_mult * atr &&
            r[0].high > SH && r[0].close < SH &&
            sweep_depth >= 0.0 && sweep_depth <= strategy_sweep_atr_mult * atr &&
            (!strategy_use_confluence ||
             QM13204_HasConfluence(r[0].high, strategy_conf_atr_mult * atr, false)))
           {
            const double sl = r[0].high + strategy_sl_buffer_atr * atr;
            if(QM13204_Emit(req, QM_SELL, sl, R, digits))
               return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_trail || strategy_trail_atr_mult <= 0.0)
      return;
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
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;
   const int magic = QM_FrameworkMagic();
   const datetime last_closed_bar = iTime(_Symbol, PERIOD_CURRENT, 1);
   const int period_seconds = PeriodSeconds(PERIOD_CURRENT);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(period_seconds > 0 && last_closed_bar > open_time &&
         ((last_closed_bar - open_time) / period_seconds) >= strategy_max_hold_bars)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central news filter
  }

// -----------------------------------------------------------------------------
// Framework wiring — mirror of the proven skeleton. Do NOT edit below.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
