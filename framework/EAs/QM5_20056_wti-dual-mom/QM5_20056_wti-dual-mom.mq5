#property strict
#property version   "5.0"
#property description "QM5_20056 WTI 3M Time Series Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20056 - WTI Dual-Horizon Time-Series Momentum
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - first D1 bar of each month only
//   - direction = sign of prior 3-month log return
//   - monthly package exits at next rebalance or stale-position guard
// Runtime uses MT5 OHLC/broker calendar only; no curve, inventory, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20056;
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
input int    strategy_momentum_lookback_d1 = 63;
input double strategy_min_abs_return_pct   = 0.0;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 31;
input int    strategy_max_spread_points    = 1000;

int g_last_entry_month_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   // Framework calendar-cadence helper (QM_Indicators.mqh) -- stateless key
   // comparison across two D1 shifts, NOT the latching QM_IsNewCalendarPeriod
   // (which would double-consume its single-fire edge between the close-check
   // in Strategy_ManageOpenPosition and the entry-check in Strategy_EntrySignal
   // on the same tick).
   const int current_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_key <= 0 || prior_key <= 0)
      return false;
   return current_key != prior_key;
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

bool Strategy_LoadMomentum(double &momentum, int &direction)
  {
   momentum = 0.0;
   direction = 0;

   const int lookback = MathMax(21, strategy_momentum_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 3M momentum sample behind new-bar gate.
   if(copied < lookback + 1)
      return false;

   const double close_recent = closes[0];
   const double close_past = closes[lookback];
   if(close_recent <= 0.0 || close_past <= 0.0)
      return false;

   momentum = MathLog(close_recent / close_past);
   if(!MathIsValidNumber(momentum))
      return false;

   const double threshold = MathMax(0.0, strategy_min_abs_return_pct) / 100.0;
   if(momentum > threshold)
      direction = 1;
   else if(momentum < -threshold)
      direction = -1;
   else
      direction = 0;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const bool monthly_rebalance = Strategy_IsMonthlyRebalanceBar();
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = monthly_rebalance;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_momentum_lookback_d1 < 21)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20056_WTI_TSMOM3M";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double momentum = 0.0;
   int direction = 0;
   if(!Strategy_LoadMomentum(momentum, direction))
      return false;
   if(direction == 0)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   // QM_StopATRFromValue reuses the already-pooled atr_last read above.
   // QM_StopATR itself re-derives ATR via a raw iATR handle that is opened
   // and released within the call (QM_StopRulesReadATRValue), which never
   // back-calculates in the tester -- root-caused 2026-07-05 on the WTI
   // calendar-fade family (1 trade then permanent silence).
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_TSMOM3M_LONG" : "WTI_TSMOM3M_SHORT";
   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20056\",\"ea\":\"wti-dual-mom\"}");
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

   // News blackout gates NEW entries only (below), per the 2026-07-02 audit
   // rule -- it must not sit above Strategy_ManageOpenPosition/ExitSignal so
   // the ATR hard stop keeps enforcing through news windows.
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


