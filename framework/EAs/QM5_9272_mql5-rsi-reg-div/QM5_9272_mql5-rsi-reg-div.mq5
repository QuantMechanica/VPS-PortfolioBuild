#property strict
#property version   "5.0"
#property description "QM5_9272 MQL5 RSI Regular Divergence (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)"

#include <QM/QM_Common.mqh>

//=============================================================================
// QM5_9272 — RSI Regular Divergence
// Card  : QM5_9272_mql5-rsi-reg-div
// Source: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
// Logic : Regular RSI divergence on H1.  Price lower-low / higher-high while
//         RSI disagrees → reversal entry with 2R TP or opposite-swing target,
//         48-bar time exit, opposite-divergence exit.
//=============================================================================

//--- QuantMechanica V5 Framework inputs
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9272;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period        = 14;    // RSI period
input int    strategy_swing_strength    = 5;     // Bars each side to confirm swing
input int    strategy_min_sep           = 5;     // Min bars between two divergence swings
input int    strategy_max_sep           = 50;    // Max bars between two divergence swings
input int    strategy_atr_period        = 14;    // ATR period for SL computation
input double strategy_sl_atr_mult       = 0.5;   // SL buffer = max(mult*ATR, min_pts*pt)
input int    strategy_sl_min_pts        = 20;    // Minimum SL buffer in points
input double strategy_tp_r_mult         = 2.0;   // TP as R-multiple
input double strategy_rsi_div_tol       = 0.1;   // RSI line cleanliness tolerance (RSI units)
input int    strategy_time_exit_bars    = 48;    // Close position after this many H1 bars
input int    strategy_rsi_mid_lo        = 45;    // RSI midzone filter — lower bound
input int    strategy_rsi_mid_hi        = 55;    // RSI midzone filter — upper bound

//=============================================================================
// File-scope state — populated once per QM_IsNewBar() event, read every tick
//=============================================================================

static int    g_div_sig        = 0;      // +1=long, -1=short, 0=none
static double g_div_sl         = 0.0;
static double g_div_tp         = 0.0;
static bool   g_opp_div_exit   = false;  // opposite divergence → close open trade
static datetime g_pos_open_time = 0;     // position open time for 48-bar exit

//=============================================================================
// Structural helpers (all called inside QM_IsNewBar gate — perf-allowed)
//=============================================================================

// True when bar[idx] is a confirmed swing low:
//   idx - strength >= 1  (need strength more-recent bars)
//   iLow[idx+k] > iLow[idx]  for k=1..strength  (past bars higher)
//   iLow[idx-k] > iLow[idx]  for k=1..strength  (future bars higher)
bool IsSwingLow(const int idx, const int strength)
  {
   if(idx <= strength) return false;       // need strength newer bars above bar[1]
   const double lo = iLow(_Symbol, _Period, idx);  // perf-allowed: structural swing scan
   for(int k = 1; k <= strength; k++)
     {
      if(iLow(_Symbol, _Period, idx + k) <= lo) return false;  // perf-allowed
      if(iLow(_Symbol, _Period, idx - k) <= lo) return false;  // perf-allowed
     }
   return true;
  }

bool IsSwingHigh(const int idx, const int strength)
  {
   if(idx <= strength) return false;
   const double hi = iHigh(_Symbol, _Period, idx);  // perf-allowed: structural swing scan
   for(int k = 1; k <= strength; k++)
     {
      if(iHigh(_Symbol, _Period, idx + k) >= hi) return false;  // perf-allowed
      if(iHigh(_Symbol, _Period, idx - k) >= hi) return false;  // perf-allowed
     }
   return true;
  }

// Bullish RSI line clean: from older swing (s1,R1) to newer swing (s2,R2) where s1>s2.
// R2>R1 (line slopes up older→newer).  No intermediate bar RSI below the line - tol.
bool RSILineBullishClean(const int s1, const double R1,
                         const int s2, const double R2,
                         const double tol,
                         const double &rsi_cache[], const int cache_size)
  {
   const int span = s1 - s2;
   if(span <= 1) return true;
   for(int k = s2 + 1; k < s1; k++)
     {
      const double ratio    = (double)(k - s2) / (double)span;
      const double exp_rsi  = R2 + ratio * (R1 - R2);
      const double actual   = (k >= 1 && k <= cache_size) ? rsi_cache[k]
                             : QM_RSI(_Symbol, _Period, strategy_rsi_period, k);
      if(actual < exp_rsi - tol) return false;
     }
   return true;
  }

// Bearish RSI line clean: R2<R1 (line slopes down older→newer).
// No intermediate bar RSI above the line + tol.
bool RSILineBearishClean(const int s1, const double R1,
                         const int s2, const double R2,
                         const double tol,
                         const double &rsi_cache[], const int cache_size)
  {
   const int span = s1 - s2;
   if(span <= 1) return true;
   for(int k = s2 + 1; k < s1; k++)
     {
      const double ratio    = (double)(k - s2) / (double)span;
      const double exp_rsi  = R2 + ratio * (R1 - R2);
      const double actual   = (k >= 1 && k <= cache_size) ? rsi_cache[k]
                             : QM_RSI(_Symbol, _Period, strategy_rsi_period, k);
      if(actual > exp_rsi + tol) return false;
     }
   return true;
  }

// Max high and min low helpers for opposite-swing TP target
double MaxHighBetween(const int bar_a, const int bar_b)
  {
   const int lo = MathMin(bar_a, bar_b);
   const int hi = MathMax(bar_a, bar_b);
   double mx = 0.0;
   for(int k = lo; k <= hi; k++)
      mx = MathMax(mx, iHigh(_Symbol, _Period, k));  // perf-allowed: structural
   return mx;
  }

double MinLowBetween(const int bar_a, const int bar_b)
  {
   const int lo = MathMin(bar_a, bar_b);
   const int hi = MathMax(bar_a, bar_b);
   double mn = DBL_MAX;
   for(int k = lo; k <= hi; k++)
      mn = MathMin(mn, iLow(_Symbol, _Period, k));  // perf-allowed: structural
   return mn;
  }

//=============================================================================
// AdvanceState_OnNewBar — called ONCE per new closed bar (inside IsNewBar gate)
//=============================================================================

void AdvanceState_OnNewBar()
  {
   g_div_sig      = 0;
   g_div_sl       = 0.0;
   g_div_tp       = 0.0;
   g_opp_div_exit = false;

   const double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr    = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || pt <= 0.0) return;

   const double sl_buf = MathMax(strategy_sl_atr_mult * atr, strategy_sl_min_pts * pt);

   //--- Confirmed swing bar minimum: strength bars on each side, newest at bar[1]
   const int confirm_min = strategy_swing_strength + 1;
   // Scan swing2 in bars [confirm_min .. confirm_min+25]; swing1 up to +50 beyond
   const int scan_s2_max = confirm_min + 25;
   const int cache_need  = scan_s2_max + strategy_max_sep + 2;

   //--- Pre-cache RSI values to avoid repeated CopyBuffer overhead
   double rsi_cache[];
   ArrayResize(rsi_cache, cache_need + 1);
   for(int k = 1; k <= cache_need; k++)
      rsi_cache[k] = QM_RSI(_Symbol, _Period, strategy_rsi_period, k);

   //--- Check existing position type (for opposite-divergence exit detection)
   int  pos_type_int = -1;
   ulong pos_ticket  = 0;
   const int magic   = QM_FrameworkMagic();
   if(magic > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong tk = PositionGetTicket(i);
         if(!PositionSelectByTicket(tk)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         pos_type_int = (int)PositionGetInteger(POSITION_TYPE);
         pos_ticket   = tk;
         break;
        }
     }
   const bool has_pos = (pos_ticket > 0);

   //-------------------------------------------------------------------
   // Scan for bullish divergence
   //-------------------------------------------------------------------
   bool bull_found = false;
   double bull_sl  = 0.0, bull_tp = 0.0;

   for(int s2 = confirm_min; s2 <= scan_s2_max && !bull_found; s2++)
     {
      if(!IsSwingLow(s2, strategy_swing_strength)) continue;

      const double L2 = iLow(_Symbol, _Period, s2);   // perf-allowed
      const double R2 = (s2 >= 1 && s2 <= cache_need) ? rsi_cache[s2] : 0.0;

      const int s1_lo = s2 + strategy_min_sep;
      const int s1_hi = MathMin(s2 + strategy_max_sep, cache_need - 1);

      for(int s1 = s1_lo; s1 <= s1_hi && !bull_found; s1++)
        {
         if(!IsSwingLow(s1, strategy_swing_strength)) continue;

         const double L1 = iLow(_Symbol, _Period, s1);   // perf-allowed
         const double R1 = (s1 >= 1 && s1 <= cache_need) ? rsi_cache[s1] : 0.0;

         if(L2 >= L1) continue;   // need price lower low
         if(R2 <= R1) continue;   // need RSI higher low (divergence)

         // RSI midzone filter: reject only when BOTH values inside [mid_lo, mid_hi]
         const bool R1_mid = (R1 >= strategy_rsi_mid_lo && R1 <= strategy_rsi_mid_hi);
         const bool R2_mid = (R2 >= strategy_rsi_mid_lo && R2 <= strategy_rsi_mid_hi);
         if(R1_mid && R2_mid) continue;

         // RSI divergence line clean check
         if(!RSILineBullishClean(s1, R1, s2, R2, strategy_rsi_div_tol, rsi_cache, cache_need))
            continue;

         // Compute entry, SL, TP
         const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl    = L2 - sl_buf;
         const double r_dist = ask - sl;
         if(r_dist <= 0.0) continue;

         // TP: 2R or opposite swing HIGH (whichever is closer above entry)
         const double opp_high = MaxHighBetween(s2, s1);
         const double tp_2r    = ask + strategy_tp_r_mult * r_dist;
         const double tp       = (opp_high > ask && opp_high < tp_2r) ? opp_high : tp_2r;

         bull_found = true;
         bull_sl    = sl;
         bull_tp    = tp;
        }
     }

   //-------------------------------------------------------------------
   // Scan for bearish divergence
   //-------------------------------------------------------------------
   bool bear_found = false;
   double bear_sl  = 0.0, bear_tp = 0.0;

   for(int s2 = confirm_min; s2 <= scan_s2_max && !bear_found; s2++)
     {
      if(!IsSwingHigh(s2, strategy_swing_strength)) continue;

      const double H2 = iHigh(_Symbol, _Period, s2);  // perf-allowed
      const double R2 = (s2 >= 1 && s2 <= cache_need) ? rsi_cache[s2] : 0.0;

      const int s1_lo = s2 + strategy_min_sep;
      const int s1_hi = MathMin(s2 + strategy_max_sep, cache_need - 1);

      for(int s1 = s1_lo; s1 <= s1_hi && !bear_found; s1++)
        {
         if(!IsSwingHigh(s1, strategy_swing_strength)) continue;

         const double H1 = iHigh(_Symbol, _Period, s1);  // perf-allowed
         const double R1 = (s1 >= 1 && s1 <= cache_need) ? rsi_cache[s1] : 0.0;

         if(H2 <= H1) continue;   // need price higher high
         if(R2 >= R1) continue;   // need RSI lower high (divergence)

         // RSI midzone filter
         const bool R1_mid = (R1 >= strategy_rsi_mid_lo && R1 <= strategy_rsi_mid_hi);
         const bool R2_mid = (R2 >= strategy_rsi_mid_lo && R2 <= strategy_rsi_mid_hi);
         if(R1_mid && R2_mid) continue;

         // RSI divergence line clean check
         if(!RSILineBearishClean(s1, R1, s2, R2, strategy_rsi_div_tol, rsi_cache, cache_need))
            continue;

         // Compute entry, SL, TP
         const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl    = H2 + sl_buf;
         const double r_dist = sl - bid;
         if(r_dist <= 0.0) continue;

         // TP: 2R or opposite swing LOW (whichever is closer below entry)
         const double opp_low = MinLowBetween(s2, s1);
         const double tp_2r   = bid - strategy_tp_r_mult * r_dist;
         const double tp      = (opp_low < bid && opp_low > tp_2r) ? opp_low : tp_2r;

         bear_found = true;
         bear_sl    = sl;
         bear_tp    = tp;
        }
     }

   //-------------------------------------------------------------------
   // Resolve signals based on position state
   //-------------------------------------------------------------------
   if(has_pos)
     {
      // Long position + bearish div → exit signal
      if(pos_type_int == POSITION_TYPE_BUY  && bear_found) g_opp_div_exit = true;
      // Short position + bullish div → exit signal
      if(pos_type_int == POSITION_TYPE_SELL && bull_found) g_opp_div_exit = true;
      // Never re-enter while already in a position
      g_div_sig = 0;
     }
   else
     {
      if(bull_found)
        {
         g_div_sig = 1;
         g_div_sl  = bull_sl;
         g_div_tp  = bull_tp;
        }
      else if(bear_found)
        {
         g_div_sig = -1;
         g_div_sl  = bear_sl;
         g_div_tp  = bear_tp;
        }
     }
  }

//=============================================================================
// Strategy hooks
//=============================================================================

bool Strategy_NoTradeFilter()
  {
   return false; // no additional filter; framework handles spread, news, Friday close
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_div_sig == 0) return false;

   req.symbol_slot        = qm_magic_slot_offset;
   req.price              = 0.0;   // market order
   req.expiration_seconds = 0;

   if(g_div_sig > 0)
     {
      req.type   = QM_BUY;
      req.sl     = g_div_sl;
      req.tp     = g_div_tp;
      req.reason = "BULL_RSI_DIV";
     }
   else
     {
      req.type   = QM_SELL;
      req.sl     = g_div_sl;
      req.tp     = g_div_tp;
      req.reason = "BEAR_RSI_DIV";
     }
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Track position open time for 48-bar time exit; reset when no position held.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) { g_pos_open_time = 0; return; }
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      found = true;
      if(g_pos_open_time == 0)
         g_pos_open_time = (datetime)PositionGetInteger(POSITION_TIME);
     }
   if(!found) g_pos_open_time = 0;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Opposite-divergence exit (detected on new bar by AdvanceState_OnNewBar)
      if(g_opp_div_exit) return true;

      // 48-bar time exit
      const datetime open_t = (g_pos_open_time > 0) ? g_pos_open_time
                             : (datetime)PositionGetInteger(POSITION_TIME);
      const int period_secs = PeriodSeconds(_Period);
      if(period_secs > 0)
        {
         const int bars_held = (int)((TimeCurrent() - open_t) / period_secs);
         if(bars_held >= strategy_time_exit_bars) return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade in framework
  }

//=============================================================================
// Framework wiring — do NOT edit below this line
//=============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_9272\",\"ea\":\"QM5_9272_mql5-rsi-reg-div\"}");
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

   // Per-tick: manage open position (tracks open time)
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (time stop or opposite divergence)
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong tk = PositionGetTicket(i);
         if(!PositionSelectByTicket(tk)) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(tk, g_opp_div_exit ? QM_EXIT_STRATEGY : QM_EXIT_TIME_STOP);
         g_pos_open_time = 0;
        }
     }

   // Per-closed-bar: advance divergence state, then check entry
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_pos_open_time = TimeCurrent();
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
