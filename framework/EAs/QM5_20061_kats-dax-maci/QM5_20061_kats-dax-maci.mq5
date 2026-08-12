#property strict
#property version   "5.0"
#property description "QM5_20061 kats-dax-maci — Katsanos DAX CI-regime MA/Stochastic (Intermarket Trading Strategies, 2008, Ch.13/Appendix A.4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20061_kats-dax-maci
// Source: Katsanos, "Intermarket Trading Strategies" (Wiley, 2008), Ch.13
// pp.209-213 / Table 13.2 p.210 / Appendix A.4 p.329. Card:
// D:\QM\strategy_farm\artifacts\cards_approved\QM5_20061_kats-dax-maci.md
//
// Daily Congestion-Index (CI) regime switch: CI>30 (or <-30) activates
// asymmetric fast/slow MA trend rules; |CI|<25 activates fast/slow
// stochastic congestion-reversal rules. Signal exits + 60-bar time exit;
// no source protective stop (QM adds a fixed ATR20x3 catastrophe stop).
//
// CI, HHV/LLV(CI,3), ROC(CI,3) and LLV/HHV(S40) are bespoke rolling-window
// math over a QM_* framework helper output with no generic corset helper
// (custom regime state, framework corset exception). All of it is computed
// exactly once per closed D1 bar in AdvanceState_OnNewBar() and cached in
// file-scope g_* state; every per-tick hook below only READS that cache.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20061;
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
// Source-locked (Appendix A.4, Table 13.2). No alpha sweep authorized by the
// G0 Card — these defaults ARE the tested rule; do not rescue via sweep.
input int    ci_roc_period          = 39;   // ROC(Close,39,%) numerator
input int    ci_range_period        = 40;   // HHV(High,40)/LLV(Low,40) denominator
input int    stoch_fast_k_period    = 5;    // S5 = Stoch(5,3) main (%K)
input int    stoch_fast_d_period    = 3;    // SMA(S5,3) == Stoch(5,3) %D (slowing=1)
input int    stoch_slow_k_period    = 40;   // S40 = Stoch(40,3) main (%K)
input int    stoch_slow_d_period    = 3;
input int    trend_long_fast_ma     = 15;   // TREND_LONG: SMA(Close,15)>SMA(Close,20)
input int    trend_long_slow_ma     = 20;
input int    trend_short_fast_ma    = 10;   // TREND_SHORT: SMA(Close,10)<SMA(Close,20)
input int    trend_short_slow_ma    = 20;
input int    trend_short_micro_ma   = 2;    // TREND_SHORT: SMA(Close,2)<SMA(Close,150)
input int    trend_short_macro_ma   = 150;
input int    macd_fast_period       = 12;   // M = EMA(Close,12)-EMA(Close,26)
input int    macd_slow_period       = 26;
input int    macd_signal_period     = 9;    // unused buffer (MT5 iMACD ctor arg only)
input int    macd_signal_ema_period = 7;    // EMA(MACD,7) for short-cover CrossUp
input int    exit_close_ema_period  = 7;    // EMA(Close,7) for short-cover confirm
input int    time_exit_bars         = 60;   // close after 60 completed D1 bars in trade
input int    catastrophe_atr_period = 20;   // QM overlay: fixed non-alpha stop
input double catastrophe_atr_mult   = 3.0;
input int    min_warmup_bars        = 200;  // >=151 required + CI/SMA150 lookback buffer

// -----------------------------------------------------------------------------
// Closed-bar cached state — advanced once per bar in AdvanceState_OnNewBar().
// Per-tick hooks (ManageOpenPosition/ExitSignal/EntrySignal) only READ this;
// none of them recompute the CI/stochastic/MACD-EMA rolling windows live.
// -----------------------------------------------------------------------------
bool   g_state_valid         = false;
double g_ci[4];                       // CI at shift 1..4 (index0 = shift1)
bool   g_ci_ok[4];
double g_s5                  = 0.0;   // Stoch(5,3) main, shift1
double g_s5_sma3             = 0.0;   // SMA(S5,3) == Stoch(5,3) %D (slowing=1), shift1
double g_s40[4];                      // Stoch(40,3) main at shift1..4 (index0 = shift1)
bool   g_s40_ok[4];
double g_sma_close_15        = 0.0;
double g_sma_close_20        = 0.0;
double g_sma_close_10        = 0.0;
double g_sma_close_2         = 0.0;
double g_sma_close_150       = 0.0;
double g_macd_1              = 0.0;   // MACD main at shift1
double g_macd_2              = 0.0;   // MACD main at shift2 (for CrossUp check)
double g_macd_ema7           = 0.0;   // recursive EMA(MACD,7), value as of shift1
double g_macd_ema7_prev      = 0.0;   // recursive EMA(MACD,7), value as of shift2
bool   g_macd_ema7_ready     = false;
bool   g_crossup_macd_ema7   = false;
double g_close_1             = 0.0;   // completed-bar close (shift1)
double g_ema_close7          = 0.0;   // EMA(Close,7) at shift1
double g_roc_ci3             = 0.0;   // ROC(CI,3,%) at shift1
bool   g_roc_ci3_valid       = false;
int    g_bars_in_position    = 0;     // completed D1 bars elapsed since entry

// -----------------------------------------------------------------------------
// ComputeCI(shift, &out_ci) — Congestion Index at a given closed-bar shift.
//   CI = ROC(Close,ci_roc_period,%) / (((HHV(High,ci_range_period)
//        -LLV(Low,ci_range_period))/(LLV(Low,ci_range_period)+0.01))+0.000001)
// HHV/LLV include the signal bar itself (shift..shift+range_period-1).
// Bespoke rolling-window math (no generic QM_* CI helper exists) — reads via
// QM_ReadBar (framework helper, not a raw iHigh/iLow/iClose call) so this
// stays corset-clean; called ONLY from AdvanceState_OnNewBar (once/bar).
// -----------------------------------------------------------------------------
bool ComputeCI(const int shift, double &out_ci)
  {
   out_ci = 0.0;
   MqlRates bar_now, bar_ago;
   if(!QM_ReadBar(_Symbol, _Period, shift, bar_now))
      return false;
   if(!QM_ReadBar(_Symbol, _Period, shift + ci_roc_period, bar_ago))
      return false;
   if(bar_ago.close <= 0.0)
      return false;

   const double roc = (bar_now.close - bar_ago.close) / bar_ago.close * 100.0;

   double hh = 0.0, ll = 0.0;
   bool first = true;
   for(int i = shift; i < shift + ci_range_period; ++i)
     {
      MqlRates b;
      if(!QM_ReadBar(_Symbol, _Period, i, b))
         return false;
      if(b.high <= 0.0 || b.low <= 0.0)
         return false;
      if(first)
        {
         hh = b.high;
         ll = b.low;
         first = false;
        }
      else
        {
         if(b.high > hh) hh = b.high;
         if(b.low  < ll) ll = b.low;
        }
     }

   const double denom = ((hh - ll) / (ll + 0.01)) + 0.000001;
   if(denom == 0.0)
      return false;

   out_ci = roc / denom;
   return MathIsValidNumber(out_ci);
  }

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar() — called once per new closed D1 bar (latched in
// OnTick below; QM_IsNewBar() is single-consume per tick so this reuses the
// same latch rather than calling QM_IsNewBar() a second time).
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_state_valid = false;

   const long available_bars = SeriesInfoInteger(_Symbol, _Period, SERIES_BARS_COUNT);
   if(available_bars < min_warmup_bars)
      return; // fail closed: source requires >=151 valid bars plus warm-up

   bool ok = true;
   for(int i = 0; i < 4; ++i)
     {
      g_ci_ok[i] = ComputeCI(i + 1, g_ci[i]);
      ok = ok && g_ci_ok[i];
     }

   g_s5      = QM_Stoch_K(_Symbol, _Period, stoch_fast_k_period, stoch_fast_d_period, 1, 1);
   g_s5_sma3 = QM_Stoch_D(_Symbol, _Period, stoch_fast_k_period, stoch_fast_d_period, 1, 1);

   for(int i = 0; i < 4; ++i)
     {
      g_s40[i]    = QM_Stoch_K(_Symbol, _Period, stoch_slow_k_period, stoch_slow_d_period, 1, i + 1);
      g_s40_ok[i] = MathIsValidNumber(g_s40[i]);
      ok = ok && g_s40_ok[i];
     }

   g_sma_close_15  = QM_SMA(_Symbol, _Period, trend_long_fast_ma,   1, PRICE_CLOSE);
   g_sma_close_20  = QM_SMA(_Symbol, _Period, trend_long_slow_ma,   1, PRICE_CLOSE);
   g_sma_close_10  = QM_SMA(_Symbol, _Period, trend_short_fast_ma,  1, PRICE_CLOSE);
   g_sma_close_2   = QM_SMA(_Symbol, _Period, trend_short_micro_ma, 1, PRICE_CLOSE);
   g_sma_close_150 = QM_SMA(_Symbol, _Period, trend_short_macro_ma, 1, PRICE_CLOSE);

   g_macd_1 = QM_MACD_Main(_Symbol, _Period, macd_fast_period, macd_slow_period, macd_signal_period, 1);
   g_macd_2 = QM_MACD_Main(_Symbol, _Period, macd_fast_period, macd_slow_period, macd_signal_period, 2);

   const double alpha = 2.0 / ((double)macd_signal_ema_period + 1.0);
   g_macd_ema7_prev = g_macd_ema7_ready ? g_macd_ema7 : g_macd_1;
   g_macd_ema7      = g_macd_ema7_ready
                       ? (alpha * g_macd_1 + (1.0 - alpha) * g_macd_ema7_prev)
                       : g_macd_1;
   g_macd_ema7_ready = true;

   g_crossup_macd_ema7 = (g_macd_2 <= g_macd_ema7_prev) && (g_macd_1 > g_macd_ema7);

   g_ema_close7 = QM_EMA(_Symbol, _Period, exit_close_ema_period, 1, PRICE_CLOSE);

   MqlRates bar1;
   if(QM_ReadBar(_Symbol, _Period, 1, bar1))
      g_close_1 = bar1.close;
   else
      ok = false;

   g_roc_ci3_valid = g_ci_ok[0] && g_ci_ok[3] && (MathAbs(g_ci[3]) > 1e-9);
   g_roc_ci3        = g_roc_ci3_valid ? ((g_ci[0] - g_ci[3]) / g_ci[3] * 100.0) : 0.0;

   ok = ok && MathIsValidNumber(g_s5) && MathIsValidNumber(g_s5_sma3)
           && MathIsValidNumber(g_sma_close_15) && MathIsValidNumber(g_sma_close_20)
           && MathIsValidNumber(g_sma_close_10) && MathIsValidNumber(g_sma_close_2)
           && MathIsValidNumber(g_sma_close_150) && MathIsValidNumber(g_macd_1)
           && MathIsValidNumber(g_macd_2) && MathIsValidNumber(g_ema_close7);

   // 60-bar time-stop counter: number of completed D1 bars elapsed while a
   // position has been open. Reflects position state as of BEFORE this bar's
   // own entry decision (entry, if any, fires later in the same tick).
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      g_bars_in_position++;
   else
      g_bars_in_position = 0;

   g_state_valid = ok;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Fail closed on missing warm-up or invalid indicator output (card
   // Filters section). No session/spread/discretionary filter otherwise.
   if(!g_state_valid)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false; // one position per symbol/magic (source Section 7)

   const double ci1 = g_ci[0];

   const bool trend_long = (ci1 > 30.0)
                         && (g_s5 > g_s5_sma3)
                         && (g_sma_close_15 > g_sma_close_20);

   const double llv_s40_2 = MathMin(g_s40[0], g_s40[1]);
   const bool congestion_long = (MathAbs(ci1) < 25.0)
                              && (g_s5 > g_s5_sma3)
                              && (llv_s40_2 < 30.0);

   const double hhv_s40_2 = MathMax(g_s40[0], g_s40[1]);
   const bool trend_short = (ci1 < -30.0)
                          && g_roc_ci3_valid && (g_roc_ci3 < 0.0)
                          && (g_s5 < g_s5_sma3)
                          && (g_sma_close_10 < g_sma_close_20)
                          && (g_sma_close_2  < g_sma_close_150);

   const bool congestion_short = (MathAbs(ci1) < 25.0)
                               && g_roc_ci3_valid && (g_roc_ci3 < 0.0)
                               && (g_s5 < g_s5_sma3)
                               && (hhv_s40_2 > 70.0);

   const bool long_signal  = trend_long  || congestion_long;
   const bool short_signal = trend_short || congestion_short;

   if(long_signal && short_signal)
     {
      // Source defines no same-bar direction tie-break: remain flat and log.
      QM_LogEvent(QM_WARN, "AMBIGUOUS_SIGNAL_REJECT", "{}");
      return false;
     }
   if(!long_signal && !short_signal)
      return false;

   req.type  = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;

   const double entry_ref = long_signal
                             ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_ref <= 0.0)
      return false;

   // QM interpretation #5: proposed non-alpha catastrophe stop, fixed
   // ATR(20)x3.0 from entry, never widened (source has no protective stop).
   req.sl = QM_StopATR(_Symbol, req.type, entry_ref, catastrophe_atr_period, catastrophe_atr_mult);
   if(req.sl <= 0.0)
      return false; // fail closed: ATR unavailable

   req.tp                = 0.0; // source: signal + time exits only, no TP
   req.reason             = long_signal ? "CI_LONG_TREND_OR_CONGESTION" : "CI_SHORT_TREND_OR_CONGESTION";
   req.symbol_slot        = 0;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source Section 7: no scale-in, partial close, break-even move, or
   // trailing alpha stop. Position lifecycle is the server-side catastrophe
   // stop (set at entry) plus the signal/time exit evaluated in ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return false;

   bool is_long = false;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   const double ci1       = g_ci[0];
   const double hhv_ci3    = MathMax(g_ci[0], MathMax(g_ci[1], g_ci[2]));
   const double llv_ci3    = MathMin(g_ci[0], MathMin(g_ci[1], g_ci[2]));
   const double hhv_s40_4  = MathMax(MathMax(g_s40[0], g_s40[1]), MathMax(g_s40[2], g_s40[3]));

   if(is_long)
     {
      if((hhv_ci3 - ci1) > 40.0)
         return true;
      if(MathAbs(ci1) < 20.0 && (g_s5 < g_s5_sma3) && (hhv_s40_4 > 85.0) && (g_s40[0] < 75.0))
         return true;
     }
   else
     {
      if((llv_ci3 - ci1) < -40.0)
         return true;
      if(g_crossup_macd_ema7 && (g_close_1 > g_ema_close7))
         return true;
     }

   // Source 60-bar time exit — lowest exit precedence, checked last.
   if(g_bars_in_position >= time_exit_bars)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2/QM_NewsAllowsTrade (entry-only, wired in OnTick)
  }

// -----------------------------------------------------------------------------
// Framework wiring — modified from EA_Skeleton.mq5: QM_IsNewBar() is latched
// ONCE (single-consume per tick) so AdvanceState_OnNewBar() can advance the
// CI/stochastic/MACD-EMA cache before ManageOpenPosition/ExitSignal read it,
// without stealing the entry gate's flag (precedent: QM5_20007 2026-07-23
// fix). Every other line matches the skeleton's canonical order.
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Latch new-bar state once — QM_IsNewBar() is single-consume per tick.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
