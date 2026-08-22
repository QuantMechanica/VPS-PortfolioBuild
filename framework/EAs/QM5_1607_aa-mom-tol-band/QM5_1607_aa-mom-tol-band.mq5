#property strict
#property version   "5.0"
#property description "QM5_1607 Alpha Architect Momentum Informed Tolerance Band"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1607 — Alpha Architect Momentum Informed Tolerance Band
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1607_aa-mom-tol-band.md
//
// Review once per broker-calendar month from completed MN1 data. Positive
// 12-month absolute momentum permits 50%-60% exposure; non-positive momentum
// permits 40%-50%. Rebalance only when the held risk-budget fraction lies
// outside the permitted band. The order comment persists the selected band
// point across EA restarts.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1607;
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
      if(StringFind(comment, "MOM_TOL_40") >= 0)
         return 0.4;
      if(StringFind(comment, "MOM_TOL_50") >= 0)
         return 0.5;
      if(StringFind(comment, "MOM_TOL_60") >= 0)
         return 0.6;
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

bool Strategy_MomentumPositive(bool &positive)
{
   positive = false;
   if(strategy_lookback_months < 1)
      return false;
   if(Bars(_Symbol, PERIOD_MN1) < strategy_lookback_months + 2)
      return false;

   const int recent_shift = 1;
   const int lookback_shift = recent_shift + strategy_lookback_months;
   const double recent_close = QM_SMA(_Symbol, PERIOD_MN1, 1, recent_shift, PRICE_CLOSE);
   const double lookback_close = QM_SMA(_Symbol, PERIOD_MN1, 1, lookback_shift, PRICE_CLOSE);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   const double return_pct = 100.0 * (recent_close / lookback_close - 1.0);
   positive = (return_pct > strategy_cash_return_12m_pct);
   return true;
}

double Strategy_TargetExposure(const bool positive_momentum,
                               const double held_exposure,
                               const bool has_position)
{
   if(!has_position || held_exposure < 0.0)
      return positive_momentum ? 0.5 : 0.4;

   if(positive_momentum)
   {
      if(held_exposure < 0.5)
         return 0.5;
      if(held_exposure > 0.6)
         return 0.6;
      return held_exposure;
   }

   if(held_exposure < 0.4)
      return 0.4;
   if(held_exposure > 0.5)
      return 0.5;
   return held_exposure;
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

string Strategy_ExposureReason(const double exposure)
{
   if(exposure >= 0.6 - 1e-9)
      return "MOM_TOL_60";
   if(exposure >= 0.5 - 1e-9)
      return "MOM_TOL_50";
   return "MOM_TOL_40";
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

   bool momentum_positive = false;
   if(!Strategy_MomentumPositive(momentum_positive))
   {
      if(Strategy_HasOpenPosition() && !Strategy_CloseOurPositions())
         return false;
      g_last_rebalance_month = month_id;
      return false;
   }

   const bool has_position = Strategy_HasOpenPosition();
   const double held_exposure = Strategy_HeldExposure();
   const double target_exposure = Strategy_TargetExposure(momentum_positive,
                                                           held_exposure,
                                                           has_position);

   if(has_position && held_exposure >= 0.0 &&
      MathAbs(target_exposure - held_exposure) <= 1e-9)
   {
      g_last_rebalance_month = month_id;
      return false;
   }

   if(has_position && !Strategy_CloseOurPositions())
      return false;

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
   req.reason = Strategy_ExposureReason(target_exposure);
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
