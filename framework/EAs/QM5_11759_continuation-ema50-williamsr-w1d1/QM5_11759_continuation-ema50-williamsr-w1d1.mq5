#property strict
#property version   "5.0"
#property description "QM5_11759 continuation-ema50-williamsr-w1d1 — EMA50 W1-bias + Williams %R D1 pullback continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11759 continuation-ema50-williamsr-w1d1
// -----------------------------------------------------------------------------
// Source: Anonymous, "The Continuation Method (End-of-Day Variant)", in
//   "Secret to Winning Forex" (retail PDF), ~2015, pp. 11-22.
// Card: artifacts/cards_approved/QM5_11759_continuation-ema50-williamsr-w1d1.md
//   (g0_status APPROVED). Weekly+Daily (End-of-Day) sibling of QM5_11464
//   (D1+H4 Robles variant) and QM5_11754 (D1+H4 market-order variant).
//
// Multi-timeframe trend-continuation (bias TF = W1, entry TF = D1):
//
//   BIAS STATE (W1, EMA50) — the higher (weekly) TF defines the trend
//   direction. Card Phase 1: count the EMA50(W1) slope over the last 10 weekly
//   bars (EMA50_W1[0] > EMA50_W1[9] -> bullish; falling -> bearish). Read on
//   the closed weekly bar: now at shift 1, lag at shift 1 + slope_lag.
//       LONG  bias: EMA50(W1) sloping up   AND close(W1,1) > EMA50(W1,1)
//       SHORT bias: EMA50(W1) sloping down AND close(W1,1) < EMA50(W1,1)
//     Slope is read with explicit-TF QM helper calls (no per-EA new-bar gate).
//
//   TRIGGER EVENT (D1, Williams %R) — ONE event drives the entry. A pullback
//   that resumes the trend is detected as the %R exiting the extreme zone in
//   the bias direction on the closed D1 bar (card Phase 3):
//       LONG : WPR(D1,2) < -OS_level AND WPR(D1,1) >= -OS_level (exits OS up)
//       SHORT: WPR(D1,2) > -OB_level AND WPR(D1,1) <= -OB_level (exits OB down)
//   MT5 iWPR scale is [-100, 0]; -80 = oversold, -20 = overbought (card).
//
//   The %R cross is the single trigger EVENT; the W1 EMA50 stack is a STATE
//   filter — they are NEVER required to coincide on the same bar (two-cross
//   trap avoided). The D1 pullback only fires while the W1 bias agrees. The
//   card's STOP-ORDER nuance (buy-stop above the signal-bar high) collapses to
//   the framework single-entry market send at the next D1 open: the same
//   continuation-resumption event, modelled once, framework-sized.
//
//   Stop   : QM_StopATR on D1 (atr_period, sl_atr_mult). Card default for the
//            stop is "signal bar Low - 2*ATR(14,D1)"; the ATR-multiple stop is
//            the framework-canonical realisation of that swing-buffer stop.
//   Target : QM_TakeRR at tp_rr (card's 2:1 RR baseline) off the realised stop.
//            The card's SMA(5) two-close trail is an alternative exit; the
//            framework single-position path uses the fixed RR target plus the
//            W1-bias-flip defensive exit below.
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX 0).
//
// Symbols (card R3 / target_symbols, all in dwx_symbol_matrix.csv):
//   EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD (.DWX). The GER40->GDAXI and
//   OIL->XTIUSD porting hints from the build prompt are NOT card symbols and
//   are not registered for this EA.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11759;
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
input int    strategy_ema_bias_period   = 50;     // W1 EMA defining the trend bias
input int    strategy_ema_slope_lag     = 9;      // weekly bars back for the EMA slope (EMA[1] vs EMA[1+9])
input int    strategy_wpr_period        = 14;     // Williams %R period on D1
input double strategy_wpr_os_level      = 80.0;   // oversold magnitude (level = -80)
input double strategy_wpr_ob_level      = 20.0;   // overbought magnitude (level = -20)
input int    strategy_atr_period        = 14;     // ATR period for the stop (D1)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR (card: 2xATR)
input double strategy_tp_rr             = 2.0;    // take-profit at this R:R (card 2:1)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// Bias TF is fixed W1; entry TF is the chart period (D1 per the setfile).
#define QM11759_BIAS_TF PERIOD_W1

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — bias/signal work lives in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true on the entry (D1) chart.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- BIAS STATE (W1, explicit-TF reads): EMA50 slope + price side ---
   const double ema_w1_now = QM_EMA(_Symbol, QM11759_BIAS_TF, strategy_ema_bias_period, 1);
   const double ema_w1_lag = QM_EMA(_Symbol, QM11759_BIAS_TF, strategy_ema_bias_period,
                                    1 + strategy_ema_slope_lag);
   if(ema_w1_now <= 0.0 || ema_w1_lag <= 0.0)
      return false;

   const double close_w1 = iClose(_Symbol, QM11759_BIAS_TF, 1); // perf-allowed: single closed-bar read
   if(close_w1 <= 0.0)
      return false;

   const bool long_bias  = (ema_w1_now > ema_w1_lag) && (close_w1 > ema_w1_now);
   const bool short_bias = (ema_w1_now < ema_w1_lag) && (close_w1 < ema_w1_now);
   if(!long_bias && !short_bias)
      return false;

   // --- TRIGGER EVENT (D1, Williams %R): %R exits the extreme in bias dir ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // iWPR is bounded [-100, 0]; require values strictly within the band before
   // trusting a cross (a flat read of exactly 0 / -100 is suspect).
   if(wpr_now > 0.0 || wpr_prev > 0.0 || wpr_now < -100.0 || wpr_prev < -100.0)
      return false;

   const double os_level = -strategy_wpr_os_level;   // e.g. -80
   const double ob_level = -strategy_wpr_ob_level;   // e.g. -20

   // Long: %R was oversold (below -80) and crossed back up through -80.
   const bool long_trigger  = long_bias &&
                              (wpr_prev <  os_level) && (wpr_now >= os_level);
   // Short: %R was overbought (above -20) and crossed back down through -20.
   const bool short_trigger = short_bias &&
                              (wpr_prev >  ob_level) && (wpr_now <= ob_level);

   if(!long_trigger && !short_trigger)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = long_trigger ? QM_BUY : QM_SELL;
   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, otype, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_trigger ? "cont_w1d1_long" : "cont_w1d1_short";
   return true;
  }

// Fixed ATR stop + RR target carry the trade; no active management beyond that.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: W1 EMA50 bias flips against the open position. One event,
// read on the closed W1 bar via explicit-TF helpers.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_w1_now = QM_EMA(_Symbol, QM11759_BIAS_TF, strategy_ema_bias_period, 1);
   const double ema_w1_lag = QM_EMA(_Symbol, QM11759_BIAS_TF, strategy_ema_bias_period,
                                    1 + strategy_ema_slope_lag);
   const double close_w1 = iClose(_Symbol, QM11759_BIAS_TF, 1); // perf-allowed: single closed-bar read
   if(ema_w1_now <= 0.0 || ema_w1_lag <= 0.0 || close_w1 <= 0.0)
      return false;

   const bool long_bias  = (ema_w1_now > ema_w1_lag) && (close_w1 > ema_w1_now);
   const bool short_bias = (ema_w1_now < ema_w1_lag) && (close_w1 < ema_w1_now);

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && !long_bias)
         return true;   // long held but W1 bias no longer up
      if(ptype == POSITION_TYPE_SELL && !short_bias)
         return true;   // short held but W1 bias no longer down
     }
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
