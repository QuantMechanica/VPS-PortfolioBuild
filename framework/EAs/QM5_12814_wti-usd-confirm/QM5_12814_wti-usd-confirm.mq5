#property strict
#property version   "5.0"
#property description "QM5_12814 WTI USD Confirmation Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12814 - WTI USD Confirmation Trend
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - host/traded symbol: XTIUSD.DWX
//   - read-only confirmation symbol: EURUSD.DWX as broad USD proxy
//   - weekly entry gate
//   - direction requires WTI momentum and same-direction EURUSD proxy movement
// Runtime uses MT5 OHLC/broker calendar only; no macro feed, API, CSV, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12814;
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
input string strategy_usd_proxy_symbol        = "EURUSD.DWX";
input int    strategy_oil_lookback_d1         = 63;
input int    strategy_usd_lookback_d1         = 63;
input double strategy_min_oil_return_pct      = 3.0;
input double strategy_min_usd_proxy_return_pct = 1.0;
input int    strategy_trend_period            = 84;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.0;
input int    strategy_max_hold_days           = 21;
input int    strategy_max_spread_points       = 1000;

int g_last_entry_week_key = 0;

bool Strategy_IsHostD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_IsWeeklySignalBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework new-bar.
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 calendar gate behind framework new-bar.
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_WeekKey(current_bar) != Strategy_WeekKey(prior_bar);
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

bool Strategy_LoadLogReturn(const string symbol, const int lookback_raw, double &log_return)
  {
   log_return = 0.0;
   const int lookback = MathMax(10, lookback_raw);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 return sample behind new-bar gate.
   if(copied < lookback + 1)
      return false;

   const double close_recent = closes[0];
   const double close_past = closes[lookback];
   if(close_recent <= 0.0 || close_past <= 0.0)
      return false;

   log_return = MathLog(close_recent / close_past);
   return MathIsValidNumber(log_return);
  }

bool Strategy_LoadSignal(int &direction)
  {
   direction = 0;

   double oil_return = 0.0;
   double usd_proxy_return = 0.0;
   if(!Strategy_LoadLogReturn(_Symbol, strategy_oil_lookback_d1, oil_return))
      return false;
   if(!Strategy_LoadLogReturn(strategy_usd_proxy_symbol, strategy_usd_lookback_d1, usd_proxy_return))
      return false;

   const double trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1);
   double oil_closes[];
   ArraySetAsSeries(oil_closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, 1, oil_closes); // perf-allowed: single closed D1 price behind new-bar gate.
   if(copied < 1 || trend_sma <= 0.0)
      return false;
   const double oil_close = oil_closes[0];
   if(oil_close <= 0.0)
      return false;

   const double oil_threshold = MathMax(0.0, strategy_min_oil_return_pct) / 100.0;
   const double usd_threshold = MathMax(0.0, strategy_min_usd_proxy_return_pct) / 100.0;

   if(oil_return > oil_threshold && usd_proxy_return > usd_threshold && oil_close > trend_sma)
      direction = 1;
   else if(oil_return < -oil_threshold && usd_proxy_return < -usd_threshold && oil_close < trend_sma)
      direction = -1;
   else
      direction = 0;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const bool weekly_check = Strategy_IsWeeklySignalBar();
   int current_signal = 0;
   bool signal_available = true;

   if(weekly_check)
      signal_available = Strategy_LoadSignal(current_signal);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(weekly_check && signal_available)
        {
         const long type = PositionGetInteger(POSITION_TYPE);
         const int position_direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
         if(current_signal != position_direction)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_usd_proxy_symbol != "EURUSD.DWX")
      return true;
   if(strategy_oil_lookback_d1 < 10 || strategy_usd_lookback_d1 < 10)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12814_WTI_USD_CONFIRM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsWeeklySignalBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 weekly de-dupe behind new-bar gate.
   const int week_key = Strategy_WeekKey(current_bar);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   if(!Strategy_LoadSignal(direction))
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

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_USD_CONFIRM_LONG" : "WTI_USD_CONFIRM_SHORT";
   g_last_entry_week_key = week_key;
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
   if(!SymbolSelect(strategy_usd_proxy_symbol, true))
     {
      PrintFormat("QM5_12814 failed to select confirmation symbol %s", strategy_usd_proxy_symbol);
      return INIT_FAILED;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12814\",\"ea\":\"wti-usd-confirm\"}");
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
