#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — QM5_9459 Geraked Average Force Andean MACD (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9459 gk-af-aos-md
// Source: geraked/metatrader5 AFAOSMD Expert Advisor
// Strategy: M30 momentum continuation — Average Force zero-cross filtered by
//           Andean Oscillator dominance and MACD(100,200,1) slope on M30.
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9459_gk-af-aos-md.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9459;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_af_period       = 20;    // Average Force EMA period
input int    strategy_af_smooth       = 9;     // Average Force smoothing period
input int    strategy_aos_period      = 50;    // Andean Oscillator period
input int    strategy_aos_sig_period  = 9;     // Andean Oscillator signal period
input int    strategy_md_fast         = 100;   // MACD fast EMA period
input int    strategy_md_slow         = 200;   // MACD slow EMA period
input int    strategy_sl_lookback     = 7;     // Swing stop lookback bars
input double strategy_sl_dev_pts      = 60.0;  // Swing stop deviation in _Point units
input double strategy_tp_coef         = 1.0;   // TP distance = SL distance * tp_coef
input int    strategy_time_exit_bars  = 80;    // Forced exit after N M30 bars

// -----------------------------------------------------------------------------
// File-scope cached indicator state (advanced once per closed bar)
// -----------------------------------------------------------------------------

// Average Force: double-EMA of normalised bar body direction
// AF_stage1 = EMA(body_norm, af_period); AF_final = EMA(stage1, af_smooth)
// af_prev captures the bar[2] value used for the zero-cross check.
static double g_af_stage1  = 0.0;
static double g_af_final   = 0.0;
static double g_af_prev    = 0.0;

// Andean Oscillator: recursive exponential variance of bull/bear components
// Based on Pierrefeu/geraked formula: bull2 = EMA(sq(dcp_bull)+sq(dco_bull), period)
static double g_aos_bull2  = 0.0;
static double g_aos_bear2  = 0.0;
static double g_aos_bull   = 0.0;
static double g_aos_bear   = 0.0;
static double g_aos_signal = 0.0;

// Cached entry direction evaluated on each new closed bar
static int    g_entry_dir  = 0;   // +1 = LONG signal, -1 = SHORT signal, 0 = none

static bool   g_initialized = false;

// -----------------------------------------------------------------------------
// BootstrapState: warm up EMA state from historical bars
// Called once on the first new bar.  Reads bars[2..warmup+1] so AdvanceState
// can correctly advance bar[1] without double-counting.
// -----------------------------------------------------------------------------
void BootstrapState()
{
   const int warmup = MathMax(strategy_md_slow + 20,
                              strategy_aos_period * 3 + strategy_af_period * 3);
   MqlRates rates[];
   ArraySetAsSeries(rates, false); // oldest-first ordering
   // offset=2 so the bootstrap covers bar[2] through bar[warmup+1]
   const int copied = CopyRates(_Symbol, PERIOD_M30, 2, warmup, rates);

   if(copied < strategy_af_period * 2)
   {
      QM_LogEvent(QM_WARN, "BOOTSTRAP_INSUFFICIENT",
                  StringFormat("{\"bars_copied\":%d,\"min_needed\":%d}", copied, strategy_af_period * 2));
      // Proceed with zero-initialised state; will converge over live bars.
      g_initialized = true;
      return;
   }

   const double alpha_af  = 2.0 / (strategy_af_period + 1);
   const double alpha_sm  = 2.0 / (strategy_af_smooth + 1);
   const double alpha_aos = 2.0 / (strategy_aos_period + 1);
   const double alpha_sig = 2.0 / (strategy_aos_sig_period + 1);

   double af1 = 0.0, af2 = 0.0;
   double b2  = 0.0, e2  = 0.0, sig = 0.0;

   for(int i = 0; i < copied; i++)
   {
      // Average Force: normalised body direction per bar
      const double body  = rates[i].close - rates[i].open;
      const double range = rates[i].high - rates[i].low + _Point;
      af1 = alpha_af * (body / range) + (1.0 - alpha_af) * af1;
      af2 = alpha_sm * af1             + (1.0 - alpha_sm) * af2;

      // Andean Oscillator: use previous-close from adjacent bar in array
      const double c_cur  = rates[i].close;
      const double c_prev = (i > 0) ? rates[i - 1].close : rates[i].open;
      const double o_cur  = rates[i].open;

      const double dcp_bull = MathMax(c_cur - c_prev, 0.0);
      const double dco_bull = MathMax(c_cur - o_cur,  0.0);
      const double dcp_bear = MathMax(c_prev - c_cur, 0.0);
      const double dco_bear = MathMax(o_cur  - c_cur, 0.0);

      b2  = alpha_aos * (dcp_bull * dcp_bull + dco_bull * dco_bull) + (1.0 - alpha_aos) * b2;
      e2  = alpha_aos * (dcp_bear * dcp_bear + dco_bear * dco_bear) + (1.0 - alpha_aos) * e2;
      sig = alpha_sig * MathMax(MathSqrt(b2), MathSqrt(e2)) + (1.0 - alpha_sig) * sig;
   }

   g_af_stage1  = af1;
   g_af_final   = af2;
   g_af_prev    = af2;   // first AdvanceState call will move this to true bar[2] value
   g_aos_bull2  = b2;
   g_aos_bear2  = e2;
   g_aos_bull   = MathSqrt(b2);
   g_aos_bear   = MathSqrt(e2);
   g_aos_signal = sig;
   g_initialized = true;
}

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar: advance indicator state by one closed bar.
// Called exactly once per new closed bar from Strategy_EntrySignal.
// All iClose/iOpen/iHigh/iLow reads are perf-allowed: bespoke structural
// custom-indicator calculation gated by QM_IsNewBar.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
{
   if(!g_initialized)
      BootstrapState();

   const double alpha_af  = 2.0 / (strategy_af_period + 1);
   const double alpha_sm  = 2.0 / (strategy_af_smooth + 1);
   const double alpha_aos = 2.0 / (strategy_aos_period + 1);
   const double alpha_sig = 2.0 / (strategy_aos_sig_period + 1);

   // --- Average Force from bar[1] OHLC ---
   // perf-allowed: structural custom-indicator computation, inside closed-bar gate
   const double c1   = iClose(_Symbol, PERIOD_M30, 1);
   const double o1   = iOpen(_Symbol,  PERIOD_M30, 1);
   const double h1   = iHigh(_Symbol,  PERIOD_M30, 1);
   const double l1   = iLow(_Symbol,   PERIOD_M30, 1);
   const double body = c1 - o1;
   const double rng  = MathMax(h1 - l1, _Point);

   g_af_prev    = g_af_final;                          // capture bar[2]-equivalent
   g_af_stage1  = alpha_af * (body / rng) + (1.0 - alpha_af) * g_af_stage1;
   g_af_final   = alpha_sm * g_af_stage1  + (1.0 - alpha_sm) * g_af_final;

   // --- Andean Oscillator: bar[1] vs bar[2] ---
   // perf-allowed: structural custom-indicator computation, inside closed-bar gate
   const double c2       = iClose(_Symbol, PERIOD_M30, 2);
   const double dcp_bull = MathMax(c1 - c2, 0.0);
   const double dco_bull = MathMax(c1 - o1, 0.0);
   const double dcp_bear = MathMax(c2 - c1, 0.0);
   const double dco_bear = MathMax(o1 - c1, 0.0);

   g_aos_bull2 = alpha_aos * (dcp_bull * dcp_bull + dco_bull * dco_bull)
               + (1.0 - alpha_aos) * g_aos_bull2;
   g_aos_bear2 = alpha_aos * (dcp_bear * dcp_bear + dco_bear * dco_bear)
               + (1.0 - alpha_aos) * g_aos_bear2;
   g_aos_bull  = MathSqrt(g_aos_bull2);
   g_aos_bear  = MathSqrt(g_aos_bear2);
   g_aos_signal = alpha_sig * MathMax(g_aos_bull, g_aos_bear)
                + (1.0 - alpha_sig) * g_aos_signal;

   // --- MACD(100,200,1) via framework helper ---
   const double macd1 = QM_MACD_Main(_Symbol, PERIOD_M30,
                                     strategy_md_fast, strategy_md_slow, 1, 1);
   const double macd2 = QM_MACD_Main(_Symbol, PERIOD_M30,
                                     strategy_md_fast, strategy_md_slow, 1, 2);

   // --- Evaluate entry conditions ---
   const bool af_cross_up = (g_af_prev  < 0.0) && (g_af_final > 0.0);
   const bool af_cross_dn = (g_af_prev  > 0.0) && (g_af_final < 0.0);
   const bool aos_bull    = (g_aos_bull > g_aos_bear);
   const bool aos_bear    = (g_aos_bear > g_aos_bull);
   const bool macd_long   = (macd1 > 0.0) && (macd2 > 0.0) && (macd1 > macd2);
   const bool macd_short  = (macd1 < 0.0) && (macd2 < 0.0) && (macd1 < macd2);

   g_entry_dir = 0;
   if(af_cross_up && aos_bull && macd_long)  g_entry_dir =  1;
   if(af_cross_dn && aos_bear && macd_short) g_entry_dir = -1;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: no additional session or regime filter (card specifies none).
bool Strategy_NoTradeFilter()
{
   return false;
}

// Entry Signal: evaluate closed-bar conditions; build request on new entry signal.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   AdvanceState_OnNewBar();

   if(g_entry_dir == 0) return false;

   // One-position-per-magic (MultipleOpenPos=false per card)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) return false;
   }

   // Swing stop: min/max of last strategy_sl_lookback bars
   // perf-allowed: bespoke structural swing stop, inside closed-bar gate
   double sl_level;
   if(g_entry_dir == 1)
   {
      double lo = iLow(_Symbol, PERIOD_M30, 1);
      for(int j = 2; j <= strategy_sl_lookback; j++)
         lo = MathMin(lo, iLow(_Symbol, PERIOD_M30, j));
      sl_level = lo - strategy_sl_dev_pts * _Point;
   }
   else
   {
      double hi = iHigh(_Symbol, PERIOD_M30, 1);
      for(int j = 2; j <= strategy_sl_lookback; j++)
         hi = MathMax(hi, iHigh(_Symbol, PERIOD_M30, j));
      sl_level = hi + strategy_sl_dev_pts * _Point;
   }

   const double entry_px = (g_entry_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist  = MathAbs(entry_px - sl_level);
   if(sl_dist < _Point) return false;

   const double tp_dist  = sl_dist * strategy_tp_coef;
   const double tp_level = (g_entry_dir == 1) ? entry_px + tp_dist
                                               : entry_px - tp_dist;

   req.type               = (g_entry_dir == 1) ? QM_BUY : QM_SELL;
   req.price              = 0.0;      // market order
   req.sl                 = sl_level;
   req.tp                 = tp_level;
   req.reason             = (g_entry_dir == 1) ? "QM5_9459_LONG" : "QM5_9459_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

// Manage Open Position: card specifies no trailing stop or partial close.
void Strategy_ManageOpenPosition()
{
   // Hold to TP, time exit, or opposite signal — no in-trade adjustments.
}

// Exit Signal: time-based exit or opposite-signal exit.
bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time-based exit: 80 M30 bars = 80 * 1800 seconds
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if((TimeCurrent() - opened) >= (long)strategy_time_exit_bars * 1800)
         return true;

      // Opposite-signal exit (card: "Exit on opposite valid signal")
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(g_entry_dir == -1 && ptype == POSITION_TYPE_BUY)  return true;
      if(g_entry_dir ==  1 && ptype == POSITION_TYPE_SELL) return true;
   }
   return false;
}

// News Filter Hook: defer entirely to framework QM_NewsAllowsTrade.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9459_gk-af-aos-md\",\"tf\":\"M30\"}");
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
