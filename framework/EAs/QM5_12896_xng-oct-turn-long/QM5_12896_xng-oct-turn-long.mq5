#property strict
#property version   "5.0"
#property description "QM5_12896 XNG October Winter-Turn Long"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12896 - XNG October Winter-Turn Long
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - checks the first D1 bar of each broker-calendar week in October/November
//   - requires a positive 10-D1 turn plus fast/slow SMA confirmation
//   - buys XNGUSD.DWX only; exits by ATR stop, fast-SMA failure, season end, or time
// Runtime uses MT5 OHLC only; no EIA feed, weather feed, API, CSV, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12896;
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
input int    strategy_turn_lookback_days  = 10;
input double strategy_min_turn_return_pct = 3.0;
input int    strategy_fast_sma_period     = 20;
input int    strategy_slow_sma_period     = 60;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 6;
input int    strategy_max_spread_points   = 2500;

int g_last_signal_week_key = -1;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year / 7;
  }

bool Strategy_IsEligibleMonth(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.mon == 10 || dt.mon == 11);
  }

bool Strategy_IsFirstD1BarOfWeek(const datetime t)
  {
   if(t <= 0)
      return false;
   const datetime prev_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 calendar gate.
   if(prev_bar_time <= 0)
      return false;

   MqlDateTime dt;
   MqlDateTime prev_dt;
   TimeToStruct(t, dt);
   TimeToStruct(prev_bar_time, prev_dt);

   if(dt.year != prev_dt.year)
      return true;
   return (dt.day_of_week <= prev_dt.day_of_week);
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

bool Strategy_LoadTurnState(double &turn_return_pct,
                            double &close_last,
                            double &fast_sma,
                            double &slow_sma,
                            double &atr_last,
                            int &signal_week_key,
                            const bool require_weekly_gate)
  {
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 weekly calendar gate.
   if(current_bar_time <= 0)
      return false;
   if(require_weekly_gate && !Strategy_IsFirstD1BarOfWeek(current_bar_time))
      return false;
   if(!Strategy_IsEligibleMonth(current_bar_time))
      return false;

   signal_week_key = Strategy_WeekKey(current_bar_time);

   int lookback = strategy_turn_lookback_days;
   if(lookback < 2)
      lookback = 2;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int close_count = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 turn window.
   if(close_count < lookback + 1)
      return false;

   close_last = closes[0];
   const double close_lookback = closes[lookback];
   if(close_last <= 0.0 || close_lookback <= 0.0)
      return false;

   fast_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1, PRICE_CLOSE);
   slow_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(signal_week_key < 0 || fast_sma <= 0.0 || slow_sma <= 0.0 || atr_last <= 0.0)
      return false;

   turn_return_pct = 100.0 * ((close_last / close_lookback) - 1.0);
   if(!MathIsValidNumber(turn_return_pct))
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   int hold_days = strategy_max_hold_days;
   if(hold_days < 1)
      hold_days = 1;
   const int hold_seconds = hold_days * 86400;

   double turn_return_pct = 0.0;
   double close_last = 0.0;
   double fast_sma = 0.0;
   double slow_sma = 0.0;
   double atr_last = 0.0;
   int signal_week_key = -1;
   const bool state_ready = Strategy_LoadTurnState(turn_return_pct,
                                                   close_last,
                                                   fast_sma,
                                                   slow_sma,
                                                   atr_last,
                                                   signal_week_key,
                                                   false);

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
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(!Strategy_IsEligibleMonth(now))
         should_close = true;
      if(state_ready && close_last < fast_sma)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_turn_lookback_days < 2)
      return true;
   if(strategy_fast_sma_period <= 1 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_min_turn_return_pct <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12896_XNG_OCT_TURN_LONG";
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

   double turn_return_pct = 0.0;
   double close_last = 0.0;
   double fast_sma = 0.0;
   double slow_sma = 0.0;
   double atr_last = 0.0;
   int signal_week_key = -1;
   if(!Strategy_LoadTurnState(turn_return_pct,
                              close_last,
                              fast_sma,
                              slow_sma,
                              atr_last,
                              signal_week_key,
                              true))
      return false;
   if(signal_week_key == g_last_signal_week_key)
      return false;

   if(turn_return_pct < strategy_min_turn_return_pct)
      return false;
   if(close_last <= fast_sma || close_last <= slow_sma)
      return false;
   if(fast_sma < slow_sma)
      return false;

   req.type = QM_BUY;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_OCT_TURN_LONG";
   g_last_signal_week_key = signal_week_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12896\",\"ea\":\"xng-oct-turn-long\"}");
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
