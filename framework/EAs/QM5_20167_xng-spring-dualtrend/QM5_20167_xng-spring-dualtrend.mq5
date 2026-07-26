#property strict
#property version   "5.0"
#property description "QM5_20167 XNG Spring-Shoulder Dual-Trend Short"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20167;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_period         = 21;
input int    strategy_slow_period         = 84;
input int    strategy_slope_bars          = 5;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 35;
input int    strategy_max_spread_points    = 1000;

datetime g_last_entry_bar = 0;

bool Strategy_IsSpringMonth(const int month)
  {
   return (month == 4 || month == 5);
  }

bool Strategy_GetTrendState(double &close_last,
                            double &fast_now,
                            double &slow_now,
                            double &fast_prior,
                            double &slow_prior)
  {
   close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   fast_now   = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_period, 1, PRICE_CLOSE);
   slow_now   = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_period, 1, PRICE_CLOSE);
   const int prior_shift = 1 + strategy_slope_bars;
   fast_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_period, prior_shift, PRICE_CLOSE);
   slow_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_period, prior_shift, PRICE_CLOSE);
   return (close_last > 0.0 && fast_now > 0.0 && slow_now > 0.0 &&
           fast_prior > 0.0 && slow_prior > 0.0);
  }

bool Strategy_TrendIsShort(const double close_last,
                          const double fast_now,
                          const double slow_now,
                          const double fast_prior,
                          const double slow_prior)
  {
   return (close_last < fast_now && fast_now < slow_now &&
           fast_now < fast_prior && slow_now < slow_prior);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XNGUSD.DWX" || _Period != PERIOD_D1 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_fast_period != 21 || strategy_slow_period != 84 ||
      strategy_slope_bars != 5 || strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1e-9 ||
      strategy_max_hold_days != 35 || strategy_max_spread_points != 1000)
      return true;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
      return;

   double close_last, fast_now, slow_now, fast_prior, slow_prior;
   if(!Strategy_GetTrendState(close_last, fast_now, slow_now, fast_prior, slow_prior))
      return;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   const int month = (month_key > 0) ? month_key % 100 : 0;
   const bool valid_state = Strategy_IsSpringMonth(month) &&
      Strategy_TrendIsShort(close_last, fast_now, slow_now, fast_prior, slow_prior);
   const datetime now = TimeCurrent();
   const int hold_seconds = strategy_max_hold_days * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const bool wrong_side =
         ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL);
      if(wrong_side || !valid_state ||
         (opened > 0 && now - opened >= hold_seconds))
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XNG_SPRING_DUALTREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one D1 timestamp read per framework new-bar pass
   if(d1_bar <= 0 || d1_bar == g_last_entry_bar)
      return false;
   g_last_entry_bar = d1_bar;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0 || !Strategy_IsSpringMonth(month_key % 100))
      return false;

   const long spread_pts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_pts > strategy_max_spread_points)
      return false;

   double close_last, fast_now, slow_now, fast_prior, slow_prior;
   if(!Strategy_GetTrendState(close_last, fast_now, slow_now, fast_prior, slow_prior) ||
      !Strategy_TrendIsShort(close_last, fast_now, slow_now, fast_prior, slow_prior))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price,
                       strategy_atr_period, strategy_atr_sl_mult);
   return (req.sl > 0.0);
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT,
                        RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_20167\",\"slug\":\"xng-spring-dualtrend\"}");
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar())
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
