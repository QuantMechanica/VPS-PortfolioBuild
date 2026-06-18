#property strict
#property version   "5.0"
#property description "QM5_1350 tom-fps-williams-percent-r-h1 — Tom Yeoman FPS Williams %R pullback + EMA-stack (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1350 tom-fps-williams-percent-r-h1
// -----------------------------------------------------------------------------
// Source: Tom Yeoman "Forex Profit System" master-thread (ForexFactory thread/12503),
//   Williams %R(14) pullback variant (FPS-family; oscillator slot = Williams %R).
// Card: artifacts/cards_approved/QM5_1350_tom-fps-williams-percent-r-h1.md
//   (g0_status APPROVED). BUILD TARGET ea_id = 1350 (card frontmatter says
//   ea_id: QM5_12143 — stale; qm_ea_id forced to 1350 per build task; flagged).
//
// Mechanics (H1, closed-bar reads; shift 1 = last closed bar, shift 2 = bar
// before it, ...). Williams %R is bounded [-100, 0]; canonical OS=-80, OB=-20,
// mid=-50. The %R cross back through the mid-line (-50), out of the OS/OB zone,
// is the SINGLE trigger EVENT; the EMA-stack bias, the recent OS/OB dip and the
// EMA-50 slope are STATES evaluated on the same closed bar. The framework
// QM_WPR(sym,tf,period,shift) reader (handle-pooled iWPR) supplies %R — this is
// the sanctioned reader; no raw iWPR / in-EA high-low loop.
//
//   Entry — BUY (all on closed bars; card [0]->shift1, [1]->shift2, ...):
//     STATE  trend bias  : EMA(50)[s1] > EMA(200)[s1]  AND  close[s1] > EMA(50)[s1]
//     STATE  OS dip      : min(WPR[s2], WPR[s3], WPR[s4]) < WPR_OS (-80)
//     EVENT  mid cross   : WPR[s2] <= WPR_REARM (-50)  AND  WPR[s1] > WPR_REARM
//     STATE  slope ok    : EMA(50)[s1] >= EMA(50)[s4]  (trend not flattening)
//     STATE  flat 1-pos  : no open position on this magic
//   Entry — SELL: mirror (EMA50<EMA200 & close<EMA50; max(WPR[s2..s4]) > OB (-20);
//                 WPR[s2] >= -50 & WPR[s1] < -50; EMA50[s1] <= EMA50[s4]).
//
//   Stop  : BUY  = min(low[s1], low[s2]) - stop_atr_buf*ATR, capped so the SL
//                  distance never exceeds stop_atr_cap*ATR.
//           SELL = max(high[s1], high[s2]) + stop_atr_buf*ATR, same cap.
//   TP    : take_rr * initial-SL distance (FPS 2R standard), via QM_TakeRR.
//
//   Exit (Strategy_ExitSignal), whichever first:
//     - Opposite WPR-extreme + turn (BUY: WPR[s1] > OB & WPR[s1] < WPR[s2];
//       SELL: WPR[s1] < OS & WPR[s1] > WPR[s2]) — Williams' classic exit.
//     - EMA-50 cross exit after a min-hold cushion (BUY: close[s1] < EMA50[s1];
//       SELL mirror), gated by bars-in-trade >= ema_exit_min_bars.
//     - Time-stop: position older than time_stop_bars H1 bars.
//
//   Spread  : skip only a genuinely wide spread (fail-open on .DWX zero spread).
//   News    : central two-axis filter (framework). No session window (24x5).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1350;
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
input int    strategy_wpr_period        = 14;     // Williams %R period
input int    strategy_ema_slope_period  = 50;     // fast EMA (FPS slope/bias)
input int    strategy_ema_macro_period  = 200;    // slow EMA (FPS macro bias)
input double strategy_wpr_os            = -80.0;  // oversold line (Williams 1972)
input double strategy_wpr_ob            = -20.0;  // overbought line
input double strategy_wpr_rearm         = -50.0;  // mid-line cross trigger
input int    strategy_os_lookback       = 3;      // bars back to scan for the OS/OB dip
input int    strategy_slope_lookback    = 3;      // EMA-50 slope window (bars)
input int    strategy_atr_period        = 20;     // ATR period (SL buffer + cap)
input double strategy_stop_atr_buf      = 0.3;    // SL = structure -/+ buf*ATR
input double strategy_stop_atr_cap      = 2.5;    // max SL distance = cap*ATR
input int    strategy_stop_low_lookback = 2;      // bars for structure low/high (closed)
input double strategy_take_rr           = 2.0;    // TP = take_rr * SL distance (FPS 2R)
input int    strategy_ema_exit_min_bars = 4;      // min H1 bars before EMA-50 cross exit
input int    strategy_time_stop_bars    = 48;     // hard time-stop (H1 bars ~2 days)
input double strategy_spread_pct_of_stop = 30.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: wide-spread guard only (no session window — 24x5
// H1 trend follower). Returns TRUE to BLOCK. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_stop_atr_buf * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only block a genuinely wide spread; .DWX models 0 spread -> never blocks.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (HR14, FPS 1-pos-per-symbol).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA stack on the last closed bar. ---
   const double ema_fast    = QM_EMA(_Symbol, _Period, strategy_ema_slope_period, 1);
   const double ema_macro   = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double ema_fast_bk = QM_EMA(_Symbol, _Period, strategy_ema_slope_period,
                                     1 + strategy_slope_lookback); // slope reference
   if(ema_fast <= 0.0 || ema_macro <= 0.0 || ema_fast_bk <= 0.0)
      return false;

   // --- Williams %R: shift 1 = newest closed bar (card [0]); shift 2 = card [1]. ---
   const double wpr1 = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1); // card [0]
   const double wpr2 = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2); // card [1]
   // %R is in [-100, 0]; 0.0 is a legitimate value (price at top of range), so
   // do not reject on == 0. Reject only the impossible out-of-band sentinel.
   if(wpr1 < -100.0 || wpr1 > 0.0 || wpr2 < -100.0 || wpr2 > 0.0)
      return false;

   // --- Recent OS/OB dip extreme over the lookback window (card min/max WPR[1..3]
   //     -> closed-bar shifts 2..(1+os_lookback)). ---
   double wpr_min = 0.0;    // most-oversold (lowest) %R in the window
   double wpr_max = -100.0; // most-overbought (highest) %R in the window
   for(int s = 2; s <= 1 + strategy_os_lookback; ++s)
     {
      const double w = QM_WPR(_Symbol, _Period, strategy_wpr_period, s);
      if(w < -100.0 || w > 0.0)
         return false;
      if(w < wpr_min) wpr_min = w;
      if(w > wpr_max) wpr_max = w;
     }

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed single read
   if(close1 <= 0.0)
      return false;

   // ---------------------------- BUY ----------------------------
   const bool bias_bull   = (ema_fast > ema_macro && close1 > ema_fast);
   const bool os_dip      = (wpr_min < strategy_wpr_os);                       // dipped into OS
   const bool cross_up    = (wpr2 <= strategy_wpr_rearm && wpr1 > strategy_wpr_rearm); // EVENT
   const bool slope_bull  = (ema_fast >= ema_fast_bk);                         // not flattening

   if(bias_bull && os_dip && cross_up && slope_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Structure low over the last N closed bars, pushed one ATR-buffer lower.
      const double struct_sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_stop_low_lookback);
      if(struct_sl <= 0.0)
         return false;
      double sl = struct_sl - strategy_stop_atr_buf * atr_value;
      // Cap the SL distance at cap*ATR (sanity floor against an extreme pullback low).
      const double max_dist = strategy_stop_atr_cap * atr_value;
      if(entry - sl > max_dist)
         sl = entry - max_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_wpr_long";
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool bias_bear   = (ema_fast < ema_macro && close1 < ema_fast);
   const bool ob_dip      = (wpr_max > strategy_wpr_ob);                       // pushed into OB
   const bool cross_dn    = (wpr2 >= strategy_wpr_rearm && wpr1 < strategy_wpr_rearm); // EVENT
   const bool slope_bear  = (ema_fast <= ema_fast_bk);                         // not flattening

   if(bias_bear && ob_dip && cross_dn && slope_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double struct_sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_stop_low_lookback);
      if(struct_sl <= 0.0)
         return false;
      double sl = struct_sl + strategy_stop_atr_buf * atr_value;
      const double max_dist = strategy_stop_atr_cap * atr_value;
      if(sl - entry > max_dist)
         sl = entry + max_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_wpr_short";
      return true;
     }

   return false;
  }

// Fixed SL + 2R TP handle the protective side; no active trail.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (whichever fires first), evaluated per closed bar:
//   - opposite WPR-extreme + turn (Williams' classic exit)
//   - EMA-50 cross exit after >= ema_exit_min_bars in trade (anti-whipsaw)
//   - time-stop: position older than time_stop_bars H1 bars
// Direction + open-time taken from the live open position for this EA's magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool     is_long  = false;
   bool     is_short = false;
   datetime open_time = 0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!is_long && !is_short)
      return false;

   // --- Time-stop (H1 bars elapsed since entry). ---
   const int period_secs = PeriodSeconds(_Period);
   if(period_secs > 0 && open_time > 0)
     {
      const int bars_in_trade = (int)((TimeCurrent() - open_time) / period_secs);
      if(bars_in_trade >= strategy_time_stop_bars)
         return true;
     }

   const double wpr1 = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr2 = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_slope_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed
   if(wpr1 < -100.0 || wpr1 > 0.0 || wpr2 < -100.0 || wpr2 > 0.0 ||
      ema_fast <= 0.0 || close1 <= 0.0)
      return false;

   // Min-hold cushion for the EMA-50 cross exit (anti-whipsaw).
   bool ema_exit_armed = false;
   if(period_secs > 0 && open_time > 0)
     {
      const int bars_in_trade = (int)((TimeCurrent() - open_time) / period_secs);
      ema_exit_armed = (bars_in_trade >= strategy_ema_exit_min_bars);
     }

   if(is_long)
     {
      const bool wpr_exit = (wpr1 > strategy_wpr_ob && wpr1 < wpr2); // peaked in OB & turned down
      const bool ema_exit = (ema_exit_armed && close1 < ema_fast);   // closed back below EMA-50
      return (wpr_exit || ema_exit);
     }

   // is_short
   const bool wpr_exit = (wpr1 < strategy_wpr_os && wpr1 > wpr2);    // bottomed in OS & turned up
   const bool ema_exit = (ema_exit_armed && close1 > ema_fast);      // closed back above EMA-50
   return (wpr_exit || ema_exit);
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
