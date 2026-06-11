#property strict
#property version   "5.0"
#property description "QM5_11701 FSR TRIX(14) H1 Zero-Line Cross"

#include <QM/QM_Common.mqh>

// =============================================================================
// Strategy: FSR TRIX(14) H1 Zero-Line Cross
// Card: QM5_11701_fsr-trix14-zerolinecross
// Source: 30796091-5c65-5467-9f28-77d938217c26
//
// Entry: TRIX(14,H1) crosses from <=0 to >0 → LONG; from >=0 to <0 → SHORT.
// Exit:  SL=2xATR(14,H1), TP=4xATR(14,H1) (2:1 R:R).
//
// TRIX implementation note: iTRIX is absent from this MT5 build. TRIX is
// computed manually as the rate-of-change of a triple-smoothed 14-period EMA.
// State is seeded from historical H1 closes in OnInit and advanced once per
// new H1 bar inside Strategy_EntrySignal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11701;
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
input int    strategy_trix_period                  = 14;   // TRIX triple-EMA smoothing period
input int    strategy_atr_period                   = 14;   // ATR period used for SL/TP sizing
input double strategy_atr_sl_mult                  = 2.0;  // SL distance = N x ATR
input double strategy_atr_tp_rr                    = 2.0;  // TP = RR x SL distance (default 2:1)

// =============================================================================
// Manual TRIX state
// No iTRIX built-in available; triple EMA maintained as file-scope state,
// seeded once in OnInit from historical bars and advanced once per new H1 bar.
// =============================================================================
double g_trix_ema1     = 0.0;   // first EMA of close
double g_trix_ema2     = 0.0;   // second EMA (EMA of ema1)
double g_trix_ema3     = 0.0;   // third EMA (EMA of ema2)
double g_trix_ema3_prv = 0.0;   // ema3 from previous bar step (for TRIX calculation)
double g_trix_prv      = 0.0;   // TRIX at bar-before-last (shift=2 equivalent)
double g_trix_cur      = 0.0;   // TRIX at last closed bar (shift=1 equivalent)
bool   g_trix_ready    = false; // true after SeedTRIX succeeds

// Seed TRIX from historical H1 closes.
// Called once from OnInit — NOT on per-tick path; iClose loops are safe here.
void SeedTRIX()
  {
   const double alpha   = 2.0 / (strategy_trix_period + 1.0);
   const int    warmup  = strategy_trix_period * 3 + 1;  // 43 bars for period=14

   // Prime all three EMAs from the oldest warm-up bar
   const double seed_c  = iClose(_Symbol, PERIOD_H1, warmup); // perf-allowed: OnInit seed only, no QM_TRIX equivalent
   if(seed_c <= 0.0)
      return;

   g_trix_ema1 = seed_c;
   g_trix_ema2 = seed_c;
   g_trix_ema3 = seed_c;

   // Walk from bar (warmup-1) down to bar 3 to converge the triple EMA
   for(int i = warmup - 1; i >= 3; i--)
     {
      const double c = iClose(_Symbol, PERIOD_H1, i); // perf-allowed: OnInit warmup loop, no QM_TRIX equivalent
      if(c <= 0.0)
         continue;
      g_trix_ema3_prv = g_trix_ema3;
      g_trix_ema1     = alpha * c + (1.0 - alpha) * g_trix_ema1;
      g_trix_ema2     = alpha * g_trix_ema1 + (1.0 - alpha) * g_trix_ema2;
      g_trix_ema3     = alpha * g_trix_ema2 + (1.0 - alpha) * g_trix_ema3;
     }

   // Advance to bar 2: gives g_trix_prv (TRIX at bar-before-last)
   const double c2 = iClose(_Symbol, PERIOD_H1, 2); // perf-allowed: OnInit seed, no QM_TRIX equivalent
   if(c2 > 0.0)
     {
      g_trix_ema3_prv = g_trix_ema3;
      g_trix_ema1     = alpha * c2 + (1.0 - alpha) * g_trix_ema1;
      g_trix_ema2     = alpha * g_trix_ema1 + (1.0 - alpha) * g_trix_ema2;
      g_trix_ema3     = alpha * g_trix_ema2 + (1.0 - alpha) * g_trix_ema3;
      if(g_trix_ema3_prv > 0.0)
         g_trix_prv = (g_trix_ema3 - g_trix_ema3_prv) / g_trix_ema3_prv * 100.0;
     }

   // Advance to bar 1: gives g_trix_cur (TRIX at last closed bar)
   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: OnInit seed, no QM_TRIX equivalent
   if(c1 > 0.0)
     {
      g_trix_ema3_prv = g_trix_ema3;
      g_trix_ema1     = alpha * c1 + (1.0 - alpha) * g_trix_ema1;
      g_trix_ema2     = alpha * g_trix_ema1 + (1.0 - alpha) * g_trix_ema2;
      g_trix_ema3     = alpha * g_trix_ema2 + (1.0 - alpha) * g_trix_ema3;
      if(g_trix_ema3_prv > 0.0)
         g_trix_cur = (g_trix_ema3 - g_trix_ema3_prv) / g_trix_ema3_prv * 100.0;
     }

   g_trix_ready = true;
  }

// Advance TRIX by one H1 bar. Called only from Strategy_EntrySignal which is
// new-bar-gated, so this executes exactly once per closed H1 bar.
// iClose shift=1: perf-allowed — single read, new-bar gated, no QM_TRIX equivalent.
void AdvanceTRIX()
  {
   const double alpha = 2.0 / (strategy_trix_period + 1.0);
   const double c     = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: shift-1, new-bar gated
   if(c <= 0.0)
      return;

   g_trix_prv      = g_trix_cur;        // shift: current → previous
   g_trix_ema3_prv = g_trix_ema3;
   g_trix_ema1     = alpha * c + (1.0 - alpha) * g_trix_ema1;
   g_trix_ema2     = alpha * g_trix_ema1 + (1.0 - alpha) * g_trix_ema2;
   g_trix_ema3     = alpha * g_trix_ema2 + (1.0 - alpha) * g_trix_ema3;

   if(g_trix_ema3_prv > 0.0)
      g_trix_cur = (g_trix_ema3 - g_trix_ema3_prv) / g_trix_ema3_prv * 100.0;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No custom session or regime filter. QM_Entry handles duplicate-position guard.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry on TRIX(14,H1) zero-line cross. Called only when QM_IsNewBar() is true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_trix_ready)
      return false;

   AdvanceTRIX(); // advance by one closed bar; updates g_trix_prv / g_trix_cur

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = atr * strategy_atr_sl_mult;
   const double tp_dist = sl_dist * strategy_atr_tp_rr;
   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Long: TRIX[prev] <= 0 AND TRIX[cur] > 0
   if(g_trix_prv <= 0.0 && g_trix_cur > 0.0)
     {
      const double ep = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type  = QM_BUY;
      req.price = ep;
      req.sl    = NormalizeDouble(ep - sl_dist, digits);
      req.tp    = NormalizeDouble(ep + tp_dist, digits);
      return true;
     }

   // Short: TRIX[prev] >= 0 AND TRIX[cur] < 0
   if(g_trix_prv >= 0.0 && g_trix_cur < 0.0)
     {
      const double ep = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type  = QM_SELL;
      req.price = ep;
      req.sl    = NormalizeDouble(ep + sl_dist, digits);
      req.tp    = NormalizeDouble(ep - tp_dist, digits);
      return true;
     }

   return false;
  }

// No active position management; SL/TP handles exit.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP is the only exit mechanism.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   SeedTRIX();
   if(!g_trix_ready)
     {
      QM_LogEvent(QM_ERROR, "INIT_FAIL", "{\"reason\":\"trix_seed_failed\"}");
      return INIT_FAILED;
     }

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
