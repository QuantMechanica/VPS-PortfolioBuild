#property strict
#property version   "5.0"
#property description "QM5_11381 psar-ao-ac-trend-align-h1 — PSAR flip + AO/AC alignment (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11381 psar-ao-ac-trend-align-h1
// -----------------------------------------------------------------------------
// Source: "Winning Pips System 4" (anonymous, fxmiracle.com), local PDF.
// Card: artifacts/cards_approved/QM5_11381_psar-ao-ac-trend-align-h1.md
//       (g0_status APPROVED). Source ID 875997e6-a398-5eb7-a5ee-75e75a020ad6.
//
// Three Bill Williams indicators aligned on H1 (all reads at closed bars):
//   PSAR  : iSAR(step, max). Dot BELOW price = bullish, ABOVE = bearish.
//   AO    : SMA5(hl2) - SMA34(hl2). Computed from QM_SMA on PRICE_MEDIAN (=hl2).
//   AC    : AO - SMA5(AO). SMA5(AO) is a 5-bar mean of AO values (manual, since
//           no handle takes AO as input). AC "green" when AC[s] > AC[s+1].
//
// ENTRY (closed signal bar = shift 1):
//   LONG  : PSAR dot is below the signal candle AND AO is green/rising
//           AND AC is green/rising.
//   SHORT : PSAR dot is above the signal candle AND AO is red/falling
//           AND AC is red/falling.
// The card describes a same-bar PSAR flip as the "best signal", but the hard
// entry bullets only require PSAR position. This build implements the hard
// bullets literally and does not require multiple fresh cross events on one bar.
//
// STOP   : LONG = low of the signal (just-closed) bar; SHORT = high of it.
//          Capped at strategy_sl_cap_pips (card P2 cap: 25 pips), pip-scaled.
// TAKE   : 1:1 RR off the realised stop distance (QM_TakeRR rr=1).
// EXIT   : both AO and AC reverse color vs the position direction
//          (LONG: AO falling AND AC falling; SHORT: AO rising AND AC rising).
//
// One position per symbol/magic. RISK_FIXED ($1000) in tester, RISK_PERCENT live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11381;
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
input double strategy_sar_step          = 0.02;   // PSAR acceleration step
input double strategy_sar_max           = 0.20;   // PSAR acceleration maximum
input int    strategy_ao_fast           = 5;      // AO fast SMA period (on hl2)
input int    strategy_ao_slow           = 34;     // AO slow SMA period (on hl2)
input int    strategy_ac_sma            = 5;      // AC = AO - SMA(this) of AO
input int    strategy_sl_cap_pips       = 25;     // P2 max stop distance, pips
input double strategy_tp_rr             = 1.0;    // take-profit reward:risk
input double strategy_spread_cap_pips   = 20.0;   // skip only if spread > this (pips)

// -----------------------------------------------------------------------------
// AO / AC helpers — deterministic from QM_SMA on hl2 (PRICE_MEDIAN).
// AO[shift] = SMA(ao_fast, hl2)[shift] - SMA(ao_slow, hl2)[shift].
// AC[shift] = AO[shift] - mean_{k=0..ac_sma-1} AO[shift+k].
// All reads are closed-bar (shift >= 1). Bounded loops (ac_sma small).
// -----------------------------------------------------------------------------
bool AO_ValueAt(const int shift, double &ao_out)
  {
   ao_out = 0.0;
   if(strategy_ao_fast <= 0 || strategy_ao_slow <= strategy_ao_fast)
      return false;

   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow, shift, PRICE_MEDIAN);
   if(fast <= 0.0 || slow <= 0.0)
      return false;

   ao_out = fast - slow;
   return true;
  }

// Returns false (and ao/ac unset) if any underlying SMA read is unavailable.
bool AO_AC_At(const int shift, double &ao_out, double &ac_out)
  {
   if(strategy_ac_sma <= 0)
      return false;

   double ao = 0.0;
   if(!AO_ValueAt(shift, ao))
      return false;

   double sum = 0.0;
   for(int k = 0; k < strategy_ac_sma; ++k)
     {
      double ao_k = 0.0;
      if(!AO_ValueAt(shift + k, ao_k))
         return false;
      sum += ao_k;
     }
   const double ao_sma = sum / (double)strategy_ac_sma;
   ao_out = ao;
   ac_out = ao - ao_sma;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide quoted spread blocks; zero/equal ask==bid passes.
bool Strategy_NoTradeFilter()
  {
   if(strategy_sar_step <= 0.0 || strategy_sar_max <= strategy_sar_step ||
      strategy_ao_fast <= 0 || strategy_ao_slow <= strategy_ao_fast ||
      strategy_ac_sma <= 0 || strategy_sl_cap_pips <= 0 ||
      strategy_tp_rr <= 0.0 || strategy_spread_cap_pips <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double cap_price = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_price <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap_price)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// PSAR position plus AO/AC direction implement the card's closed-candle entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- PSAR at the signal bar (shift 1) ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // PSAR position relative to price (dot below = bullish, above = bearish).
   const bool sar_below = (sar1 < close1);
   const bool sar_above = (sar1 > close1);

   // --- AO / AC states at the signal bar (shift 1) and prior bar (shift 2) ---
   double ao1 = 0.0, ac1 = 0.0, ao2 = 0.0, ac2 = 0.0;
   if(!AO_AC_At(1, ao1, ac1))
      return false;
   if(!AO_AC_At(2, ao2, ac2))
      return false;

   const bool ao_rising  = (ao1 > ao2);
   const bool ao_falling = (ao1 < ao2);
   const bool ac_rising  = (ac1 > ac2);
   const bool ac_falling = (ac1 < ac2);

   QM_OrderType dir;
   double stop_anchor;
   if(sar_below && ao_rising && ac_rising)
     {
      dir = QM_BUY;
      stop_anchor = iLow(_Symbol, _Period, 1);  // perf-allowed: signal-bar low
     }
   else if(sar_above && ao_falling && ac_falling)
     {
      dir = QM_SELL;
      stop_anchor = iHigh(_Symbol, _Period, 1); // perf-allowed: signal-bar high
     }
   else
      return false;

   if(stop_anchor <= 0.0)
      return false;

   // --- Stop = structure (signal-bar low/high), capped at sl_cap_pips ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = QM_StopRulesNormalizePrice(_Symbol, stop_anchor);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   if(dir == QM_BUY)
     {
      // SL must be below entry; cap the distance.
      if(sl >= entry)
         return false;
      if((entry - sl) > cap_dist)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry - cap_dist);
     }
   else
     {
      if(sl <= entry)
         return false;
      if((sl - entry) > cap_dist)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry + cap_dist);
     }

   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "psar_ao_ac_long" : "psar_ao_ac_short";
   return true;
  }

// Fixed SL/TP; no active trailing. Discretionary exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: AO AND AC both reverse color against the open position.
// LONG closes when AO falling AND AC falling; SHORT when AO rising AND AC rising.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open-position direction for this magic.
   bool is_long = false, have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   double ao1 = 0.0, ac1 = 0.0, ao2 = 0.0, ac2 = 0.0;
   if(!AO_AC_At(1, ao1, ac1))
      return false;
   if(!AO_AC_At(2, ao2, ac2))
      return false;

   const bool ao_rising  = (ao1 > ao2);
   const bool ao_falling = (ao1 < ao2);
   const bool ac_rising  = (ac1 > ac2);
   const bool ac_falling = (ac1 < ac2);

   if(is_long)
      return (ao_falling && ac_falling);
   return (ao_rising && ac_rising);
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. Must be the first statement in OnTick.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per EA_Skeleton.mq5).
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

   // FW1 — 2-axis news check gates NEW entries only, evaluated AFTER
   // management/exit above so risk management keeps running through news
   // windows (2026-07-02 audit rule).
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
