#property strict
#property version   "5.0"
#property description "QM5_10123 20 Day Donchian Channel Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10123 don20-break
// Strategy: 20-period Donchian Channel Breakout (daily, long-only default)
// Source: Raposa.Trade / d3c009d7-a8d6-5251-b572-4777b207c2b9
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10123;
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
input int    strategy_donchian_period        = 20;
input bool   strategy_shorts_enabled         = false;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 3.0;
input bool   strategy_use_previous_bar_channel = true;

// -----------------------------------------------------------------------------
// Per-bar Donchian state cache
// Advanced from the framework QM_IsNewBar() gate in OnTick. All strategy hooks
// read cached values (O(1)). Bounds: strategy_donchian_period iterations per bar.
// -----------------------------------------------------------------------------
static double   g_don_upper    = -DBL_MAX;
static double   g_don_lower    = DBL_MAX;
static double   g_don_close1   = 0.0;

void AdvanceDonchianState()
  {
   g_don_upper    = -DBL_MAX;
   g_don_lower    = DBL_MAX;
   g_don_close1   = 0.0;
   const int need = strategy_donchian_period + 2;
   if(Bars(_Symbol, PERIOD_D1) < need) // perf-allowed: warmup guard; called once per framework new-bar gate
      return;
   for(int s = 2; s <= strategy_donchian_period + 1; ++s)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, s); // perf-allowed: bounded Donchian window; no QM helper for N-bar extremum
      const double lo = iLow(_Symbol, PERIOD_D1, s);  // perf-allowed: bounded Donchian window; no QM helper for N-bar extremum
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
        {
         g_don_upper = -DBL_MAX;
         return;
        }
      if(hi > g_don_upper) g_don_upper = hi;
      if(lo < g_don_lower) g_don_lower = lo;
     }
   g_don_close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single shift read for signal comparison; no QM helper for raw close
  }

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(strategy_donchian_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(!strategy_use_previous_bar_channel)
      return true;
   if(g_don_upper <= 0.0 || g_don_lower <= 0.0 || g_don_upper <= g_don_lower || g_don_close1 <= 0.0)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_don_upper <= 0.0 || g_don_lower <= 0.0 || g_don_close1 <= 0.0)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   int direction = 0;
   if(g_don_close1 > g_don_upper)
      direction = 1;
   else if(strategy_shorts_enabled && g_don_close1 < g_don_lower)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY  && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.price              = 0.0;
   req.tp                 = 0.0;
   req.expiration_seconds = 0;
   req.reason             = (direction > 0) ? "QM5_10123_DON20_LONG" : "QM5_10123_DON20_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management — card specifies no BE / trail / partial
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Trade Close — exit when close[1] crosses opposite channel band
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(g_don_upper <= 0.0 || g_don_lower <= 0.0 || g_don_close1 <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_don_close1 < g_don_lower)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_don_close1 > g_don_upper)
         return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for Q09 News Impact phase)
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   AdvanceDonchianState();

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
