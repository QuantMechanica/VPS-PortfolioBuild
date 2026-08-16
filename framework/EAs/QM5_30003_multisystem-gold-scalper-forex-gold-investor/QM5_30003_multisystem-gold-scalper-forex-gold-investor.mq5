#property strict
#property version   "5.0"
#property description "Multi-System Intraday Gold Scalper (Forex Gold Investor)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 30003;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input bool InpEnableMod1  = true;
input bool InpEnableMod2  = true;
input int  InpMaxHoldHours = 12;

double g_strategy_initial_equity = 0.0;

bool Strategy_RolloverBlackout()
  {
   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return true;
   const int minute_of_day = utc.hour * 60 + utc.min;
   return minute_of_day >= 1435 || minute_of_day <= 5;
  }

bool Strategy_EntryCircuitBreaker()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity * 0.98)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_EquityExitRequired()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity * 0.975)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, 14, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   return ask > bid && (ask - bid) > 1.8 * atr;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_LinearRegressionFade()
  {
   if(!InpEnableMod1)
      return 0;

   const int lookback = 20;
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, PERIOD_M15, 1, lookback, closes) != lookback) // perf-allowed: bounded LinReg channel read after the framework new-bar gate.
      return 0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double x = (double)i;
      const double y = closes[lookback - 1 - i];
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double denominator = lookback * sum_xx - sum_x * sum_x;
   if(MathAbs(denominator) < 1.0e-12)
      return 0;
   const double slope = (lookback * sum_xy - sum_x * sum_y) / denominator;
   const double intercept = (sum_y - slope * sum_x) / lookback;
   const double fitted_now = intercept + slope * (lookback - 1);

   double residual_sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double fitted = intercept + slope * i;
      const double residual = closes[lookback - 1 - i] - fitted;
      residual_sum += residual * residual;
     }
   const double residual_sd = MathSqrt(residual_sum / lookback);
   if(residual_sd <= 0.0)
      return 0;

   if(closes[0] <= fitted_now - 1.5 * residual_sd)
      return 1;
   if(closes[0] >= fitted_now + 1.5 * residual_sd)
      return -1;
   return 0;
  }

int Strategy_AsianRangeBreakout()
  {
   if(!InpEnableMod2)
      return 0;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime now_parts;
   if(!TimeToStruct(utc_now, now_parts) ||
      now_parts.hour < 6 || now_parts.hour >= 12)
      return 0;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int requested = 48;
   if(CopyRates(_Symbol, PERIOD_M15, 1, requested, bars) != requested) // perf-allowed: bounded same-day Asian range read after the framework new-bar gate.
      return 0;

   double range_high = -1.0e100;
   double range_low = 1.0e100;
   int found = 0;
   for(int i = 0; i < requested; ++i)
     {
      MqlDateTime bar_parts;
      if(!TimeToStruct(QM_BrokerToUTC(bars[i].time), bar_parts))
         continue;
      if(bar_parts.year != now_parts.year ||
         bar_parts.day_of_year != now_parts.day_of_year ||
         bar_parts.hour >= 6)
         continue;
      range_high = MathMax(range_high, bars[i].high);
      range_low = MathMin(range_low, bars[i].low);
      ++found;
     }

   if(found < 8)
      return 0;
   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: one closed-bar breakout read.
   if(close_1 > range_high)
      return 1;
   if(close_1 < range_low)
      return -1;
   return 0;
  }

int Strategy_H4VolatilitySurge()
  {
   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
      return 0;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, 2, bars) != 2) // perf-allowed: two-bar H4 surge read after the framework H4 new-bar gate.
      return 0;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(atr <= 0.0 || bars[0].high - bars[0].low < 1.5 * atr)
      return 0;
   if(bars[0].close > bars[0].open && bars[0].close > bars[1].high)
      return 1;
   if(bars[0].close < bars[0].open && bars[0].close < bars[1].low)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(Strategy_RolloverBlackout())
      return true;
   return Strategy_EntryCircuitBreaker();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1 ||
      Strategy_WideSpread())
      return false;

   int signal = Strategy_LinearRegressionFade();
   string reason = "linreg_channel_fade";
   if(signal == 0)
     {
      signal = Strategy_AsianRangeBreakout();
      reason = "asian_session_range_break";
     }
   if(signal == 0)
     {
      signal = Strategy_H4VolatilitySurge();
      reason = "h4_volatility_surge";
     }
   if(signal == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double sl_distance = 250.0 * _Point;
   const double tp_distance = 300.0 * _Point;
   if(signal > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - sl_distance, digits);
      req.tp = NormalizeDouble(ask + tp_distance, digits);
      req.reason = reason + "_long";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + sl_distance, digits);
      req.tp = NormalizeDouble(bid - tp_distance, digits);
      req.reason = reason + "_short";
     }

   return req.sl > 0.0 && req.tp > 0.0;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(Strategy_EquityExitRequired() || InpMaxHoldHours <= 0)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 &&
         TimeCurrent() - opened_at >= (datetime)(InpMaxHoldHours * 3600))
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
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

