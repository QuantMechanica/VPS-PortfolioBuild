#property strict
#property version   "5.0"
#property description "QM5_10649 TradingView Stochastic SLTP"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_10649 tv-stoch-sltp
// Source: TradingView "Stochastic Bot with SL/TP" (JimmyPerez) — mean-reversion,
// long-only, Stochastic(14,3,3) oversold crossover with fixed % SL/TP.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10649;
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
input int    strategy_stoch_k_period      = 14;    // %K length
input int    strategy_stoch_d_period      = 3;     // %D smoothing period
input int    strategy_stoch_slowing       = 3;     // %K smoothing
input double strategy_stoch_oversold      = 20.0;  // entry: both K & D below this
input double strategy_stoch_reversal      = 60.0;  // exit: both K & D above this
input double strategy_tp_pct              = 6.0;   // take profit, % of entry price
input double strategy_sl_pct              = 2.5;   // stop loss, % of entry price
input int    strategy_time_exit_bars      = 96;    // close after N bars if no other exit

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic — no pyramiding (card: "ignore fresh oversold
   // crosses while a long position is open").
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);

   const bool cross_up      = (k2 <= d2) && (k1 > d1);
   const bool both_oversold = (k1 < strategy_stoch_oversold) && (d1 < strategy_stoch_oversold);
   if(!(cross_up && both_oversold))
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   req.type              = QM_BUY;
   req.price              = 0.0;
   req.sl                 = QM_StopRulesNormalizePrice(_Symbol, entry_price * (1.0 - strategy_sl_pct / 100.0));
   req.tp                 = QM_StopRulesNormalizePrice(_Symbol, entry_price * (1.0 + strategy_tp_pct / 100.0));
   req.reason              = "stoch_oversold_cross";
   req.symbol_slot         = 0;
   req.expiration_seconds  = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();

   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const bool reversal_exit = (k2 >= d2) && (k1 < d1) && (k1 > strategy_stoch_reversal) && (d1 > strategy_stoch_reversal);

   const int period_sec = PeriodSeconds(PERIOD_CURRENT);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool time_exit = false;
      if(period_sec > 0)
        {
         const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
         const int      bars_elapsed = (int)((TimeCurrent() - open_time) / period_sec);
         if(bars_elapsed >= strategy_time_exit_bars)
            time_exit = true;
        }

      if(reversal_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      else if(time_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false; // handled per-ticket in Strategy_ManageOpenPosition
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
