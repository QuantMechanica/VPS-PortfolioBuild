#property strict
#property version   "5.0"
#property description "QM5_20062 Katsanos EUR/USD Volatility-Filtered MA/CI/SAR (KATSANOS-INTERMARKET-2008_S02)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20062 - Katsanos EUR/USD Volatility-Filtered MA/CI/SAR
// -----------------------------------------------------------------------------
// Card: KATSANOS-INTERMARKET-2008_S02 / variant KATS_EUR_APPENDIX_A8_GT40.
// Katsanos, "Intermarket Trading Strategies" (Wiley, 2008), Ch.17 pp.279-285 /
// Appendix A.8 p.355. D1 EUR/USD conventional comparator (no CRB/TNX):
//   MA   = SMA(Close,10)
//   FILT = StdDev(Ln(MA/MA[-1]), 20)
//   CI   = EMA(ROC(Close,39,%) / (((HHV(High,40)-LLV(Low,40))/(LLV(Low,40)+0.01))+0.000001), 7)
//   SAR  = ParabolicSAR(step=0.04, maximum=0.10)
// Long:  MA > LLV(MA,3)+0.7*FILT AND Close>SAR AND ABS(CI)>40 AND CI>LLV(CI,3)+3
// Short: MA < HHV(MA,3)-0.7*FILT AND Close<SAR AND ABS(CI)>40 AND CI<HHV(CI,3)-3
// Exit:  close below/above SAR (source signal), causal next-open submission.
// Catastrophe stop: fixed ATR(20)x3.0 from entry, never widened (QM interp #5).
// MA/FILT/CI are derived series with no framework reader; CI is an EMA of a
// bespoke Congestion Index, so both are computed ONCE per new D1 bar in
// AdvanceState_OnNewBar() and cached in file-scope g_* vars per the
// Performance Discipline caching contract. The per-tick management/exit path
// reads only the cached values.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20062;
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
input int    strategy_ma_period              = 10;    // Card Source-defined rules: MA = SMA(Close,10).
input int    strategy_pc_stddev_period       = 20;    // Card: FILT = StdDev(Ln(MA/MA[-1]),20).
input double strategy_filt_mult              = 0.7;   // Card Entry Rules: 0.7*FILT threshold.
input int    strategy_ci_roc_period          = 39;    // Card: CI_raw ROC(Close,39,%).
input int    strategy_ci_range_period        = 40;    // Card: HHV(High,40)/LLV(Low,40).
input int    strategy_ci_ema_period          = 7;      // Card: CI = EMA(CI_raw,7).
input double strategy_ci_abs_gate            = 40.0;  // Card Appendix A.8 frozen variant: ABS(CI)>40.
input double strategy_ci_turn_threshold      = 3.0;   // Card: CI turn threshold (+/-3).
input int    strategy_turn_lookback          = 3;     // Card: LLV/HHV(MA or CI, 3).
input double strategy_sar_step               = 0.04;  // Card: ParabolicSAR step.
input double strategy_sar_max                = 0.10;  // Card: ParabolicSAR maximum.
input int    strategy_catastrophe_atr_period = 20;    // Card QM interpretation #5: ATR(20).
input double strategy_catastrophe_atr_mult   = 3.0;   // Card QM interpretation #5: 3.0x ATR distance, never widened.

#define KATS_MAX_TURN_LOOKBACK 10
#define KATS_MAX_MA_SLOTS      66

// ----- Cached once-per-D1-bar signal state (AdvanceState_OnNewBar) ---------
double g_ma_current    = 0.0;
double g_ma_llv        = 0.0;
double g_ma_hhv        = 0.0;
double g_filt          = 0.0;
double g_ci_current    = 0.0;
double g_ci_llv        = 0.0;
double g_ci_hhv        = 0.0;
double g_sar_current   = 0.0;
double g_close_current = 0.0;
bool   g_state_ready   = false;

// MA = SMA(strategy_ma_period), read at shifts 1..slots_needed via the pooled
// QM_SMA handle. Derives FILT = StdDev(Ln(MA/MA[-1]), pc_period) and the
// LLV/HHV(MA, turn_lookback) window. No framework reader computes StdDev of a
// derived series, so this is bespoke math per the Framework Corset allowance.
bool KatsComputeMA(const int pc_period, const int turn_lookback,
                   double &ma_current, double &ma_llv, double &ma_hhv, double &filt)
  {
   ma_current = 0.0;
   ma_llv     = 0.0;
   ma_hhv     = 0.0;
   filt       = 0.0;

   const int clamped_pc   = (int)MathMax(2, MathMin(KATS_MAX_MA_SLOTS - 2, pc_period));
   const int clamped_turn = (int)MathMax(1, MathMin(KATS_MAX_TURN_LOOKBACK, turn_lookback));
   const int slots_needed = MathMax(clamped_pc + 1, clamped_turn);

   double ma[KATS_MAX_MA_SLOTS];
   for(int s = 1; s <= slots_needed; ++s)
     {
      ma[s] = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, s);
      if(ma[s] <= 0.0 || !MathIsValidNumber(ma[s]))
         return false;
     }

   double pc[KATS_MAX_MA_SLOTS];
   double sum = 0.0;
   for(int i = 1; i <= clamped_pc; ++i)
     {
      pc[i] = MathLog(ma[i] / ma[i + 1]);
      if(!MathIsValidNumber(pc[i]))
         return false;
      sum += pc[i];
     }
   const double mean = sum / clamped_pc;
   double sq_sum = 0.0;
   for(int i = 1; i <= clamped_pc; ++i)
      sq_sum += (pc[i] - mean) * (pc[i] - mean);
   filt = MathSqrt(sq_sum / clamped_pc);
   if(!MathIsValidNumber(filt))
      return false;

   ma_current = ma[1];
   ma_llv     = ma[1];
   ma_hhv     = ma[1];
   for(int t = 2; t <= clamped_turn; ++t)
     {
      if(ma[t] < ma_llv) ma_llv = ma[t];
      if(ma[t] > ma_hhv) ma_hhv = ma[t];
     }
   return true;
  }

// CI_raw(k) = ROC(Close,roc_period,%) / (((HHV(High,range_period)-LLV(Low,range_period))
//             / (LLV(Low,range_period)+0.01)) + 0.000001), window [k, k+range_period-1]
// inclusive of the completed signal bar per the Card's "HHV/LLV include the
// current completed signal bar" instruction. Fails closed (returns false) on
// any missing/nonfinite OHLC per Card Filters (No-Trade Module).
bool KatsCIRaw(const int k, const int roc_period, const int range_period, double &out_raw)
  {
   out_raw = 0.0;
   const double close_k   = iClose(_Symbol, PERIOD_D1, k);              // perf-allowed: bespoke Congestion Index, computed once per new D1 bar behind AdvanceState_OnNewBar.
   const double close_ref = iClose(_Symbol, PERIOD_D1, k + roc_period); // perf-allowed: see above.
   if(close_k <= 0.0 || close_ref <= 0.0)
      return false;
   const double roc = 100.0 * (close_k - close_ref) / close_ref;

   double hh = -DBL_MAX;
   double ll = DBL_MAX;
   for(int j = k; j < k + range_period; ++j)
     {
      const double h = iHigh(_Symbol, PERIOD_D1, j); // perf-allowed: bespoke Congestion Index range window, see above.
      const double l = iLow(_Symbol, PERIOD_D1, j);  // perf-allowed: see above.
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   const double denom = ((hh - ll) / (ll + 0.01)) + 0.000001;
   if(denom == 0.0)
      return false;
   out_raw = roc / denom;
   return MathIsValidNumber(out_raw);
  }

// CI = EMA(CI_raw, ema_period). No framework reader computes an EMA of a
// derived series, so the recursion is seeded (clamped_turn+20) bars back and
// walked forward to bar 1 each new-D1-bar call; alpha=2/(ema_period+1) decays
// the seed residual to well under 1% within ~20 steps, so a fixed warmup
// window is numerically equivalent to a persistent full-history EMA while
// staying restart-safe (no cross-tick recursive state to corrupt).
bool KatsComputeCI(const int roc_period, const int range_period, const int ema_period,
                   const int turn_lookback, double &ci_current, double &ci_llv, double &ci_hhv)
  {
   ci_current = 0.0;
   ci_llv     = 0.0;
   ci_hhv     = 0.0;
   if(ema_period <= 0)
      return false;

   const int clamped_turn = (int)MathMax(1, MathMin(KATS_MAX_TURN_LOOKBACK, turn_lookback));
   const int warmup_k     = clamped_turn + 20;
   const double alpha     = 2.0 / (ema_period + 1.0);

   double ci_hist[KATS_MAX_TURN_LOOKBACK];
   double ema    = 0.0;
   bool   seeded = false;
   for(int k = warmup_k; k >= 1; --k)
     {
      double raw = 0.0;
      if(!KatsCIRaw(k, roc_period, range_period, raw))
         return false;
      ema = seeded ? (alpha * raw + (1.0 - alpha) * ema) : raw;
      seeded = true;
      if(k <= clamped_turn)
         ci_hist[k - 1] = ema;
     }
   if(!seeded)
      return false;

   ci_current = ci_hist[0];
   ci_llv     = ci_hist[0];
   ci_hhv     = ci_hist[0];
   for(int t = 1; t < clamped_turn; ++t)
     {
      if(ci_hist[t] < ci_llv) ci_llv = ci_hist[t];
      if(ci_hist[t] > ci_hhv) ci_hhv = ci_hist[t];
     }
   return true;
  }

// Called once per new closed D1 bar (latched qm_new_bar in OnTick, BEFORE
// Strategy_ManageOpenPosition/Strategy_ExitSignal so their per-tick reads see
// the fresh signal-bar state). Fails closed (g_state_ready=false) on any
// invalid MA/FILT/CI/SAR output per Card Filters (No-Trade Module).
void AdvanceState_OnNewBar()
  {
   g_state_ready = false;

   double ma_current = 0.0, ma_llv = 0.0, ma_hhv = 0.0, filt = 0.0;
   if(!KatsComputeMA(strategy_pc_stddev_period, strategy_turn_lookback, ma_current, ma_llv, ma_hhv, filt))
      return;

   double ci_current = 0.0, ci_llv = 0.0, ci_hhv = 0.0;
   if(!KatsComputeCI(strategy_ci_roc_period, strategy_ci_range_period, strategy_ci_ema_period,
                     strategy_turn_lookback, ci_current, ci_llv, ci_hhv))
      return;

   const double sar_current   = QM_SAR(_Symbol, PERIOD_D1, strategy_sar_step, strategy_sar_max, 1);
   const double close_current = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: signal-bar close, cached once per new D1 bar.
   if(sar_current <= 0.0 || !MathIsValidNumber(sar_current) || close_current <= 0.0)
      return;

   g_ma_current    = ma_current;
   g_ma_llv        = ma_llv;
   g_ma_hhv        = ma_hhv;
   g_filt          = filt;
   g_ci_current    = ci_current;
   g_ci_llv        = ci_llv;
   g_ci_hhv        = ci_hhv;
   g_sar_current   = sar_current;
   g_close_current = close_current;
   g_state_ready   = true;
  }

// Card Filters (No-Trade Module): no session/carry/discretionary filter.
// Data-validity fail-closed is enforced via g_state_ready inside
// Strategy_EntrySignal (entries only) — this hook must stay false so
// Strategy_ManageOpenPosition/Strategy_ExitSignal keep running every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Card §4 Entry Rules. Reads AdvanceState_OnNewBar() cached state only;
// called once per new D1 bar (framework OnTick gates this behind the
// latched new-bar flag). Ambiguous (both directions true) -> flat + log
// reject per QM interpretation #3.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;

   const double ma_turn_long  = g_ma_llv + strategy_filt_mult * g_filt;
   const double ma_turn_short = g_ma_hhv - strategy_filt_mult * g_filt;

   const bool long_signal = (g_ma_current > ma_turn_long) &&
                            (g_close_current > g_sar_current) &&
                            (MathAbs(g_ci_current) > strategy_ci_abs_gate) &&
                            (g_ci_current > g_ci_llv + strategy_ci_turn_threshold);

   const bool short_signal = (g_ma_current < ma_turn_short) &&
                             (g_close_current < g_sar_current) &&
                             (MathAbs(g_ci_current) > strategy_ci_abs_gate) &&
                             (g_ci_current < g_ci_hhv - strategy_ci_turn_threshold);

   if(long_signal && short_signal)
     {
      // Card QM interpretation #3: simultaneous long+short states -> stay flat, log reject.
      QM_LogEvent(QM_WARN, "KATS_AMBIGUOUS_SIGNAL_REJECT",
                  StringFormat("{\"ma\":%.8f,\"close\":%.8f,\"sar\":%.8f,\"ci\":%.4f}",
                               g_ma_current, g_close_current, g_sar_current, g_ci_current));
      return false;
     }

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry_price_estimate = QM_OrderTypeIsBuy(side)
                                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price_estimate <= 0.0)
      return false;

   // Card QM interpretation #5: fixed 3.0*ATR(20) catastrophe stop from
   // entry, using ATR from the completed signal bar, never widened.
   const double sl_price = QM_StopATR(_Symbol, side, entry_price_estimate,
                                      strategy_catastrophe_atr_period,
                                      strategy_catastrophe_atr_mult);
   if(sl_price <= 0.0)
      return false;

   req.type   = side;
   req.sl     = sl_price;
   req.reason = long_signal ? "KATS_LONG_MA_CI_SAR" : "KATS_SHORT_MA_CI_SAR";
   return true;
  }

// Card §7 Trade Management Rules: no scale-in, partial close, break-even, or
// trailing. The catastrophe stop is set once at entry and never widened.
void Strategy_ManageOpenPosition()
  {
  }

// Card §5 Exit Rules: exit a long when the signal-bar close is below SAR;
// cover a short when the signal-bar close is above SAR. Runs every tick
// (not gated to new-bar) so the source exit fires at the first eligible
// tick of the next D1 bar, reading only AdvanceState_OnNewBar() cached state.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_close_current < g_sar_current)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_close_current > g_sar_current)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2/QM_NewsAllowsTrade below.
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"KATSANOS-INTERMARKET-2008_S02\",\"ea\":\"QM5_20062_kats-eu-macisar\"}");
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

   if(Strategy_NoTradeFilter())
      return;

   // Katsanos MA/FILT/CI/SAR state is derived once per completed D1 bar and
   // reused by both the per-tick management/exit path below and the entry
   // gate further down. QM_IsNewBar() is single-consume, so latch it once
   // here instead of calling it again at the entry gate (2026-07-02 audit
   // rule; QM5_20007 caching defect; Performance Discipline "Cache indicator
   // reads used in per-tick paths").
   const bool qm_new_bar = QM_IsNewBar();
   if(qm_new_bar)
      AdvanceState_OnNewBar();

   // Per-tick: trade management (no-op per Card §7, kept for framework shape).
   Strategy_ManageOpenPosition();

   // Per-tick: source SAR close-signal exit, reading cached state only.
   bool exit_fired_this_tick = false;
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
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            exit_fired_this_tick = true;
        }
     }

   // Per-closed-bar: entry-signal evaluation. News blackout gates NEW entries
   // only (2026-07-02 audit rule) — it must not sit above
   // Strategy_ManageOpenPosition/ExitSignal so the source SAR exit and the
   // ATR catastrophe stop keep enforcing through news windows.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!qm_new_bar)
      return;

   // Card "Exit precedence": never open a replacement position on the same
   // tick as a forced or source exit.
   if(exit_fired_this_tick)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
