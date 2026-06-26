#property strict
#property version   "5.0"
#property description "QM5_9262 Dual VIDYA Crossover (ba57d97a)"

#include <QM/QM_Common.mqh>

// =====================================================================
// QuantMechanica V5 Framework inputs
// =====================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9262;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                 = true;
input int    qm_friday_close_hour_broker             = 21;

input group "Stress"
input double qm_stress_reject_probability            = 0.0;

input group "Strategy"
input int    strategy_fast_cmo_period   = 9;
input int    strategy_fast_ema_period   = 12;
input int    strategy_slow_cmo_period   = 20;
input int    strategy_slow_ema_period   = 50;
input double strategy_atr_sl_mult       = 2.2;
input double strategy_rr_tp             = 2.4;
input int    strategy_atr_period        = 14;
input int    strategy_max_hold_bars     = 96;
input int    strategy_cooldown_bars     = 3;

// =====================================================================
// File-scope VIDYA state  (updated once per new H1 bar via AdvanceVIDYA)
// =====================================================================
double g_fast_vidya_curr   = 0.0;
double g_fast_vidya_prev   = 0.0;
double g_slow_vidya_curr   = 0.0;
double g_slow_vidya_prev   = 0.0;
bool   g_vidya_initialized = false;
int    g_cooldown_remaining = 0;

// =====================================================================
// VIDYA helpers
// =====================================================================

// Seed VIDYA by walking forward through 'need' historic closes.
// Called once at OnInit; O(warmup * max_period) — not per-tick.
bool InitVIDYA()
  {
   int max_cmo = MathMax(strategy_fast_cmo_period, strategy_slow_cmo_period);
   int warmup  = 300;
   int need    = warmup + max_cmo + 2;

   // perf-allowed: VIDYA is bespoke structural logic; no QM_VIDYA helper exists.
   double closes[];
   ArraySetAsSeries(closes, false);
   int copied = CopyClose(_Symbol, _Period, 1, need, closes);
   if(copied < max_cmo + 3)
      return false;

   double fast_alpha = 2.0 / (double)(strategy_fast_ema_period + 1);
   double slow_alpha = 2.0 / (double)(strategy_slow_ema_period + 1);

   double fv = closes[0];
   double sv = closes[0];

   for(int i = max_cmo; i < copied; ++i)
     {
      double fu = 0.0, fd = 0.0;
      for(int j = i - strategy_fast_cmo_period; j < i; ++j)
        {
         double d = closes[j + 1] - closes[j];
         if(d > 0.0) fu += d; else fd -= d;
        }
      double fdenom = fu + fd;
      double fast_cmo = (fdenom > 0.0) ? 100.0 * (fu - fd) / fdenom : 0.0;

      double su = 0.0, sd = 0.0;
      for(int j = i - strategy_slow_cmo_period; j < i; ++j)
        {
         double d = closes[j + 1] - closes[j];
         if(d > 0.0) su += d; else sd -= d;
        }
      double sdenom = su + sd;
      double slow_cmo = (sdenom > 0.0) ? 100.0 * (su - sd) / sdenom : 0.0;

      g_fast_vidya_prev = fv;
      g_slow_vidya_prev = sv;

      double fk = MathAbs(fast_cmo) / 100.0;
      double sk = MathAbs(slow_cmo) / 100.0;
      fv = fast_alpha * fk * closes[i] + (1.0 - fast_alpha * fk) * fv;
      sv = slow_alpha * sk * closes[i] + (1.0 - slow_alpha * sk) * sv;
     }

   g_fast_vidya_curr = fv;
   g_slow_vidya_curr = sv;
   return true;
  }

// Called once per new bar before ExitSignal and EntrySignal.
// Updates g_fast/slow_vidya_prev/curr and decrements the cooldown.
void AdvanceVIDYA()
  {
   if(g_cooldown_remaining > 0)
      g_cooldown_remaining--;

   if(!g_vidya_initialized)
     {
      g_vidya_initialized = InitVIDYA();
      return;
     }

   int max_cmo = MathMax(strategy_fast_cmo_period, strategy_slow_cmo_period);
   int need    = max_cmo + 2;

   // perf-allowed: bespoke VIDYA CMO; CopyClose bounded to max_cmo+2 bars per new bar only.
   double closes[];
   ArraySetAsSeries(closes, true);
   int copied = CopyClose(_Symbol, _Period, 1, need, closes);
   if(copied < need)
      return;

   g_fast_vidya_prev = g_fast_vidya_curr;
   g_slow_vidya_prev = g_slow_vidya_curr;

   double fu = 0.0, fd = 0.0;
   for(int j = 0; j < strategy_fast_cmo_period; ++j)
     {
      double d = closes[j] - closes[j + 1];
      if(d > 0.0) fu += d; else fd -= d;
     }
   double fdenom = fu + fd;
   double fast_cmo = (fdenom > 0.0) ? 100.0 * (fu - fd) / fdenom : 0.0;

   double su = 0.0, sd = 0.0;
   for(int j = 0; j < strategy_slow_cmo_period; ++j)
     {
      double d = closes[j] - closes[j + 1];
      if(d > 0.0) su += d; else sd -= d;
     }
   double sdenom = su + sd;
   double slow_cmo = (sdenom > 0.0) ? 100.0 * (su - sd) / sdenom : 0.0;

   double fast_alpha = 2.0 / (double)(strategy_fast_ema_period + 1);
   double slow_alpha = 2.0 / (double)(strategy_slow_ema_period + 1);
   double fk = MathAbs(fast_cmo) / 100.0;
   double sk = MathAbs(slow_cmo) / 100.0;

   g_fast_vidya_curr = fast_alpha * fk * closes[0] + (1.0 - fast_alpha * fk) * g_fast_vidya_curr;
   g_slow_vidya_curr = slow_alpha * sk * closes[0] + (1.0 - slow_alpha * sk) * g_slow_vidya_curr;
  }

// =====================================================================
// Strategy hooks
// =====================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_vidya_initialized)
      return false;
   if(g_cooldown_remaining > 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(g_fast_vidya_curr <= 0.0 || g_slow_vidya_curr <= 0.0)
      return false;

   bool fast_above_prev = g_fast_vidya_prev > g_slow_vidya_prev;
   bool fast_above_curr = g_fast_vidya_curr > g_slow_vidya_curr;

   bool long_cross  = !fast_above_prev && fast_above_curr;
   bool short_cross =  fast_above_prev && !fast_above_curr;

   if(!long_cross && !short_cross)
      return false;

   double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.price              = 0.0;

   if(long_cross)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.tp     = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_rr_tp);
      req.reason = "VIDYA_LONG_CROSS";
     }
   else
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.tp     = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_rr_tp);
      req.reason = "VIDYA_SHORT_CROSS";
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: fixed ATR stop and 2.4R TP set at entry; no trail or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!g_vidya_initialized)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool should_exit = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY  && g_fast_vidya_curr < g_slow_vidya_curr)
         should_exit = true;
      if(ptype == POSITION_TYPE_SELL && g_fast_vidya_curr > g_slow_vidya_curr)
         should_exit = true;

      // Failsafe time exit (max hold bars)
      datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      // perf-allowed: no QM bar-count helper; iBarShift is O(log N), negligible per tick
      int bars_held = iBarShift(_Symbol, _Period, pos_time, false);
      if(bars_held >= strategy_max_hold_bars)
         should_exit = true;
     }

   if(should_exit)
      g_cooldown_remaining = strategy_cooldown_bars + 1;

   return should_exit;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =====================================================================
// Framework wiring
// =====================================================================

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

   g_vidya_initialized = InitVIDYA();
   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"vidya_init\":%s}", g_vidya_initialized ? "true" : "false"));
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

   // Advance VIDYA FIRST so ExitSignal and EntrySignal see current-bar values.
   const bool new_bar = QM_IsNewBar(); // single consume
   if(new_bar)
     {
      AdvanceVIDYA();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!new_bar)
      return;

   if(!g_vidya_initialized)
      return;

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
