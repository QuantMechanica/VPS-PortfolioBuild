#property strict
#property version   "5.0"
#property description "QM5_9123 Alpha Architect Triple ES 0.1325 Cross (aa-tes01325-cross)"
// Card: artifacts/cards_approved/QM5_9123_aa-tes01325-cross.md  G0 APPROVED 2026-05-19
// Source: Henry Stern, Alpha Architect, "Trend-Following Filters - Part 2/2", 2021-01-21

#include <QM/QM_Common.mqh>

// =============================================================================
// Framework inputs — do not reorder or rename; QM_FrameworkInit binds by position.
// =============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9123;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_alpha               = 0.1325; // TES fixed smoothing constant (card: alpha=0.1325)
input int    strategy_warmup_bars         = 120;    // minimum D1 bars before trading (card filter)
input int    strategy_atr_period          = 20;     // ATR period for initial SL (card: ATR(20,D1))
input double strategy_atr_sl_mult         = 2.5;    // SL multiplier (card: 2.5×ATR)
input int    strategy_spread_window       = 20;     // bars for median spread calculation (card filter)
input double strategy_spread_mult         = 2.5;    // spread filter multiplier (card: 2.5×median)

// =============================================================================
// TES state — advanced once per closed D1 bar inside AdvanceState_OnNewBar()
// =============================================================================
double g_es1           = 0.0;   // first exponential smoother ES1_t
double g_es2           = 0.0;   // second smoother ES2_t
double g_tes           = 0.0;   // triple smoother TES_t (signal line)
double g_tes_prev      = 0.0;   // TES from previous bar (for cross detection)
double g_close_cur     = 0.0;   // close of most recently processed bar
double g_close_prev    = 0.0;   // close of bar before that
bool   g_initialized   = false; // true once warmup is complete
int    g_bars_since_init = 0;

// Rolling spread history for 20-day median filter (card: skip entry if spread > 2.5×median)
double g_spread_history[20];
int    g_spread_count  = 0;

// =============================================================================
// Helpers
// =============================================================================

bool HasOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype  = POSITION_TYPE_BUY;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ptype  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }
   return false;
  }

void UpdateSpreadHistory()
  {
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0) return;
   const long sp_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_history[g_spread_count % 20] = sp_pts * pt;
   g_spread_count++;
  }

double MedianSpread()
  {
   const int n_raw = MathMin(g_spread_count, 20);
   if(n_raw <= 0) return 0.0;
   double sorted[20];
   int fill = 0;
   const int start = (g_spread_count > 20) ? (g_spread_count - 20) : 0;
   for(int j = start; j < g_spread_count && fill < 20; j++)
      sorted[fill++] = g_spread_history[j % 20];
   const int n = fill;
   // Insertion sort — O(20²), effectively O(1)
   for(int i = 1; i < n; i++)
     {
      double key = sorted[i];
      int k = i - 1;
      while(k >= 0 && sorted[k] > key) { sorted[k+1] = sorted[k]; k--; }
      sorted[k+1] = key;
     }
   return (n % 2 == 1) ? sorted[n/2] : (sorted[n/2-1] + sorted[n/2]) / 2.0;
  }

// Called once per closed D1 bar (inside QM_IsNewBar gate).
// On first call: one-time warmup from CopyRates over historical closes.
// Subsequent calls: advance the three smoothers by one bar step.
void AdvanceState_OnNewBar()
  {
   if(!g_initialized)
     {
      MqlRates rates[];
      const int n = CopyRates(_Symbol, PERIOD_D1, 1, 600, rates);
      if(n < strategy_warmup_bars) return; // not enough history — try again next bar

      // Seed all three smoothers from the oldest available bar
      g_es1 = rates[n-1].close;
      g_es2 = rates[n-1].close;
      g_tes = rates[n-1].close;
      g_close_cur  = rates[n-1].close;
      g_tes_prev   = rates[n-1].close;
      g_close_prev = rates[n-1].close;

      // Advance from second-oldest to most-recent (rates[0] = most recent closed bar)
      for(int i = n-2; i >= 0; --i)
        {
         g_tes_prev   = g_tes;
         g_close_prev = g_close_cur;
         const double c = rates[i].close;
         g_es1 = strategy_alpha * c + (1.0 - strategy_alpha) * g_es1;
         g_es2 = strategy_alpha * g_es1 + (1.0 - strategy_alpha) * g_es2;
         g_tes = strategy_alpha * g_es2 + (1.0 - strategy_alpha) * g_tes;
         g_close_cur = c;
        }

      g_bars_since_init = n;
      g_initialized = true;
      UpdateSpreadHistory(); // record spread for this initialization bar
      return;
     }

   // Regular one-step advance
   const double c = iClose(_Symbol, PERIOD_D1, 1);
   if(c <= 0.0) return;

   UpdateSpreadHistory();

   g_tes_prev   = g_tes;
   g_close_prev = g_close_cur;
   g_close_cur  = c;
   g_es1 = strategy_alpha * c + (1.0 - strategy_alpha) * g_es1;
   g_es2 = strategy_alpha * g_es1 + (1.0 - strategy_alpha) * g_es2;
   g_tes = strategy_alpha * g_es2 + (1.0 - strategy_alpha) * g_tes;
   g_bars_since_init++;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter — per-tick O(1) guard. Warmup and spread checked in EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry signal — called once per closed D1 bar (after QM_IsNewBar gate).
// Also handles TES-cross exit so same-bar flip (exit short → enter long) is possible.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Declare all locals at top — MQL5 const-after-jump scoping is fragile.
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   bool long_exit, short_exit, long_cross, short_cross;
   double atr, sl_dist, entry_pt, sl_pts, entry_lots;
   double spread_pt, cur_spread, med_spread;

   AdvanceState_OnNewBar();

   if(!g_initialized)
      return false;

   // === Exit check for any open position ===
   if(HasOurPosition(ptype, ticket))
     {
      long_exit  = (ptype == POSITION_TYPE_BUY  && g_close_cur <= g_tes);
      short_exit = (ptype == POSITION_TYPE_SELL && g_close_cur >= g_tes);
      if(long_exit || short_exit)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         // fall through to check for opposite-direction entry
        }
      else
         return false; // position still on the correct side of TES, hold
     }

   // === Spread filter (card: skip entry when spread > 2.5×20-day median) ===
   if(g_spread_count >= strategy_spread_window)
     {
      spread_pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(spread_pt > 0.0)
        {
         cur_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * spread_pt;
         med_spread = MedianSpread();
         if(med_spread > 0.0 && cur_spread > strategy_spread_mult * med_spread)
            return false;
        }
     }

   // === TES cross — card: both current AND prior bar must be on correct sides ===
   long_cross  = (g_close_cur > g_tes  && g_close_prev <= g_tes_prev);
   short_cross = (g_close_cur < g_tes  && g_close_prev >= g_tes_prev);

   if(!long_cross && !short_cross)
      return false;

   // === Build entry request ===
   atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   sl_dist   = strategy_atr_sl_mult * atr;
   entry_pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry_pt <= 0.0) return false;

   sl_pts      = sl_dist / entry_pt;
   entry_lots  = QM_LotsForRisk(_Symbol, sl_pts);
   if(entry_lots <= 0.0) return false;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.tp                 = 0.0;

   if(long_cross)
     {
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl_dist;
      req.lots   = entry_lots;
      req.reason = "TES_LONG_CROSS";
      return true;
     }

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = SymbolInfoDouble(_Symbol, SYMBOL_BID) + sl_dist;
   req.lots   = entry_lots;
   req.reason = "TES_SHORT_CROSS";
   return true;
  }

// No intra-bar position management; SL is the only hard stop.
void Strategy_ManageOpenPosition()
  {
  }

// Exit is evaluated per closed D1 bar inside Strategy_EntrySignal to allow same-bar flip.
bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
// =============================================================================

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
               "{\"ea\":\"QM5_9123_aa-tes01325-cross\",\"card\":\"ede348b4-0fa7-5be1-baa8-09e9089b67b7\"}");
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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
