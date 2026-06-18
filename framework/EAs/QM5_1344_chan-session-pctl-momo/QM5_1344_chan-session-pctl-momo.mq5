#property strict
#property version   "5.0"
#property description "QM5_1344 Chan Session Percentile Momentum"
// Ernie Chan "Beware of Low Frequency Data" futures momentum, session-percentile port.
// SESSION = prior exchange close -> current exchange close. On DXZ the broker clock is
// NY-Close aligned (GMT+2/+3 DST), so the broker D1 bar roll IS the exchange-session
// boundary; iTime(_Symbol, PERIOD_D1, 0) marks each new session deterministically and
// DST-correctly. Percentiles are computed in-EA over the session's M1 closes (bounded,
// cached once per session roll + once per active-bar exit refresh).
//
// .DWX invariants honoured:
//  - Spread guard fail-OPEN on zero spread (only blocks a genuinely wide quoted spread).
//  - No swap gate.
//  - ONE trigger EVENT: the session-close percentile breach (>=P95 long / <=P5 short).
//    Session window + data-coverage are STATES, not triggers.
//  - Single QM_IsNewBar() consume per OnTick (entry gate); exits run pre-gate per tick.
//  - Prior CLOSE referenced (last M1 close of the finished session), never prior range.
//  - All in-EA, no ML, RISK_FIXED in tester, one position per magic.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1344;
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
// Entry percentile breach at session close (P3 sweep: 90/95/97.5).
input double strategy_entry_pctl_hi      = 95.0;
input double strategy_entry_pctl_lo      = 5.0;
// Exit percentile of the ACTIVE session's running distribution
// (P3 sweep: 55/60/65 long, 45/40/35 short).
input double strategy_exit_pctl_long     = 60.0;
input double strategy_exit_pctl_short    = 40.0;
// Catastrophic stop = mult * ATR(period, M15).
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
// Data-coverage filter: skip session if fewer than this fraction of expected M1
// bars are present (card: 90% of expected). Expected derived from session span.
input double strategy_min_bar_coverage   = 0.90;
// Spread filter: skip entries when quoted spread > this multiple of rolling median.
input double strategy_spread_med_mult    = 1.5;
// Max M1 bars to pull per session (bounds the percentile window).
input int    strategy_max_session_bars   = 2000;

// ---- cached session state (advanced once per session roll / exit refresh) ----
datetime g_session_day      = 0;     // D1 bar-open of the CURRENT active session
int      g_pending_dir      = 0;     // +1 long / -1 short / 0 none, armed at last roll
bool     g_entered_session  = false; // entry already fired this session
double   g_sl_price         = 0.0;   // cached catastrophic SL for the open position
double   g_spread_median    = 0.0;   // rolling median quoted spread (points), >0 only if real
// active-session running percentiles (refreshed per active M15 bar, cheap exit gate)
double   g_active_exit_long  = 0.0;
double   g_active_exit_short = 0.0;
bool     g_active_valid      = false;

int PctlRank(double &arr[], const int n, const double pctl)
  {
   // nearest-rank percentile on a sorted ascending array.
   int idx = (int)MathCeil((pctl / 100.0) * (double)n) - 1;
   if(idx < 0) idx = 0;
   if(idx > n - 1) idx = n - 1;
   return idx;
  }

void SortAsc(double &arr[], const int n)
  {
   // simple insertion sort; n is bounded by strategy_max_session_bars and runs
   // only on a session roll / per active M15 bar, never per tick.
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

// Collect M1 closes whose bar-open time falls in [from, to) (broker time).
// Returns count copied into out[]; out[] left sorted-ascending. expected_bars
// receives the span length in minutes (the theoretical max M1 bar count).
int CollectSessionM1(const datetime from, const datetime to, double &out[], int &expected_bars)
  {
   expected_bars = (int)((to - from) / 60);
   if(expected_bars < 1) return 0;

   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   const int got = CopyRates(_Symbol, PERIOD_M1, from, to, m1);
   if(got <= 0) return 0;

   ArrayResize(out, got);
   int n = 0;
   for(int i = 0; i < got && n < strategy_max_session_bars; ++i)
     {
      if(m1[i].time < from || m1[i].time >= to) continue;
      out[n++] = m1[i].close;
     }
   if(n <= 0) return 0;
   ArrayResize(out, n);
   SortAsc(out, n);
   return n;
  }

void UpdateSpreadMedian()
  {
   // Track a rolling median of GENUINELY quoted spreads only. .DWX quotes
   // ask==bid (0 spread) in the tester, so this stays 0 and the spread filter
   // is fail-OPEN by construction. On a live broker with real spread it arms.
   static double samples[64];
   static int    cnt = 0;
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

// Arm the next-session direction from the just-finished session, then reset
// active-session state. Called ONCE per session roll inside the new-bar gate.
void OnSessionRoll()
  {
   const datetime new_day = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prev_day = iTime(_Symbol, PERIOD_D1, 1);
   g_session_day = new_day;
   g_entered_session = false;
   g_pending_dir = 0;
   g_active_valid = false;

   if(prev_day <= 0 || new_day <= 0) return;

   double closes[];
   int expected = 0;
   const int n = CollectSessionM1(prev_day, new_day, closes, expected);
   if(n <= 0 || expected <= 0) return;
   if((double)n < strategy_min_bar_coverage * (double)expected) return;  // coverage STATE

   const double hi = closes[PctlRank(closes, n, strategy_entry_pctl_hi)];
   const double lo = closes[PctlRank(closes, n, strategy_entry_pctl_lo)];
   // last price of the finished session = the most-recent M1 close (prior CLOSE, not range)
   double recent = 0.0;
   {
      MqlRates lr[];
      ArraySetAsSeries(lr, true);
      const int g = CopyRates(_Symbol, PERIOD_M1, prev_day, new_day, lr);
      if(g > 0)
        {
         for(int i = 0; i < g; ++i)
           {
            if(lr[i].time >= prev_day && lr[i].time < new_day) { recent = lr[i].close; break; }
           }
        }
   }
   if(recent <= 0.0) return;

   // ONE trigger EVENT: the session-close percentile breach.
   if(recent >= hi)      g_pending_dir = +1;
   else if(recent <= lo) g_pending_dir = -1;
  }

// Refresh the ACTIVE session's running exit percentiles. Called once per active
// M15 bar (inside the new-bar gate) so the per-tick exit check is O(1).
void RefreshActiveExitLevels()
  {
   g_active_valid = false;
   if(g_session_day <= 0) return;
   const datetime now_bar = iTime(_Symbol, PERIOD_D1, 0);
   double closes[];
   int expected = 0;
   const int n = CollectSessionM1(g_session_day, now_bar + 86400, closes, expected);
   if(n < 2) return;
   g_active_exit_long  = closes[PctlRank(closes, n, strategy_exit_pctl_long)];
   g_active_exit_short = closes[PctlRank(closes, n, strategy_exit_pctl_short)];
   g_active_valid = true;
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

int PositionDir()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
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

// ---- No-trade filter: cheap O(1) STATE checks (spread fail-OPEN). ----
bool Strategy_NoTradeFilter()
  {
   // Spread fail-OPEN: only block a genuinely WIDE quoted spread. On .DWX
   // ask==bid so g_spread_median stays 0 and this never blocks.
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

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_pending_dir == 0) return false;
   if(g_entered_session || HasPosition()) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   QM_OrderType side;
   double entry, sl;
   if(g_pending_dir > 0)
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
   req.price              = 0.0;          // market fill at send
   req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp                 = 0.0;          // percentile / session-end exit, no fixed TP
   req.reason             = (side == QM_BUY) ? "SESS_PCTL_LONG" : "SESS_PCTL_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_sl_price        = req.sl;
   g_entered_session = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Catastrophic SL is attached to the order at open; no trailing/scaling per card.
  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;

   // Force flat at session end: the active D1 session has rolled past the one we
   // entered in (entry session armed g_session_day at its roll).
   const datetime cur_day = iTime(_Symbol, PERIOD_D1, 0);
   if(g_session_day > 0 && cur_day > g_session_day)
     {
      ClosePosition(QM_EXIT_TIME_STOP);
      return false;
     }

   if(!g_active_valid) return false;
   const double last = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(last <= 0.0) return false;

   const int dir = PositionDir();
   if(dir > 0 && last < g_active_exit_long)        // long: drop below running P60
     {
      ClosePosition(QM_EXIT_STRATEGY);
      return false;
     }
   if(dir < 0 && last > g_active_exit_short)       // short: rise above running P40
     {
      ClosePosition(QM_EXIT_STRATEGY);
      return false;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1344\",\"strategy\":\"chan-session-pctl-momo\"}");
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

   // Per-tick: manage + discretionary exit (reads cached percentile levels, O(1)).
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   // Single new-bar consume for the entry gate.
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   UpdateSpreadMedian();

   // Detect a session roll (new broker D1 bar = new exchange session) and advance
   // cached state ONCE per roll. Otherwise refresh the active-session exit levels.
   const datetime cur_day = iTime(_Symbol, PERIOD_D1, 0);
   if(cur_day != g_session_day)
      OnSessionRoll();
   else
      RefreshActiveExitLevels();

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
