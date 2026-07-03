#property strict
#property version   "5.0"
#property description "QM5_12975 Ehlers PMA triple-screen swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12975;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pma_slow_period   = 50;
input int    strategy_pma_fast_period   = 10;
input int    strategy_atr_period        = 14;
input double strategy_atr_mult          = 2.5;

datetime g_last_manage_d1_bar = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == "NDX.DWX")
      return 0;
   if(symbol == "XAUUSD.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsTarget()
  {
   return (Strategy_SlotForSymbol(_Symbol) == qm_magic_slot_offset && _Period == PERIOD_D1);
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

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(shift < 1)
      return 0.0;
   return QM_SMA(_Symbol, tf, 1, shift, PRICE_CLOSE);
  }

double Strategy_RegressionSlope(const ENUM_TIMEFRAMES tf, const int length, const int shift)
  {
   if(length < 2 || shift < 1)
      return 0.0;

   const double n = (double)length;
   const double sum_x = (n - 1.0) * n / 2.0;
   const double sum_xx = (n - 1.0) * n * (2.0 * n - 1.0) / 6.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;

   for(int i = 0; i < length; ++i)
     {
      const int bar_shift = shift + (length - 1 - i);
      const double y = Strategy_Close(tf, bar_shift);
      if(y <= 0.0 || !MathIsValidNumber(y))
         return 0.0;
      sum_y += y;
      sum_xy += (double)i * y;
     }

   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= 1e-12)
      return 0.0;
   return (n * sum_xy - sum_x * sum_y) / denom;
  }

double Strategy_PMA(const ENUM_TIMEFRAMES tf, const int length, const int shift)
  {
   if(length < 2 || shift < 1)
      return 0.0;
   const double sma = QM_SMA(_Symbol, tf, length, shift, PRICE_CLOSE);
   const double slope = Strategy_RegressionSlope(tf, length, shift);
   if(sma <= 0.0 || !MathIsValidNumber(sma) || !MathIsValidNumber(slope))
      return 0.0;
   return sma + slope * ((double)length / 2.0);
  }

double Strategy_HighestCloseSinceEntry(const datetime opened)
  {
   if(opened <= 0)
      return 0.0;
   const int bars_since_open = iBarShift(_Symbol, PERIOD_D1, opened, false);
   if(bars_since_open < 1)
      return 0.0;

   double best = 0.0;
   for(int shift = 1; shift <= bars_since_open; ++shift)
     {
      const double close_value = Strategy_Close(PERIOD_D1, shift);
      if(close_value <= 0.0)
         return 0.0;
      if(best <= 0.0 || close_value > best)
         best = close_value;
     }
   return best;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_pma_slow_period < 2 || strategy_pma_fast_period < 2)
      return true;
   if(strategy_pma_fast_period >= strategy_pma_slow_period)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "EHLERS_PMA_TRIPLE_SCREEN";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const double w1_close = Strategy_Close(PERIOD_W1, 1);
   const double w1_pma_slow = Strategy_PMA(PERIOD_W1, strategy_pma_slow_period, 1);
   const double d1_close = Strategy_Close(PERIOD_D1, 1);
   const double d1_pma_slow = Strategy_PMA(PERIOD_D1, strategy_pma_slow_period, 1);
   const double d1_pma_fast = Strategy_PMA(PERIOD_D1, strategy_pma_fast_period, 1);
   if(w1_close <= 0.0 || w1_pma_slow <= 0.0 || d1_close <= 0.0 ||
      d1_pma_slow <= 0.0 || d1_pma_fast <= 0.0)
      return false;

   if(!(w1_close > w1_pma_slow && d1_close > d1_pma_slow && d1_pma_fast > d1_pma_slow))
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_mult);
   if(req.sl <= 0.0)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cheap D1 timestamp throttle before daily trailing-stop maintenance.
   if(current_d1_bar <= 0 || current_d1_bar == g_last_manage_d1_bar)
      return;
   g_last_manage_d1_bar = current_d1_bar;

   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double market = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || market <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const double best_close = Strategy_HighestCloseSinceEntry(opened);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(best_close <= 0.0)
         continue;

      const double target_sl = QM_TM_NormalizePrice(_Symbol, best_close - strategy_atr_mult * atr);
      if(target_sl <= 0.0)
         continue;
      const bool improves = (current_sl <= 0.0) || (target_sl > current_sl + point * 0.5);
      if(improves && target_sl < market)
         QM_TM_MoveSL(ticket, target_sl, "pma_best_close_atr_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = Strategy_Close(PERIOD_D1, 1);
   const double d1_pma_slow = Strategy_PMA(PERIOD_D1, strategy_pma_slow_period, 1);
   if(close1 <= 0.0 || d1_pma_slow <= 0.0)
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
      if(close1 < d1_pma_slow)
         return true;
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12975\",\"ea\":\"ehlers-pma-triple-swing\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
