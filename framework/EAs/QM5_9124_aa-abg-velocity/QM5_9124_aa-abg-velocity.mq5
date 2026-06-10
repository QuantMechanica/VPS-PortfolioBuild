#property strict
#property version   "5.0"
#property description "QM5_9124 — Alpha-Beta-Gamma Velocity trend-following (D1)"

#include <QM/QM_Common.mqh>

// Fixed ABG constants (Stern 2021-01-21, Alpha Architect)
#define ABG_ALPHA    0.3289
#define ABG_BETA     0.0654
#define ABG_GAMMA    0.0065
#define WARMUP_BARS  120
#define SPREAD_LB    20

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9124;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 20;   // D1 ATR period for initial SL
input double strategy_sl_atr_mult        = 2.5;  // SL = mult × ATR(period, D1)
input double strategy_spread_max_mult    = 2.5;  // Block entry if spread > mult × 20d median

// --- ABG filter + spread-history state (file-scope; advanced once per closed D1 bar) ---
double g_abg_pos       = 0.0;
double g_abg_vel       = 0.0;
double g_abg_acc       = 0.0;
double g_abg_prev_vel  = 0.0;
int    g_bars_seen     = 0;
double g_spread_buf[SPREAD_LB];
int    g_spread_fill   = 0;
double g_spread_median = 0.0;

// Called ONCE per new D1 bar (from within the QM_IsNewBar gate in Strategy_EntrySignal).
void AdvanceFilter()
  {
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: single bar read for bespoke recursive ABG filter
   if(close1 <= 0.0)
      return;

   // Capture spread for 20-day rolling median
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_buf[g_spread_fill % SPREAD_LB] = spread;
   g_spread_fill++;
   if(g_spread_fill >= SPREAD_LB)
     {
      double tmp[SPREAD_LB];
      ArrayCopy(tmp, g_spread_buf, 0, 0, SPREAD_LB);
      ArraySort(tmp);
      g_spread_median = tmp[SPREAD_LB / 2];
     }

   if(g_bars_seen == 0)
     {
      g_abg_pos      = close1;
      g_abg_vel      = 0.0;
      g_abg_acc      = 0.0;
      g_abg_prev_vel = 0.0;
      g_bars_seen++;
      return;
     }

   g_abg_prev_vel = g_abg_vel;

   // Prediction step
   const double pos_pred = g_abg_pos + g_abg_vel + 0.5 * g_abg_acc;
   const double vel_pred = g_abg_vel + g_abg_acc;
   const double acc_pred = g_abg_acc;

   // Residual and update
   const double err = close1 - pos_pred;
   g_abg_pos = pos_pred + ABG_ALPHA * err;
   g_abg_vel = vel_pred + ABG_BETA  * err;
   g_abg_acc = acc_pred + 2.0 * ABG_GAMMA * err;

   g_bars_seen++;
  }

// ------------------------------------------------------------------------
// Strategy hooks
// ------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceFilter();

   if(g_bars_seen < WARMUP_BARS)
      return false;

   // Spread guard: skip entry if current spread > 2.5 × 20-day median
   if(g_spread_fill >= SPREAD_LB && g_spread_median > 0.0)
     {
      const double cur_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(cur_spread > strategy_spread_max_mult * g_spread_median)
         return false;
     }

   const bool vel_up   = (g_abg_vel > 0.0 && g_abg_prev_vel <= 0.0);
   const bool vel_down = (g_abg_vel < 0.0 && g_abg_prev_vel >= 0.0);
   if(!vel_up && !vel_down)
      return false;

   // Close any opposite position; skip if already in the signalled direction
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(vel_up   && ptype == POSITION_TYPE_SELL) { QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL); break; }
      if(vel_down && ptype == POSITION_TYPE_BUY)  { QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL); break; }
      if(vel_up   && ptype == POSITION_TYPE_BUY)  return false;
      if(vel_down && ptype == POSITION_TYPE_SELL) return false;
     }

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(vel_up)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = req.price - sl_dist;
      req.tp     = 0.0;
      req.reason = "ABG_VEL_CROSS_LONG";
     }
   else
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = req.price + sl_dist;
      req.tp     = 0.0;
      req.reason = "ABG_VEL_CROSS_SHORT";
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Initial SL is the only position management; no trail or BE on D1 trend-follow
  }

bool Strategy_ExitSignal()
  {
   // Exit long when velocity turns non-positive; exit short when non-negative
   if(g_bars_seen < 2)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_abg_vel <= 0.0) return true;
      if(ptype == POSITION_TYPE_SELL && g_abg_vel >= 0.0) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// ------------------------------------------------------------------------

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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
