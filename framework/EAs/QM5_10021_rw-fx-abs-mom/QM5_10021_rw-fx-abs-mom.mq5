#property strict
#property version   "5.0"
#property description "QM5_10021 Robot Wealth FX Absolute Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10021;
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
input int    strategy_formation_period  = 80;    // D1 bars to look back for momentum: Close[1] - Close[1+N]
input int    strategy_atr_period        = 14;    // ATR period for catastrophic stop
input double strategy_atr_sl_mult       = 2.5;   // ATR multiplier for stop distance
input int    strategy_max_spread_points = 40;    // spread filter at entry (points)

// Closed-bar cache — populated once per new D1 bar in AdvanceState_OnNewBar()
double g_cached_close_recent    = 0.0;
double g_cached_close_formation = 0.0;

// Called ONCE per new D1 bar from within the QM_IsNewBar gate in OnTick.
// Reads the two raw D1 closes needed for the abs-momentum formula — no QM_*
// helper exists for close-at-offset; using iClose with perf-allowed.
void AdvanceState_OnNewBar()
  {
   g_cached_close_recent    = iClose(_Symbol, PERIOD_D1, 1);                              // perf-allowed: abs-momentum formula requires raw D1 close
   g_cached_close_formation = iClose(_Symbol, PERIOD_D1, 1 + strategy_formation_period); // perf-allowed: abs-momentum formula requires raw D1 close at N-bar offset
  }

// No-trade filter: block entry if spread is excessive at rollover.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_pts > strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Entry signal: open long when momentum > 0, short when momentum < 0.
// Only called when QM_IsNewBar() is true (after AdvanceState_OnNewBar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_cached_close_recent <= 0.0 || g_cached_close_formation <= 0.0)
      return false;
   if(strategy_formation_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double momentum = g_cached_close_recent - g_cached_close_formation;
   if(momentum == 0.0)
      return false;

   const QM_OrderType side = (momentum > 0.0) ? QM_BUY : QM_SELL;

   // Skip if any position for this EA on this symbol is still open.
   // ExitSignal runs first on new bar; if position remains it is settling — retry next bar.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return false;
     }

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type               = side;
   req.price              = 0.0;
   req.sl                 = sl;
   req.tp                 = 0.0;
   req.reason             = (side == QM_BUY) ? "RW_FX_ABS_MOM_LONG" : "RW_FX_ABS_MOM_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No intraday position management; catastrophic SL handles drawdown.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when momentum sign has flipped relative to the open position direction.
// Called on new bar only (after AdvanceState_OnNewBar updates cache).
bool Strategy_ExitSignal()
  {
   if(g_cached_close_recent <= 0.0 || g_cached_close_formation <= 0.0)
      return false;

   const double momentum = g_cached_close_recent - g_cached_close_formation;
   if(momentum == 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(momentum > 0.0 && pos_type == POSITION_TYPE_SELL)
         return true;
      if(momentum < 0.0 && pos_type == POSITION_TYPE_BUY)
         return true;
     }
   return false;
  }

// Defer to framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
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

   g_cached_close_recent    = 0.0;
   g_cached_close_formation = 0.0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"10021\"}");
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

   // Per-tick management (no-op for abs-momentum baseline).
   Strategy_ManageOpenPosition();

   // D1 momentum signal changes only at bar close — gate all signal work here.
   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();
   QM_EquityStreamOnNewBar();

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
   if(TesterStatistics(STAT_TRADES) < 6)
      return -1e6;
   return QM_DefaultObjective();
  }
