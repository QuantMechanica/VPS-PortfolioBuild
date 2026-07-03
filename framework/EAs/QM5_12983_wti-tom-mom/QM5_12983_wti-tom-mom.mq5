#property strict
#property version   "5.0"
#property description "QM5_12983 WTI Turn-Of-Month Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12983 - WTI Turn-Of-Month Momentum
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - one package per broker-calendar turn-of-month cycle
//   - direction follows a fixed completed-D1 return lookback
//   - exits when the TOM window ends, by max hold, or by ATR stop/target
// Runtime uses MT5 OHLC/broker calendar only; no CTA, futures-chain, API, CSV,
// EIA, CFTC, volume, open-interest, or ML feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12983;
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
input int    strategy_tom_pre_days          = 2;
input int    strategy_tom_post_days         = 3;
input int    strategy_momentum_lookback_days = 63;
input double strategy_min_momentum_pct      = 4.0;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 2.5;
input double strategy_atr_tp_mult           = 3.0;
input int    strategy_max_hold_days         = 6;
input int    strategy_max_spread_points     = 1000;

int g_last_entry_cycle_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_MonthKey(const int year, const int month)
  {
   return year * 100 + month;
  }

int Strategy_PreviousMonthKey(const int year, const int month)
  {
   if(month <= 1)
      return Strategy_MonthKey(year - 1, 12);
   return Strategy_MonthKey(year, month - 1);
  }

bool Strategy_IsTomWindow(const datetime bar_time, int &cycle_key)
  {
   cycle_key = 0;
   if(bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int days_in_month = Strategy_DaysInMonth(dt.year, dt.mon);
   const int pre_days = MathMax(0, strategy_tom_pre_days);
   const int post_days = MathMax(0, strategy_tom_post_days);

   if(pre_days > 0 && dt.day >= days_in_month - pre_days + 1)
     {
      cycle_key = Strategy_MonthKey(dt.year, dt.mon);
      return true;
     }

   if(post_days > 0 && dt.day <= post_days)
     {
      cycle_key = Strategy_PreviousMonthKey(dt.year, dt.mon);
      return true;
     }

   return false;
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

bool Strategy_LoadMomentumState(double &return_pct,
                                double &atr_last,
                                int &cycle_key,
                                const bool require_tom_window)
  {
   return_pct = 0.0;
   atr_last = 0.0;
   cycle_key = 0;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind new-bar.
   const bool in_tom = Strategy_IsTomWindow(current_bar_time, cycle_key);
   if(require_tom_window && !in_tom)
      return false;

   int lookback = strategy_momentum_lookback_days;
   if(lookback < 10)
      lookback = 10;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int close_count = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 momentum window behind new-bar.
   if(close_count < lookback + 1)
      return false;

   const double close_last = closes[0];
   const double close_old = closes[lookback];
   if(close_last <= 0.0 || close_old <= 0.0)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   return_pct = 100.0 * ((close_last / close_old) - 1.0);
   return MathIsValidNumber(return_pct);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 TOM exit gate behind new-bar.
   int current_cycle_key = 0;
   const bool in_tom = Strategy_IsTomWindow(current_bar_time, current_cycle_key);
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
      bool should_close = false;
      if(!in_tom)
         should_close = true;
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
   if(strategy_tom_pre_days < 0 || strategy_tom_pre_days > 7)
      return true;
   if(strategy_tom_post_days < 0 || strategy_tom_post_days > 7)
      return true;
   if(strategy_tom_pre_days + strategy_tom_post_days <= 0)
      return true;
   if(strategy_momentum_lookback_days < 10)
      return true;
   if(strategy_min_momentum_pct <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
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
   req.reason = "QM5_12983_WTI_TOM_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double return_pct = 0.0;
   double atr_last = 0.0;
   int cycle_key = 0;
   if(!Strategy_LoadMomentumState(return_pct, atr_last, cycle_key, true))
      return false;
   if(cycle_key <= 0 || cycle_key == g_last_entry_cycle_key)
      return false;

   int direction = 0;
   if(return_pct >= strategy_min_momentum_pct)
      direction = 1;
   else if(return_pct <= -strategy_min_momentum_pct)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_TOM_MOM_LONG" : "WTI_TOM_MOM_SHORT";
   g_last_entry_cycle_key = cycle_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12983\",\"ea\":\"wti-tom-mom\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
