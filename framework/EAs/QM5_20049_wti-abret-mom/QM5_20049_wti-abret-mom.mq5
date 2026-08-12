#property strict
#property version   "5.0"
#property description "QM5_20049 WTI Abnormal Return Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20049;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_return_lookback_d1 = 252;
input double strategy_entry_z            = 2.0;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_exit_hour_broker   = 10;
input int    strategy_max_hold_hours     = 36;
input int    strategy_max_spread_points  = 1000;

int g_last_signal_day_key = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_CloseExpiredPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hour = Strategy_Hour(now);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const bool timed_exit = (Strategy_DayKey(now) != Strategy_DayKey(opened) &&
                               hour >= strategy_exit_hour_broker);
      const bool stale_exit = (opened > 0 && now - opened >= MathMax(1, strategy_max_hold_hours) * 3600);
      if(timed_exit || stale_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX" || _Period != PERIOD_H1 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_return_lookback_d1 < 60 || strategy_entry_z <= 0.0 ||
      strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_exit_hour_broker < 1 || strategy_exit_hour_broker > 23 ||
      strategy_max_hold_hours <= 0)
      return true;
   return false;
  }

bool Strategy_AbnormalReturn(double &signal_return, double &z_score)
  {
   const int n = strategy_return_lookback_d1;
   double opens[], closes[];
   ArraySetAsSeries(opens, true);
   ArraySetAsSeries(closes, true);
   // Signal is shift 1. Estimation starts at shift 2, so no signal-day leakage.
   if(CopyOpen(_Symbol, PERIOD_D1, 1, n + 1, opens) != n + 1 ||
      CopyClose(_Symbol, PERIOD_D1, 1, n + 1, closes) != n + 1)
      return false;
   if(opens[0] <= 0.0 || closes[0] <= 0.0)
      return false;
   signal_return = closes[0] / opens[0] - 1.0;

   double sum = 0.0;
   for(int i = 1; i <= n; ++i)
     {
      if(opens[i] <= 0.0 || closes[i] <= 0.0)
         return false;
      sum += closes[i] / opens[i] - 1.0;
     }
   const double mean = sum / (double)n;
   double variance_sum = 0.0;
   for(int i = 1; i <= n; ++i)
     {
      const double r = closes[i] / opens[i] - 1.0;
      variance_sum += (r - mean) * (r - mean);
     }
   const double sd = MathSqrt(variance_sum / (double)(n - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;
   z_score = (signal_return - mean) / sd;
   return MathIsValidNumber(z_score) && MathAbs(z_score) >= strategy_entry_z;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_ABRET_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseExpiredPositions();
   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_max_spread_points > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return false;

   const datetime current_h1 = iTime(_Symbol, PERIOD_H1, 0);
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime signal_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_h1 <= 0 || current_d1 <= 0 || signal_d1 <= 0)
      return false;
   // Enter only on the first available H1 bar of the new D1 session.
   if(Strategy_DayKey(current_h1) != Strategy_DayKey(current_d1) ||
      iBarShift(_Symbol, PERIOD_H1, current_d1, false) != 0)
      return false;

   const int signal_key = Strategy_DayKey(signal_d1);
   if(signal_key <= 0 || signal_key == g_last_signal_day_key)
      return false;

   double signal_return = 0.0, z_score = 0.0;
   if(!Strategy_AbnormalReturn(signal_return, z_score))
      return false;

   req.type = (z_score > 0.0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   req.reason = (req.type == QM_BUY) ? "WTI_POS_ABRET_CONT" : "WTI_NEG_ABRET_CONT";
   g_last_signal_day_key = signal_key;
   return true;
  }

void Strategy_ManageOpenPosition() { Strategy_CloseExpiredPositions(); }
bool Strategy_ExitSignal() { return false; }
bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20049\",\"ea\":\"wti-abret-mom\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong ticket = 0;
      QM_TM_OpenPosition(req, ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
