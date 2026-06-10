#property strict
#property version   "5.0"
#property description "QM5_1642 AA Multi-Asset Cross-Sectional Momentum Thirds (ede348b4)"

#include <QM/QM_Common.mqh>

// ---------------------------------------------------------------------------
// Multi-asset universe for cross-sectional ranking.
// Each EA instance runs on one symbol; qm_magic_slot_offset must equal the
// symbol's index in UNIVERSE_SYMS[]. Slot assignment:
//   0=SP500.DWX  1=NDX.DWX  2=WS30.DWX  3=UK100.DWX  4=GDAXI.DWX
//   5=EURUSD.DWX 6=GBPUSD.DWX 7=AUDUSD.DWX 8=USDJPY.DWX 9=USDCHF.DWX
//   10=XAUUSD.DWX 11=XTIUSD.DWX
// ---------------------------------------------------------------------------
#define UNIVERSE_SIZE       12
#define MONTHLY_HIST_DEPTH  16   // ring buffer; need indices 0..12 minimum

const string UNIVERSE_SYMS[UNIVERSE_SIZE] = {
    "SP500.DWX",    // slot 0  — US S&P 500 (backtest-only)
    "NDX.DWX",      // slot 1  — US Nasdaq 100
    "WS30.DWX",     // slot 2  — US Dow 30
    "UK100.DWX",    // slot 3  — UK FTSE 100
    "GDAXI.DWX",    // slot 4  — German DAX 40
    "EURUSD.DWX",   // slot 5  — FX EUR/USD
    "GBPUSD.DWX",   // slot 6  — FX GBP/USD
    "AUDUSD.DWX",   // slot 7  — FX AUD/USD
    "USDJPY.DWX",   // slot 8  — FX USD/JPY
    "USDCHF.DWX",   // slot 9  — FX USD/CHF
    "XAUUSD.DWX",   // slot 10 — Gold
    "XTIUSD.DWX"    // slot 11 — WTI Oil
};

// ---------------------------------------------------------------------------
// Framework inputs (skeleton-compliant, all required groups present)
// ---------------------------------------------------------------------------
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                        = 1642;
input int    qm_magic_slot_offset            = 0;
input uint   qm_rng_seed                     = 42;

input group "Risk"
input double RISK_PERCENT                    = 0.0;
input double RISK_FIXED                      = 1000.0;
input double PORTFOLIO_WEIGHT                = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled         = true;
input int    qm_friday_close_hour_broker     = 21;

input group "Stress"
input double qm_stress_reject_probability    = 0.0;

input group "Strategy"
input int    strategy_roc_idx_recent  = 2;    // Ring-buffer index for ROC numerator:   Close(3)  per card
input int    strategy_roc_idx_old     = 12;   // Ring-buffer index for ROC denominator: Close(13) per card
input int    strategy_atr_period      = 20;   // ATR period for initial SL
input double strategy_atr_sl_mult     = 3.0;  // SL distance = mult x ATR(D1)
input int    strategy_max_long_slots  = 5;    // Portfolio cap on long positions
input int    strategy_max_short_slots = 5;    // Portfolio cap on short positions
input double strategy_spread_mult     = 2.5;  // Entry filter: skip if spread > mult x 20-bar avg
input int    strategy_min_monthly_bars = 14;  // Minimum complete monthly closes before trading

// ---------------------------------------------------------------------------
// Cached state — all updated once per new D1 bar inside AdvanceState_OnNewBar
// ---------------------------------------------------------------------------
double g_monthly_closes[UNIVERSE_SIZE][MONTHLY_HIST_DEPTH]; // [sym][months_ago]
int    g_monthly_count     = 0;
int    g_last_month_num    = -1;    // year*12+month last processed
int    g_target_position[UNIVERSE_SIZE];   // +1 long / 0 flat / -1 short
int    g_my_symbol_idx     = -1;
bool   g_rebalance_happened = false;

double g_spread_hist[20];
int    g_spread_idx   = 0;
bool   g_spread_ready = false;

// ---------------------------------------------------------------------------
int FindMySymbolIdx()
  {
   for(int s = 0; s < UNIVERSE_SIZE; s++)
      if(UNIVERSE_SYMS[s] == _Symbol)
         return s;
   return -1;
  }

// ---------------------------------------------------------------------------
void ComputeTargetPositions()
  {
   for(int s = 0; s < UNIVERSE_SIZE; s++)
      g_target_position[s] = 0;

   if(strategy_roc_idx_old >= MONTHLY_HIST_DEPTH)
      return;

   double roc[UNIVERSE_SIZE];
   int    valid_count = 0;
   for(int s = 0; s < UNIVERSE_SIZE; s++)
     {
      const double c_r = g_monthly_closes[s][strategy_roc_idx_recent];
      const double c_o = g_monthly_closes[s][strategy_roc_idx_old];
      if(c_r > 0.0 && c_o > 0.0)
        { roc[s] = c_r / c_o - 1.0; valid_count++; }
      else
         roc[s] = -999.0;
     }

   if(valid_count < 3) return;

   // Sort indices descending by ROC (selection sort; 12 items, O(144) max)
   int rank[UNIVERSE_SIZE];
   for(int s = 0; s < UNIVERSE_SIZE; s++) rank[s] = s;
   for(int i = 0; i < UNIVERSE_SIZE - 1; i++)
      for(int j = i + 1; j < UNIVERSE_SIZE; j++)
         if(roc[rank[j]] > roc[rank[i]])
           { const int t = rank[i]; rank[i] = rank[j]; rank[j] = t; }

   const int third   = valid_count / 3;
   const int n_long  = MathMin(third, strategy_max_long_slots);
   const int n_short = MathMin(third, strategy_max_short_slots);

   int lc = 0;
   for(int i = 0; i < UNIVERSE_SIZE && lc < n_long; i++)
     {
      const int s = rank[i];
      if(roc[s] > -999.0) { g_target_position[s] = 1; lc++; }
     }

   int sc = 0;
   for(int i = UNIVERSE_SIZE - 1; i >= 0 && sc < n_short; i--)
     {
      const int s = rank[i];
      if(roc[s] > -999.0 && g_target_position[s] != 1)
        { g_target_position[s] = -1; sc++; }
     }
  }

// ---------------------------------------------------------------------------
// Called once per new D1 bar. Detects month boundary, records monthly closes,
// recomputes cross-sectional targets when enough data is available.
// ---------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_rebalance_happened = false;

   // Spread history for entry filter
   const double sp = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_hist[g_spread_idx % 20] = sp;
   g_spread_idx++;
   if(g_spread_idx >= 20) g_spread_ready = true;

   // Month detection via broker time (no series call; TimeCurrent() is allowed)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int cur_m = dt.year * 12 + dt.mon;

   if(g_last_month_num < 0) { g_last_month_num = cur_m; return; }
   if(cur_m == g_last_month_num) return;

   g_last_month_num = cur_m;

   // Shift ring buffer (index 0 = most recent complete month)
   for(int d = MONTHLY_HIST_DEPTH - 1; d > 0; d--)
      for(int s = 0; s < UNIVERSE_SIZE; s++)
         g_monthly_closes[s][d] = g_monthly_closes[s][d-1];

   // Record bar[1] close for each universe symbol via QM_SMA(period=1) = close[1]
   for(int s = 0; s < UNIVERSE_SIZE; s++)
     {
      const double c = QM_SMA(UNIVERSE_SYMS[s], PERIOD_D1, 1, 1);
      g_monthly_closes[s][0] = (c > 0.0) ? c : g_monthly_closes[s][1];
     }

   g_monthly_count++;

   if(g_monthly_count >= strategy_min_monthly_bars)
     {
      ComputeTargetPositions();
      g_rebalance_happened = true;
      const int my_tgt = (g_my_symbol_idx >= 0) ? g_target_position[g_my_symbol_idx] : 0;
      QM_LogEvent(QM_INFO, "REBALANCE",
                  StringFormat("{\"month_count\":%d,\"my_target\":%d}", g_monthly_count, my_tgt));
     }
  }

// ---------------------------------------------------------------------------
bool SpreadOk()
  {
   if(!g_spread_ready) return true;
   double sum = 0.0;
   for(int i = 0; i < 20; i++) sum += g_spread_hist[i];
   const double avg = sum / 20.0;
   const double cur = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (cur <= strategy_spread_mult * avg);
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;  // Monthly rank signal determines all timing
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_rebalance_happened || g_my_symbol_idx < 0) return false;

   const int tgt = g_target_position[g_my_symbol_idx];
   if(tgt == 0) return false;

   // One position per magic — check none open
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return false;  // Already have a position this cycle
     }

   if(!SpreadOk()) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   const double sl_dist = strategy_atr_sl_mult * atr;
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.tp                 = 0.0;  // No TP; monthly rebalance is the time stop

   if(tgt == 1)
     {
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = bid - sl_dist;
      req.reason = "XMOM_LONG";
      return true;
     }
   // tgt == -1
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = ask + sl_dist;
   req.reason = "XMOM_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or BE; initial ATR SL set at entry is the only bracket.
  }

bool Strategy_ExitSignal()
  {
   if(!g_rebalance_happened || g_my_symbol_idx < 0) return false;

   const int tgt   = g_target_position[g_my_symbol_idx];
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const bool pos_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(tgt == 1 && pos_long)   return false;  // Still long — keep
      if(tgt == -1 && !pos_long) return false;  // Still short — keep
      return true;  // Direction changed or flat → close
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // Defer to framework 2-axis news check in OnTick
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

int OnInit()
  {
   g_my_symbol_idx = FindMySymbolIdx();
   if(g_my_symbol_idx < 0)
     {
      Print("QM5_1642 INIT_FAILED: ", _Symbol, " not in cross-sectional universe");
      return INIT_FAILED;
     }
   if(g_my_symbol_idx != qm_magic_slot_offset)
     {
      Print("QM5_1642 INIT_FAILED: universe_idx=", g_my_symbol_idx,
            " != slot_offset=", qm_magic_slot_offset, " for ", _Symbol);
      return INIT_FAILED;
     }

   // Pre-select all universe symbols so multi-symbol reads work in tester
   for(int s = 0; s < UNIVERSE_SIZE; s++)
      SymbolSelect(UNIVERSE_SYMS[s], true);

   ArrayInitialize(g_monthly_closes, 0.0);
   ArrayInitialize(g_target_position, 0);
   ArrayInitialize(g_spread_hist, 0.0);
   g_monthly_count      = 0;
   g_last_month_num     = -1;
   g_spread_idx         = 0;
   g_spread_ready       = false;
   g_rebalance_happened = false;

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
               StringFormat("{\"card\":\"ede348b4\",\"ea\":\"QM5_1642\",\"sym_idx\":%d}",
                            g_my_symbol_idx));
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

   bool news_ok = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_ok = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_ok = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_ok) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();  // no-op; SL managed by broker after entry

   if(!QM_IsNewBar()) return;

   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();  // detect month boundary, update targets

   // Monthly rebalance: exit if direction changed, then enter new target
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong tk = PositionGetTicket(i);
         if(!PositionSelectByTicket(tk)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(tk, QM_EXIT_STRATEGY);
        }
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_tk = 0;
      QM_TM_OpenPosition(req, out_tk);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
