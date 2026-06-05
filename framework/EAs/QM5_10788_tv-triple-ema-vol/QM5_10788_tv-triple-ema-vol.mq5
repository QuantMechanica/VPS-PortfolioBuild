#property strict
#property version   "5.0"
#property description "QM5_10788 TradingView Triple EMA RSI Volatility"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA - tv-triple-ema-vol
// -----------------------------------------------------------------------------
// Card mechanics:
//   Long-only entry on a closed bar when EMA20 > EMA50 > EMA200, close > EMA20,
//   RSI is inside the configured buy zone, and the fixed ATR-percent volatility
//   proxy is inside its normalized range. Exits are broker SL/TP, bearish EMA
//   stack, RSI below the configured exit threshold, framework Friday close,
//   and framework kill/news gates.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10788;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast          = 20;
input int    strategy_ema_mid           = 50;
input int    strategy_ema_slow          = 200;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_buy_min       = 50.0;
input double strategy_rsi_buy_max       = 70.0;
input double strategy_rsi_exit_below    = 45.0;
input int    strategy_vol_atr_period    = 14;
input double strategy_vol_norm_cap_pct  = 1.0;
input double strategy_vol_min_norm      = 30.0;
input double strategy_vol_max_norm      = 100.0;
input int    strategy_stop_mode         = 0;      // 0 = fixed percent, 1 = ATR multiple
input double strategy_stop_fixed_pct    = 5.0;
input double strategy_stop_atr_mult     = 2.0;
input int    strategy_target_mode       = 0;      // 0 = fixed percent, 1 = risk multiple
input double strategy_target_fixed_pct  = 15.0;
input double strategy_target_rr         = 3.0;
input bool   strategy_exit_ema_enabled  = true;
input bool   strategy_exit_rsi_enabled  = true;

double Strategy_ClosedClose(const int shift)
  {
   double closes[1];
   if(CopyClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift, 1, closes) != 1) // perf-allowed: single closed-bar price read for card price/volatility rules.
      return 0.0;
   return closes[0];
  }

bool Strategy_GetOpenPosition(ENUM_POSITION_TYPE &out_type)
  {
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
      out_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double Strategy_VolatilityNorm(const double close_price)
  {
   if(close_price <= 0.0 || strategy_vol_atr_period <= 0 || strategy_vol_norm_cap_pct <= 0.0)
      return -1.0;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_vol_atr_period, 1);
   if(atr <= 0.0)
      return -1.0;

   const double atr_pct = 100.0 * atr / close_price;
   return 100.0 * atr_pct / strategy_vol_norm_cap_pct;
  }

double Strategy_StopPrice(const double entry)
  {
   if(entry <= 0.0)
      return 0.0;

   if(strategy_stop_mode == 1)
      return QM_StopATR(_Symbol, QM_BUY, entry, strategy_vol_atr_period, strategy_stop_atr_mult);

   const double distance = entry * strategy_stop_fixed_pct / 100.0;
   return QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, distance);
  }

double Strategy_TargetPrice(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0)
      return 0.0;

   if(strategy_target_mode == 1)
      return QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_target_rr);

   const double distance = entry * strategy_target_fixed_pct / 100.0;
   return QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, entry, distance);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(strategy_ema_fast <= 0 || strategy_ema_mid <= strategy_ema_fast ||
      strategy_ema_slow <= strategy_ema_mid || strategy_rsi_period <= 0 ||
      strategy_rsi_buy_min > strategy_rsi_buy_max)
      return false;

   ENUM_POSITION_TYPE open_type;
   if(Strategy_GetOpenPosition(open_type))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast, 1);
   const double ema_mid = QM_EMA(_Symbol, tf, strategy_ema_mid, 1);
   const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   if(!(ema_fast > ema_mid && ema_mid > ema_slow))
      return false;

   const double close1 = Strategy_ClosedClose(1);
   if(close1 <= ema_fast)
      return false;

   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   if(rsi < strategy_rsi_buy_min || rsi > strategy_rsi_buy_max)
      return false;

   const double vol_norm = Strategy_VolatilityNorm(close1);
   if(vol_norm < strategy_vol_min_norm || vol_norm > strategy_vol_max_norm)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = Strategy_StopPrice(entry);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double tp = Strategy_TargetPrice(entry, sl);
   if(tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = "tv_triple_ema_vol_long";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial-close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE open_type;
   if(!Strategy_GetOpenPosition(open_type))
      return false;
   if(open_type != POSITION_TYPE_BUY)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(strategy_exit_ema_enabled)
     {
      const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast, 1);
      const double ema_mid = QM_EMA(_Symbol, tf, strategy_ema_mid, 1);
      const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow, 1);
      if(ema_fast > 0.0 && ema_mid > 0.0 && ema_slow > 0.0 &&
         ema_fast < ema_mid && ema_mid < ema_slow)
         return true;
     }

   if(strategy_exit_rsi_enabled)
     {
      const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
      if(rsi > 0.0 && rsi < strategy_rsi_exit_below)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10788_tv-triple-ema-vol\"}");
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
