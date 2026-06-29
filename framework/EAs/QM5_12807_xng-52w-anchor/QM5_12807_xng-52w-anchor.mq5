#property strict
#property version   "5.0"
#property description "QM5_12807 Natural Gas 52-Week Anchor Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12807 - Natural Gas 52-Week High/Low Anchor Momentum
// -----------------------------------------------------------------------------
// D1 structural natural gas sleeve:
//   - first D1 bar of each month only
//   - long near the 252-D1 closing high with 63-D1 return confirmation
//   - short near the 252-D1 closing low with 63-D1 return confirmation
// Runtime uses MT5 OHLC/broker calendar only; no curve, inventory, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12807;
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
input int    strategy_anchor_lookback_d1      = 252;
input int    strategy_confirm_lookback_d1     = 63;
input double strategy_anchor_long_min         = 0.90;
input double strategy_anchor_short_max        = 1.15;
input double strategy_confirm_min_return_pct  = 5.0;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.75;
input int    strategy_max_hold_days           = 31;
input int    strategy_max_spread_points       = 1500;

int g_last_entry_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework new-bar.
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 calendar gate behind framework new-bar.
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_MonthKey(current_bar) != Strategy_MonthKey(prior_bar);
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

bool Strategy_LoadAnchorSignal(int &direction, double &anchor_metric, double &confirm_return)
  {
   direction = 0;
   anchor_metric = 0.0;
   confirm_return = 0.0;

   int anchor_lb = strategy_anchor_lookback_d1;
   if(anchor_lb < 63)
      anchor_lb = 63;

   int confirm_lb = strategy_confirm_lookback_d1;
   if(confirm_lb < 21)
      confirm_lb = 21;
   if(confirm_lb >= anchor_lb)
      confirm_lb = anchor_lb / 2;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, anchor_lb + 1, closes); // perf-allowed: bounded D1 52-week anchor sample behind new-bar gate.
   if(copied < anchor_lb + 1)
      return false;

   const double close_recent = closes[0];
   const double close_confirm = closes[confirm_lb];
   if(close_recent <= 0.0 || close_confirm <= 0.0)
      return false;

   double high_anchor = close_recent;
   double low_anchor = close_recent;
   for(int i = 0; i < anchor_lb; ++i)
     {
      const double c = closes[i];
      if(c <= 0.0)
         return false;
      if(c > high_anchor)
         high_anchor = c;
      if(c < low_anchor)
         low_anchor = c;
     }

   if(high_anchor <= 0.0 || low_anchor <= 0.0)
      return false;

   confirm_return = MathLog(close_recent / close_confirm);
   if(!MathIsValidNumber(confirm_return))
      return false;

   const double confirm_threshold = MathMax(0.0, strategy_confirm_min_return_pct) / 100.0;
   const double long_anchor = close_recent / high_anchor;
   const double short_anchor = close_recent / low_anchor;

   if(long_anchor >= strategy_anchor_long_min && confirm_return >= confirm_threshold)
     {
      direction = 1;
      anchor_metric = long_anchor;
     }
   else if(short_anchor <= strategy_anchor_short_max && confirm_return <= -confirm_threshold)
     {
      direction = -1;
      anchor_metric = short_anchor;
     }
   else
     {
      direction = 0;
      anchor_metric = long_anchor;
     }

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
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_anchor_lookback_d1 < 63)
      return true;
   if(strategy_confirm_lookback_d1 < 21)
      return true;
   if(strategy_confirm_lookback_d1 >= strategy_anchor_lookback_d1)
      return true;
   if(strategy_anchor_long_min <= 0.0 || strategy_anchor_long_min > 1.0)
      return true;
   if(strategy_anchor_short_max < 1.0)
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
   req.reason = "QM5_12807_XNG_52W_ANCHOR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly de-dupe behind new-bar gate.
   const int month_key = Strategy_MonthKey(current_bar);
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

   int direction = 0;
   double anchor_metric = 0.0;
   double confirm_return = 0.0;
   if(!Strategy_LoadAnchorSignal(direction, anchor_metric, confirm_return))
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

   req.reason = (direction > 0) ? "XNG_52W_ANCHOR_LONG" : "XNG_52W_ANCHOR_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12807\",\"ea\":\"xng-52w-anchor\"}");
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
