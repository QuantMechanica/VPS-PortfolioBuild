#property strict
#property version   "5.0"
#property description "QM5_1346 Chan VPIN Order-Flow Momentum (tick-volume proxy)"
// Ernest Chan "How Useful is Order Flow and VPIN?" (epchan.blogspot.com, 2013-10-24).
// VPIN = volume-synchronized probability of informed trading. The source uses true
// exchange trade/order-flow buckets. On Darwinex .DWX there is NO real trade-level
// order-flow feed, so this realization is a PROXY:
//   * tick_volume per closed bar is the VOLUME proxy (number of price changes per bar,
//     NOT real traded contracts). This is the single most important caveat for the
//     reviewer / P2 calibration: VPIN computed here is a tick-activity construct, not
//     an informed-trading probability over real volume.
//   * BULK-VOLUME CLASSIFICATION: each bar's tick_volume is signed buy/sell by the
//     close-to-close price-change sign (close[i] > close[i+1] => buy bucket;
//     close[i] < close[i+1] => sell bucket; flat => split out, contributes to total
//     only). This is the deterministic VPIN-style approximation named in the card.
//   * "Volume bars" in the source are replaced by FIXED-TIME M15 bars (the signal
//     timeframe). True equal-volume bars are non-deterministic on tick-volume and the
//     .DWX tester cannot reconstruct them reproducibly; time bars keep the computation
//     a deterministic closed-form (no ML, no adaptive params).
//
// Mechanik (per card):
//   Entry: VPIN over last N bars >= its rolling P_hi percentile AND signed flow != 0.
//          flow>0 => long, flow<0 => short. ONE trigger EVENT (the percentile breach
//          on a fresh closed bar); flow sign + percentile band are STATES.
//   Exit:  after HOLD bars, OR flow flips while VPIN still >= rolling P_lo percentile.
//          Force flat at session end (broker D1 roll) for intraday symbols.
//   Stop:  0.75 * ATR(14, M15) catastrophic. No averaging; one position per magic.
//
// .DWX invariants honoured:
//   - Spread guard fail-OPEN on zero spread (only blocks a genuinely WIDE quoted spread).
//   - No swap gate.
//   - Broker time only; intraday session boundary via iTime(_Symbol, PERIOD_D1) roll
//     (DXZ NY-Close D1 bar = exchange session, DST-correct).
//   - Single QM_IsNewBar() consume per OnTick (entry gate); exits run pre-gate per tick.
//   - Prior CLOSE referenced for flow classification, never prior range.
//   - All math in-EA, no ML, RISK_FIXED in tester, one position per magic.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1346;
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
// VPIN window: number of closed bars per VPIN bucket aggregation (card "last N volume bars").
input int    strategy_vpin_window        = 50;
// Rolling-percentile history (bars) over which the VPIN entry/exit percentiles are ranked.
input int    strategy_pctl_history       = 200;
// Entry percentile of VPIN (card: 90th; P3 sweep 80/90/95).
input double strategy_entry_pctl         = 90.0;
// Exit "VPIN still elevated" percentile (card: 75th).
input double strategy_exit_pctl          = 75.0;
// Hold horizon in bars (card: exit after 3 bars; P3 sweep 1/3/5).
input int    strategy_hold_bars          = 3;
// Catastrophic stop = mult * ATR(period, signal TF). Card: 0.75 * ATR(14).
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 0.75;
// Force flat at the broker D1 session roll (intraday discipline). Card: force flat at
// session end for intraday symbols.
input bool   strategy_session_flat       = true;
// Spread filter: skip entries when quoted spread > this multiple of rolling median.
// .DWX models 0 spread -> rolling median stays 0 -> fail-OPEN by construction.
input double strategy_spread_med_mult    = 1.5;

// ---- cached per-closed-bar state (advanced once per new bar inside the gate) ----
double   g_vpin_now        = 0.0;    // VPIN over the most recent strategy_vpin_window bars
int      g_flow_sign       = 0;      // sign of (buy_vol - sell_vol) over that window
double   g_entry_thresh    = 0.0;    // rolling P_hi of VPIN history (entry gate level)
double   g_exit_thresh     = 0.0;    // rolling P_lo of VPIN history (flow-flip "still elevated")
bool     g_state_valid     = false;  // true only when both VPIN + percentiles are computable
bool     g_breach_event    = false;  // ONE trigger EVENT: VPIN crossed >= P_hi this NEW bar
datetime g_bar_time        = 0;      // bar-open time of the last advanced closed bar
double   g_spread_median   = 0.0;    // rolling median quoted spread (points); >0 only if real

// ---- open-position bookkeeping ----
datetime g_session_day     = 0;      // D1 bar-open of the session the position was opened in
int      g_bars_held        = 0;      // closed bars elapsed since entry (for HOLD exit)
int      g_entry_flow_sign  = 0;      // flow sign captured at entry (to detect a flip)

void SortAsc(double &arr[], const int n)
  {
   // insertion sort; n bounded by strategy_pctl_history, runs once per new bar only.
   for(int i = 1; i < n; ++i)
     {
      const double key = arr[i];
      int j = i - 1;
      while(j >= 0 && arr[j] > key)
        {
         arr[j + 1] = arr[j];
         --j;
        }
      arr[j + 1] = key;
     }
  }

int PctlRank(const int n, const double pctl)
  {
   // nearest-rank percentile index on a sorted-ascending array of length n.
   int idx = (int)MathCeil((pctl / 100.0) * (double)n) - 1;
   if(idx < 0) idx = 0;
   if(idx > n - 1) idx = n - 1;
   return idx;
  }

// VPIN over the window ending at bar `end_shift` (inclusive), reading `window` bars
// of tick_volume + close from the supplied series arrays. Returns the imbalance ratio
// |buy - sell| / total and writes the flow sign into `flow_sign_out`. Returns -1.0 if
// the window is uncomputable (zero total volume / insufficient data).
double VpinAt(const MqlRates &rates[], const int got, const int end_shift,
              const int window, int &flow_sign_out)
  {
   flow_sign_out = 0;
   if(window < 2) return -1.0;
   // rates[] is series-ordered (index 0 = most recent). We need `window` bars starting
   // at end_shift, plus one older bar for the close-to-close classification reference.
   if(end_shift + window >= got) return -1.0;

   double buy_vol = 0.0, sell_vol = 0.0, total_vol = 0.0;
   for(int k = 0; k < window; ++k)
     {
      const int i = end_shift + k;            // current bar (more recent at smaller i)
      const int p = i + 1;                    // prior bar (older) for close-to-close sign
      const double v = (double)rates[i].tick_volume;   // tick-volume PROXY for real volume
      if(v <= 0.0) continue;
      total_vol += v;
      const double dc = rates[i].close - rates[p].close;   // prior CLOSE, not range
      if(dc > 0.0)      buy_vol  += v;   // bulk-volume classification: up bar -> buy bucket
      else if(dc < 0.0) sell_vol += v;   // down bar -> sell bucket; flat -> total only
     }
   if(total_vol <= 0.0) return -1.0;

   const double imbalance = buy_vol - sell_vol;
   if(imbalance > 0.0)      flow_sign_out = +1;
   else if(imbalance < 0.0) flow_sign_out = -1;
   else                     flow_sign_out = 0;
   return MathAbs(imbalance) / total_vol;
  }

// Advance all cached strategy state ONCE per new closed bar. Pulls a bounded window of
// M15 rates, computes the current VPIN + flow sign, then the rolling VPIN-percentile
// thresholds over strategy_pctl_history historical VPIN observations.
void AdvanceState_OnNewBar()
  {
   g_state_valid  = false;
   g_breach_event = false;

   const int window  = MathMax(2, strategy_vpin_window);
   const int history = MathMax(20, strategy_pctl_history);
   // Need: history VPIN observations, each over `window` bars, each needing one older
   // bar for classification => history + window + 2 bars of rates.
   const int need = history + window + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int got = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need, rates); // perf-allowed: bounded once-per-new-bar VPIN window read (gated by QM_IsNewBar in OnTick).
   if(got < window + 2) return;

   // Current VPIN: the most recent fully-closed window (ends at shift 0 of rates[1..]).
   int flow_now = 0;
   const double vpin_now = VpinAt(rates, got, 0, window, flow_now);
   if(vpin_now < 0.0) return;

   // Rolling VPIN history: one VPIN observation per historical bar offset.
   double hist[];
   ArrayResize(hist, history);
   int hcount = 0;
   for(int h = 1; h <= history; ++h)   // start at 1 so "now" (h=0) is not in its own ranking
     {
      int fs = 0;
      const double vp = VpinAt(rates, got, h, window, fs);
      if(vp < 0.0) continue;
      hist[hcount++] = vp;
     }
   if(hcount < 10) return;             // not enough history to rank a percentile

   ArrayResize(hist, hcount);
   SortAsc(hist, hcount);
   const double entry_thresh = hist[PctlRank(hcount, strategy_entry_pctl)];
   const double exit_thresh  = hist[PctlRank(hcount, strategy_exit_pctl)];

   g_vpin_now     = vpin_now;
   g_flow_sign    = flow_now;
   g_entry_thresh = entry_thresh;
   g_exit_thresh  = exit_thresh;
   g_state_valid  = true;

   // ONE trigger EVENT: VPIN at/above its rolling entry percentile on THIS new bar with a
   // defined flow direction. (Percentile band membership + flow sign are STATES; the fresh
   // closed-bar evaluation is the event.)
   g_breach_event = (vpin_now >= entry_thresh && flow_now != 0);
  }

void UpdateSpreadMedian()
  {
   // Rolling median of GENUINELY quoted spreads only. .DWX quotes ask==bid (0 spread) in
   // the tester, so this stays 0 and the spread filter is fail-OPEN by construction.
   static double samples[64];
   static int    cnt  = 0;
   static int    head = 0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask <= bid)
     {
      g_spread_median = 0.0;
      return;
     }
   const double sp_pts = (ask - bid) / point;
   samples[head] = sp_pts;
   head = (head + 1) % 64;
   if(cnt < 64) ++cnt;

   double tmp[64];
   for(int i = 0; i < cnt; ++i) tmp[i] = samples[i];
   SortAsc(tmp, cnt);
   g_spread_median = tmp[cnt / 2];
  }

bool HasPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

void ClosePosition(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(t, reason);
     }
  }

// ---- No Trade Filter (time, spread, news): cheap O(1) STATE checks, spread fail-OPEN. ----
bool Strategy_NoTradeFilter()
  {
   if(g_spread_median > 0.0 && strategy_spread_med_mult > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask > 0.0 && bid > 0.0 && point > 0.0 && ask > bid)
        {
         const double sp_pts = (ask - bid) / point;
         if(sp_pts > strategy_spread_med_mult * g_spread_median) return true;
        }
     }
   return false;
  }

// ---- Trade Entry: fires on the percentile-breach EVENT with a defined flow direction. ----
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_valid || !g_breach_event) return false;
   if(g_flow_sign == 0) return false;
   if(HasPosition()) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   QM_OrderType side;
   double entry, sl;
   if(g_flow_sign > 0)
     {
      side  = QM_BUY;
      entry = ask;
      sl    = entry - strategy_atr_sl_mult * atr;
     }
   else
     {
      side  = QM_SELL;
      entry = bid;
      sl    = entry + strategy_atr_sl_mult * atr;
     }

   req.type               = side;
   req.price              = 0.0;       // market fill at send
   req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp                 = 0.0;       // hold / flow-flip / session exit, no fixed TP
   req.reason             = (side == QM_BUY) ? "VPIN_FLOW_LONG" : "VPIN_FLOW_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_session_day    = iTime(_Symbol, PERIOD_D1, 0);
   g_bars_held      = 0;
   g_entry_flow_sign = g_flow_sign;
   return true;
  }

// ---- Trade Management: catastrophic SL attached at open; no trailing/scaling per card. ----
void Strategy_ManageOpenPosition()
  {
  }

// ---- Trade Close: hold horizon, flow flip while VPIN elevated, session-end flat. ----
bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;

   // Force flat at session end (broker D1 roll) for intraday symbols.
   if(strategy_session_flat && g_session_day > 0)
     {
      const datetime cur_day = iTime(_Symbol, PERIOD_D1, 0);
      if(cur_day > g_session_day)
        {
         ClosePosition(QM_EXIT_TIME_STOP);
         return false;
        }
     }

   if(!g_state_valid) return false;

   // Hold horizon: exit after strategy_hold_bars closed bars.
   if(strategy_hold_bars > 0 && g_bars_held >= strategy_hold_bars)
     {
      ClosePosition(QM_EXIT_TIME_STOP);
      return false;
     }

   // Flow flip while VPIN remains elevated (>= rolling exit percentile).
   if(g_entry_flow_sign != 0 && g_flow_sign != 0 &&
      g_flow_sign != g_entry_flow_sign && g_vpin_now >= g_exit_thresh)
     {
      ClosePosition(QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1346\",\"strategy\":\"chan-vpin-flow-momo\"}");
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

   if(Strategy_NoTradeFilter()) return;

   // Per-tick: manage + discretionary exit (reads cached state, O(1)).
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   // Single new-bar consume for the entry gate.
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   // Advance cached closed-bar state ONCE per new bar.
   if(HasPosition()) g_bars_held++;
   AdvanceState_OnNewBar();
   UpdateSpreadMedian();

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
