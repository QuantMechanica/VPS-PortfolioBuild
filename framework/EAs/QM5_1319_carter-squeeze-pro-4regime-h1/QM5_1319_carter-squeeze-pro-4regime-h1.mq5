#property strict
#property version   "5.0"
#property description "QM5_1319 carter-squeeze-pro-4regime-h1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1319 — Carter "Squeeze Pro" 4-Regime Compression Gate (H1)
// -----------------------------------------------------------------------------
// BB(20,2.0)-in-Keltner compression with FOUR tightness regimes (Keltner mult
// 2.0/1.5/1.0/0.5 over EMA20 +/- mult*ATR10). Entry fires on the SINGLE TRIGGER
// EVENT = squeeze RELEASE (regime -> NO_SQUEEZE) coming from a MID-or-tighter
// regime that was held >= 6 bars. Direction by linear-regression momentum slope
// of (close - SMA20) over the last 20 H1 bars. Macro-bias EMA200 gate. TP scales
// with the released tier (tighter coil -> larger thrust, Carter Ch.11), SL is
// tier-uniform. Momentum-flip exit + 32-bar time stop. One entry per release;
// re-arm requires a fresh coil. All STATES; only the release is the EVENT.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1319;
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
// Indicators
input int    bb_period            = 20;     // Bollinger Band period
input double bb_dev               = 2.0;    // Bollinger Band deviation
input int    kc_ema_period        = 20;     // Keltner EMA period
input int    kc_atr_period        = 10;     // Keltner ATR period
input double kc_mult_wide         = 2.0;    // widest Keltner multiplier
input double kc_mult_mid          = 1.5;    // TTM-canonical Keltner multiplier
input double kc_mult_tight        = 1.0;    // Pro-extension tighter Keltner
input double kc_mult_very_tight   = 0.5;    // Pro-extension tightest Keltner
input int    ema_trend_period     = 200;    // macro-bias EMA
input int    mom_lookback         = 20;     // linreg momentum lookback (bars)
input int    mom_sma_period       = 20;     // SMA detrend period for momentum
// Entry gates
input int    min_regime_age       = 6;      // min bars held in regime before release qualifies
// Exit
input int    atr_exit_period      = 14;     // ATR period for SL/TP scaling
input double k_tp_very_tight      = 3.0;    // TP ATR mult on VERY_TIGHT release
input double k_tp_tight           = 2.5;    // TP ATR mult on TIGHT release
input double k_tp_mid             = 2.0;    // TP ATR mult on MID release
input double sl_atr_mult          = 1.2;    // hard SL ATR mult (tier-uniform)
input int    time_stop_bars       = 32;     // bars without TP/SL/momflip -> close
// Filters
input int    session_start_hour   = 6;      // broker-time entry window start (inclusive)
input int    session_end_hour     = 21;     // broker-time entry window end (exclusive)
input double spread_median_mult   = 1.5;    // skip if spread > mult * 20-bar median spread

// ----------------------------------------------------------------------
// Regime enum (ordered tightest-first by tier index; higher tier = tighter)
// ----------------------------------------------------------------------
#define REG_NO_SQUEEZE   0
#define REG_WIDE         1
#define REG_MID          2
#define REG_TIGHT        3
#define REG_VERY_TIGHT   4

// ----------------------------------------------------------------------
// File-scope regime state (advanced once per closed H1 bar)
// ----------------------------------------------------------------------
int  g_regime          = REG_NO_SQUEEZE;  // current regime (last closed bar)
int  g_regime_prev     = REG_NO_SQUEEZE;  // regime one bar earlier
int  g_regime_age      = 0;               // consecutive bars in current regime
int  g_prev_regime_age = 0;               // regime_age held just before this bar's change
int  g_episode_tier    = REG_NO_SQUEEZE;  // tightest tier reached in the current squeeze episode
bool g_state_inited    = false;
bool g_entry_consumed  = false;           // suppress re-entry until a fresh coil forms
int  g_release_tier    = REG_NO_SQUEEZE;  // tier classification of the just-released coil
bool g_release_event   = false;           // true on the bar a qualifying release fired
double g_mom_cached    = 0.0;             // momentum slope, recomputed once per closed bar

#define SPREAD_BUF_MAX 64
double g_spread_buf[SPREAD_BUF_MAX];
int    g_spread_idx   = 0;
int    g_spread_count = 0;

// ----------------------------------------------------------------------
// Classify the compression regime at a given closed-bar shift.
// Mutually exclusive, ordered tightest-first.
// ----------------------------------------------------------------------
int ClassifyRegime(const int shift)
  {
   const double bb_u = QM_BB_Upper(_Symbol, PERIOD_H1, bb_period, bb_dev, shift);
   const double bb_l = QM_BB_Lower(_Symbol, PERIOD_H1, bb_period, bb_dev, shift);
   const double ema  = QM_EMA(_Symbol, PERIOD_H1, kc_ema_period, shift);
   const double atr  = QM_ATR(_Symbol, PERIOD_H1, kc_atr_period, shift);
   if(bb_u <= 0 || bb_l <= 0 || ema <= 0 || atr <= 0)
      return REG_NO_SQUEEZE;

   const double vt_u = ema + kc_mult_very_tight * atr;
   const double vt_l = ema - kc_mult_very_tight * atr;
   if(bb_u < vt_u && bb_l > vt_l) return REG_VERY_TIGHT;

   const double t_u = ema + kc_mult_tight * atr;
   const double t_l = ema - kc_mult_tight * atr;
   if(bb_u < t_u && bb_l > t_l) return REG_TIGHT;

   const double m_u = ema + kc_mult_mid * atr;
   const double m_l = ema - kc_mult_mid * atr;
   if(bb_u < m_u && bb_l > m_l) return REG_MID;

   const double w_u = ema + kc_mult_wide * atr;
   const double w_l = ema - kc_mult_wide * atr;
   if(bb_u < w_u && bb_l > w_l) return REG_WIDE;

   return REG_NO_SQUEEZE;
  }

// ----------------------------------------------------------------------
// Linear-regression slope of y[i] = (close[i] - SMA20[i]) over the last
// `mom_lookback` closed H1 bars (i = shift 1 .. mom_lookback). Returns the
// slope; sign drives entry direction (TTM-momentum proxy, Carter Ch.11).
// Bounded loop (lookback bars), run once per closed bar.
// ----------------------------------------------------------------------
double MomentumSlope()
  {
   const int n = MathMax(mom_lookback, 2);
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int j = 0; j < n; j++)
     {
      const int shift = j + 1; // shift 1 = most recent closed bar
      const double c   = iClose(_Symbol, PERIOD_H1, shift);          // perf-allowed: bounded lookback, new-bar gated
      const double sma = QM_SMA(_Symbol, PERIOD_H1, mom_sma_period, shift);
      if(c <= 0 || sma <= 0) return 0.0;
      const double y = c - sma;
      // x runs oldest=0 .. newest=n-1 so a positive slope = rising detrended price
      const double x = (double)(n - 1 - j);
      sx  += x;
      sy  += y;
      sxx += x * x;
      sxy += x * y;
     }
   const double denom = (double)n * sxx - sx * sx;
   if(MathAbs(denom) < 1e-12) return 0.0;
   return ((double)n * sxy - sx * sy) / denom;
  }

// ----------------------------------------------------------------------
// Advance regime state machine by ONE closed bar. Detects qualifying
// squeeze-release events. Called once per new closed bar.
// ----------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_mom_cached = MomentumSlope();     // refresh momentum once per closed bar
   const int reg = ClassifyRegime(1); // classify the just-closed bar

   if(!g_state_inited)
     {
      g_regime        = reg;
      g_regime_prev   = reg;
      g_regime_age    = 1;
      g_episode_tier  = (reg >= REG_WIDE) ? reg : REG_NO_SQUEEZE;
      g_state_inited  = true;
      g_release_event = false;
      return;
     }

   g_release_event = false;

   if(reg == g_regime)
     {
      g_regime_age++;
     }
   else
     {
      // Regime changed this bar. Remember the age it had held.
      g_prev_regime_age = g_regime_age;
      const int from = g_regime;

      // Track the tightest tier seen in the live squeeze episode.
      if(reg >= REG_WIDE && reg > g_episode_tier)
         g_episode_tier = reg;

      // Squeeze RELEASE EVENT: now NO_SQUEEZE, came from a real coil.
      if(reg == REG_NO_SQUEEZE && from >= REG_WIDE)
        {
         // Qualify: released from MID-or-tighter (WIDE-only too loose),
         // and the coil was held at least min_regime_age bars.
         const int episode_tier = (g_episode_tier > from) ? g_episode_tier : from;
         if(from >= REG_MID && g_prev_regime_age >= min_regime_age)
           {
            g_release_event = true;
            g_release_tier  = episode_tier;
           }
         // Episode ends on release regardless of qualification.
         g_episode_tier = REG_NO_SQUEEZE;
        }

      // A fresh coil (any squeeze tier) re-arms entry capability.
      if(reg >= REG_WIDE)
         g_entry_consumed = false;

      g_regime_prev = g_regime;
      g_regime      = reg;
      g_regime_age  = 1;
     }
  }

// ----------------------------------------------------------------------
// 20-bar median spread tracking (fail-OPEN; .DWX quotes 0 spread in tester).
// ----------------------------------------------------------------------
void UpdateSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0 || ask < bid) return;
   const double sp = ask - bid;
   g_spread_buf[g_spread_idx] = sp;
   g_spread_idx = (g_spread_idx + 1) % SPREAD_BUF_MAX;
   if(g_spread_count < SPREAD_BUF_MAX) g_spread_count++;
  }

double MedianSpread()
  {
   const int n = MathMin(g_spread_count, 20);
   if(n < 5) return 0.0; // not enough samples -> fail-OPEN (no guard)
   double tmp[20];
   for(int i = 0; i < n; i++)
     {
      int idx = g_spread_idx - 1 - i;
      while(idx < 0) idx += SPREAD_BUF_MAX;
      tmp[i] = g_spread_buf[idx];
     }
   // insertion sort (n<=20)
   for(int i = 1; i < n; i++)
     {
      double key = tmp[i];
      int k = i - 1;
      while(k >= 0 && tmp[k] > key) { tmp[k+1] = tmp[k]; k--; }
      tmp[k+1] = key;
     }
   if(n % 2 == 1) return tmp[n/2];
   return 0.5 * (tmp[n/2 - 1] + tmp[n/2]);
  }

// ----------------------------------------------------------------------
// Position helpers (1-pos-per-magic, HR14)
// ----------------------------------------------------------------------
bool HasPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

double TPMultForTier(const int tier)
  {
   if(tier >= REG_VERY_TIGHT) return k_tp_very_tight;
   if(tier == REG_TIGHT)      return k_tp_tight;
   return k_tp_mid; // MID
  }

// ----------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------

// Block new entries outside the broker-time session window. Fail-OPEN spread
// guard only blocks a genuinely wide spread (never on zero spread in tester).
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(h < session_start_hour || h >= session_end_hour)
      return true; // outside entry session — observe regime, do not enter

   // Spread guard (fail-OPEN): only block if spread is real AND wide.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double med = MedianSpread();
   if(ask > 0 && bid > 0 && ask > bid && med > 0.0)
     {
      const double sp = ask - bid;
      if(sp > spread_median_mult * med)
         return true;
     }
   return false;
  }

// Entry fires on the single TRIGGER EVENT = qualifying squeeze release detected
// on the just-closed bar. Direction by momentum slope; macro bias by EMA200.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_release_event) return false;
   if(g_entry_consumed) return false;
   if(HasPosition()) return false;

   const double mom = g_mom_cached;       // refreshed once per closed bar
   if(MathAbs(mom) <= 1e-9) return false; // flat momentum -> skip

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);            // perf-allowed: single closed-bar read
   const double ema200 = QM_EMA(_Symbol, PERIOD_H1, ema_trend_period, 1);
   const double atr    = QM_ATR(_Symbol, PERIOD_H1, atr_exit_period, 1);
   if(close1 <= 0 || ema200 <= 0 || atr <= 0) return false;

   bool long_signal  = false;
   bool short_signal = false;
   if(mom > 0.0 && close1 > ema200) long_signal = true;
   else if(mom < 0.0 && close1 < ema200) short_signal = true;
   else return false; // direction/macro-bias disagree

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0) return false;

   const double k_tp = TPMultForTier(g_release_tier);
   double sl, tp;
   if(long_signal)
     {
      sl = entry - sl_atr_mult * atr;
      tp = entry + k_tp * atr;
     }
   else
     {
      sl = entry + sl_atr_mult * atr;
      tp = entry - k_tp * atr;
     }

   g_entry_consumed = true; // one entry per release episode; fresh coil re-arms

   req.type              = long_signal ? QM_BUY : QM_SELL;
   req.price             = 0.0;
   req.sl                = sl;
   req.tp                = tp;
   req.reason            = long_signal ? "SQZPRO_REL_LONG" : "SQZPRO_REL_SHORT";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP are fixed at entry (hard SL, tier-scaled TP). No trailing / BE in
   // baseline per card. Nothing to adjust per-tick.
  }

// Momentum-flip exit + time-stop on closed bars.
bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;

   const int magic = QM_FrameworkMagic();
   const double mom = g_mom_cached; // momentum-flip evaluated on closed-bar cadence

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Momentum-flip exit: reversal against the release thesis.
      if((pt == POSITION_TYPE_BUY  && mom < 0.0) ||
         (pt == POSITION_TYPE_SELL && mom > 0.0))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
        }

      // Time-stop: N H1 bars without TP/SL/momflip.
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H1));
      if(bars_held >= time_stop_bars)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
  }

// ----------------------------------------------------------------------
// Framework wiring
// ----------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1319\",\"strategy\":\"carter-squeeze-pro-4regime-h1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;

   // Per-tick spread sampling (cheap; tracks median for the fail-OPEN guard).
   UpdateSpread();

   if(Strategy_NoTradeFilter())
     {
      // Session/news/spread may block entries, but regime + exits still advance.
      Strategy_ManageOpenPosition();
      Strategy_ExitSignal();
      if(QM_IsNewBar())
        {
         AdvanceState_OnNewBar();
         QM_EquityStreamOnNewBar();
        }
      return;
     }

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(!QM_IsNewBar()) return;

   // FIRST on a new closed bar: advance the regime state machine.
   AdvanceState_OnNewBar();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
