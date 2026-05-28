#property strict
#property version   "5.0"
#property description "QM5_10076 GitHub Santiago CCI Two MA Confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10076;
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
input int    strategy_cci_period        = 14;
input int    strategy_fast_ema_period   = 10;
input int    strategy_slow_ema_period   = 60;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                = 2.0;

int  g_cci_state = 0;
int  g_ma_state = 0;
int  g_latest_ma_cross = 0;
bool g_reset_states_when_position_seen = false;

bool HasOurOpenPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

int CciZeroCrossDirection()
  {
   if(strategy_cci_period < 2)
      return 0;

   const double cci_now = QM_CCI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_cci_period, 1, PRICE_CLOSE);
   const double cci_prev = QM_CCI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_cci_period, 2, PRICE_CLOSE);
   if(cci_prev <= 0.0 && cci_now > 0.0)
      return 1;
   if(cci_prev >= 0.0 && cci_now < 0.0)
      return -1;
   return 0;
  }

int MaCrossDirection()
  {
   if(strategy_fast_ema_period < 1 || strategy_slow_ema_period < 1 ||
      strategy_fast_ema_period == strategy_slow_ema_period)
      return 0;

   const double fast_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double slow_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double fast_prev = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 2, PRICE_CLOSE);
   const double slow_prev = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 2, PRICE_CLOSE);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return 0;

   if(fast_prev <= slow_prev && fast_now > slow_now)
      return 1;
   if(fast_prev >= slow_prev && fast_now < slow_now)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved Strategy Card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int cci_cross = CciZeroCrossDirection();
   if(cci_cross != 0)
      g_cci_state = cci_cross;

   const int ma_cross = MaCrossDirection();
   g_latest_ma_cross = ma_cross;
   if(ma_cross != 0)
      g_ma_state = ma_cross;

   ENUM_POSITION_TYPE ptype;
   if(HasOurOpenPosition(ptype))
      return false;

   if(g_cci_state == 0 || g_ma_state == 0 || g_cci_state != g_ma_state)
      return false;

   req.type = (g_cci_state > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr);
   if(entry <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (req.type == QM_BUY) ? "cci_ma_state_buy" : "cci_ma_state_sell";
   g_reset_states_when_position_seen = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   if(g_reset_states_when_position_seen && HasOurOpenPosition(ptype))
     {
      g_cci_state = 0;
      g_ma_state = 0;
      g_reset_states_when_position_seen = false;
     }
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!HasOurOpenPosition(ptype))
      return false;

   const int ma_cross = MaCrossDirection();
   if(ptype == POSITION_TYPE_BUY && ma_cross < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && ma_cross > 0)
      return true;

   return false;
  }

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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
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
