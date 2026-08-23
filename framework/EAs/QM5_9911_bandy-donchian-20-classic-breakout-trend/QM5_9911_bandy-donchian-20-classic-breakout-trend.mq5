#property strict
#property version   "5.0"
#property description "QM5_9911 Bandy Donchian-20 Classic Breakout Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9911
// Strategy: Bandy Donchian-20 Classic Breakout (Trend, Long/Short)
// Source: Howard B. Bandy, Quantitative Technical Analysis, Blue Owl Press, 2015
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9911;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_lookback     = 20;
input int    strategy_exit_lookback      = 10;
input int    strategy_regime_sma_period  = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.5;
input int    strategy_time_stop_bars     = 60;

// -----------------------------------------------------------------------------
// Strategy calculation — bounded and cached once per D1 calendar key.
// -----------------------------------------------------------------------------

bool Strategy_CalculateDonchian(double &don_high, double &don_low,
                                double &exit_high, double &exit_low,
                                double &signal_close)
  {
   static int    cached_calendar_key = 0;
   static bool   cached_valid        = false;
   static double cached_don_high     = 0.0;
   static double cached_don_low      = 0.0;
   static double cached_exit_high    = 0.0;
   static double cached_exit_low     = 0.0;
   static double cached_signal_close = 0.0;

   const int calendar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(calendar_key <= 0)
      return false;

   if(calendar_key == cached_calendar_key)
     {
      don_high     = cached_don_high;
      don_low      = cached_don_low;
      exit_high    = cached_exit_high;
      exit_low     = cached_exit_low;
      signal_close = cached_signal_close;
      return cached_valid;
     }

   cached_calendar_key = calendar_key;
   cached_valid        = false;
   cached_don_high     = -DBL_MAX;
   cached_don_low      = DBL_MAX;
   cached_exit_high    = -DBL_MAX;
   cached_exit_low     = DBL_MAX;
   cached_signal_close = 0.0;

   if(strategy_entry_lookback < 2 || strategy_exit_lookback < 2)
      return false;

   const int max_lookback = MathMax(strategy_entry_lookback, strategy_exit_lookback);
   const int need = max_lookback + 2;
   if(Bars(_Symbol, PERIOD_D1) < need)
      return false;

   cached_signal_close = iClose(_Symbol, PERIOD_D1, 1);
   if(cached_signal_close <= 0.0)
      return false;

   // Entry Donchian high/low over prior N completed bars (shifts 2 .. strategy_entry_lookback + 1)
   for(int s = 2; s <= strategy_entry_lookback + 1; ++s)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, s);
      const double lo = iLow(_Symbol, PERIOD_D1, s);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         return false;
      if(hi > cached_don_high) cached_don_high = hi;
      if(lo < cached_don_low)  cached_don_low  = lo;
     }

   // Exit Donchian high/low over prior M completed bars (shifts 2 .. strategy_exit_lookback + 1)
   for(int s = 2; s <= strategy_exit_lookback + 1; ++s)
     {
      const double hi = iHigh(_Symbol, PERIOD_D1, s);
      const double lo = iLow(_Symbol, PERIOD_D1, s);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         return false;
      if(hi > cached_exit_high) cached_exit_high = hi;
      if(lo < cached_exit_low)  cached_exit_low  = lo;
     }

   cached_valid = true;
   don_high     = cached_don_high;
   don_low      = cached_don_low;
   exit_high    = cached_exit_high;
   exit_low     = cached_exit_low;
   signal_close = cached_signal_close;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   return (strategy_entry_lookback < 2 ||
           strategy_exit_lookback < 2 ||
           strategy_regime_sma_period < 2 ||
           strategy_atr_period < 1 ||
           strategy_atr_stop_mult <= 0.0 ||
           strategy_time_stop_bars < 1);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double don_high = 0.0, don_low = 0.0, exit_high = 0.0, exit_low = 0.0, signal_close = 0.0;
   if(!Strategy_CalculateDonchian(don_high, don_low, exit_high, exit_low, signal_close))
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0)
      return false;

   int direction = 0;
   if(signal_close > don_high && signal_close > regime_sma)
      direction = 1;
   else if(signal_close < don_low && signal_close < regime_sma)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   const double sl_price = QM_StopATRFromValue(_Symbol, req.type, entry, atr_val, strategy_atr_stop_mult);
   if(sl_price <= 0.0)
      return false;
   if(req.type == QM_BUY  && sl_price >= entry)
      return false;
   if(req.type == QM_SELL && sl_price <= entry)
      return false;

   req.sl     = sl_price;
   req.reason = (direction > 0) ? "BANDY_DON20_LONG" : "BANDY_DON20_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic, _Symbol, PERIOD_D1, TimeCurrent());
   if(held_bars >= strategy_time_stop_bars)
      return true;

   double don_high = 0.0, don_low = 0.0, exit_high = 0.0, exit_low = 0.0, signal_close = 0.0;
   if(!Strategy_CalculateDonchian(don_high, don_low, exit_high, exit_low, signal_close))
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
        {
         if(signal_close < exit_low)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(signal_close > exit_high)
            return true;
        }
     }

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
