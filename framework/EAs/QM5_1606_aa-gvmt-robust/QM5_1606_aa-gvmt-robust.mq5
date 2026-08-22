#property strict
#property version   "5.0"
#property description "QM5_1606 Alpha Architect GVMT Robust Trend Hedge"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1606 — Alpha Architect GVMT Robust Trend Hedge
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1606_aa-gvmt-robust.md
//
// At the first completed D1 bar observed in each broker-calendar month, use the
// last completed MN1 bar to blend two fixed 12-month trend signals:
//   * positive 12-month time-series momentum; and
//   * close above the 12-month simple moving average.
// Both positive => 100% of the risk budget, one positive => 50%, neither => cash.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1606;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// This card holds allocations across weeks. Weekly liquidation would change it.
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months          = 12;
input double strategy_cash_return_12m_pct      = 0.0;
input int    strategy_atr_period               = 20;
input double strategy_atr_sl_mult              = 3.0;
input double strategy_max_spread_atr_fraction  = 0.10;

int g_last_rebalance_month = -1;

int Strategy_CurrentMonthId()
{
   MqlDateTime parts;
   if(!TimeToStruct(TimeCurrent(), parts))
      return -1;
   return parts.year * 12 + parts.mon;
}

bool Strategy_HasOpenPosition()
{
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
      return true;
   }
   return false;
}

double Strategy_HeldExposure()
{
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

      const string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GVMT_FULL") >= 0)
         return 1.0;
      if(StringFind(comment, "GVMT_HALF") >= 0)
         return 0.5;
      return -1.0;
   }
   return 0.0;
}

bool Strategy_CloseOurPositions()
{
   bool ok = true;
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
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         ok = false;
   }
   return ok && !Strategy_HasOpenPosition();
}

bool Strategy_TargetExposure(double &exposure)
{
   exposure = 0.0;
   if(strategy_lookback_months < 1)
      return false;
   if(Bars(_Symbol, PERIOD_MN1) < strategy_lookback_months + 2)
      return false;

   const int recent_shift = 1;
   const int lookback_shift = recent_shift + strategy_lookback_months;
   const double recent_close = QM_SMA(_Symbol, PERIOD_MN1, 1, recent_shift, PRICE_CLOSE);
   const double lookback_close = QM_SMA(_Symbol, PERIOD_MN1, 1, lookback_shift, PRICE_CLOSE);
   const double mean_close = QM_SMA(_Symbol, PERIOD_MN1, strategy_lookback_months,
                                    recent_shift, PRICE_CLOSE);
   if(recent_close <= 0.0 || lookback_close <= 0.0 || mean_close <= 0.0)
      return false;

   const double return_pct = 100.0 * (recent_close / lookback_close - 1.0);
   const bool momentum_positive = (return_pct > strategy_cash_return_12m_pct);
   const bool average_positive = (recent_close > mean_close);

   if(momentum_positive && average_positive)
      exposure = 1.0;
   else if(momentum_positive || average_positive)
      exposure = 0.5;
   else
      exposure = 0.0;
   return true;
}

bool Strategy_SpreadAllowsEntry(const double atr_value)
{
   if(strategy_max_spread_atr_fraction <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || atr_value <= 0.0)
      return false;
   return (ask - bid <= strategy_max_spread_atr_fraction * atr_value);
}

bool Strategy_ConfigureRiskForExposure(const double exposure)
{
   const double weight = PORTFOLIO_WEIGHT * exposure;
   if(weight <= 0.0 || weight > 1.0)
      return false;

   const QM_RiskMode mode = (RISK_FIXED > 0.0) ? QM_RISK_MODE_FIXED : QM_RISK_MODE_PERCENT;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   return QM_RiskSizerConfigure(mode, RISK_PERCENT, RISK_FIXED, weight, risk_cap_money);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return (_Period != PERIOD_D1);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int month_id = Strategy_CurrentMonthId();
   if(month_id < 0 || month_id == g_last_rebalance_month)
      return false;

   double target_exposure = 0.0;
   if(!Strategy_TargetExposure(target_exposure))
   {
      if(Strategy_HasOpenPosition() && !Strategy_CloseOurPositions())
         return false;
      g_last_rebalance_month = month_id;
      return false;
   }

   const double held_exposure = Strategy_HeldExposure();
   if(held_exposure >= 0.0 && MathAbs(held_exposure - target_exposure) <= 1e-9)
   {
      g_last_rebalance_month = month_id;
      return false;
   }

   if(Strategy_HasOpenPosition() && !Strategy_CloseOurPositions())
      return false;

   if(target_exposure <= 0.0)
   {
      g_last_rebalance_month = month_id;
      return false;
   }

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(!Strategy_SpreadAllowsEntry(atr_value))
      return false;
   if(!Strategy_ConfigureRiskForExposure(target_exposure))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double stop = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value,
                                           strategy_atr_sl_mult);
   if(entry <= 0.0 || stop <= 0.0 || stop >= entry)
      return false;

   req.type = QM_BUY;
   req.price = entry;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = (target_exposure >= 1.0) ? "GVMT_FULL" : "GVMT_HALF";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_last_rebalance_month = month_id;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal,
                                        qm_news_compliance);
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
