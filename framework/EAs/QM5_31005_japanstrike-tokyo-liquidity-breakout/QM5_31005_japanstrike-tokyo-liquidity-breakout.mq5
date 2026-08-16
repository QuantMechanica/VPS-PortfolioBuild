#property strict
#property version   "5.0"
#property description "JapanStrike Tokyo Liquidity Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 31005;
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
input string InpBoxStart = "22:00";
input string InpBoxEnd   = "00:00";

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

bool Strategy_WideSpread(const ENUM_TIMEFRAMES tf)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, tf, 14, 1);
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

bool Strategy_ParseHHMM(const string value, int &minute_of_day)
  {
   string fields[];
   if(StringSplit(value, ':', fields) != 2)
      return false;
   const int hour = (int)StringToInteger(fields[0]);
   const int minute = (int)StringToInteger(fields[1]);
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   minute_of_day = hour * 60 + minute;
   return true;
  }

bool Strategy_PreTokyoRange(const datetime utc_now,
                            double &range_high,
                            double &range_low)
  {
   int start_minute = 0;
   int end_minute = 0;
   if(!Strategy_ParseHHMM(InpBoxStart, start_minute) ||
      !Strategy_ParseHHMM(InpBoxEnd, end_minute))
      return false;

   const int duration_minutes = (end_minute - start_minute + 1440) % 1440;
   if(duration_minutes < 60 || duration_minutes > 240)
      return false;

   MqlDateTime utc;
   if(!TimeToStruct(utc_now, utc))
      return false;
   const datetime day_start = utc_now - utc.hour * 3600 - utc.min * 60 - utc.sec;
   datetime range_end = day_start + end_minute * 60;
   if(end_minute >= 12 * 60)
      range_end -= 86400;
   else if(utc_now < range_end)
      return false;
   const datetime range_start = range_end - duration_minutes * 60;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, 32, bars); // perf-allowed: bounded pre-Tokyo box reconstruction after the framework new-bar gate.
   if(copied < 4)
      return false;

   range_high = -1.0e100;
   range_low = 1.0e100;
   int found = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(bars[i].time);
      if(bar_utc < range_start || bar_utc >= range_end)
         continue;
      range_high = MathMax(range_high, bars[i].high);
      range_low = MathMin(range_low, bars[i].low);
      ++found;
     }
   return found >= MathMax(4, duration_minutes / 15) &&
          range_high > range_low;
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
      Strategy_WideSpread(PERIOD_M15))
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc;
   if(!TimeToStruct(utc_now, utc))
      return false;
   const int minute_of_day = utc.hour * 60 + utc.min;
   if(minute_of_day < 5 || minute_of_day >= 3 * 60)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!Strategy_PreTokyoRange(utc_now, range_high, range_low))
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: one closed-bar breakout comparison.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(close_1 <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double buffer = 2.0 * pip;
   const double midpoint = 0.5 * (range_high + range_low);

   if(close_1 > range_high + buffer && midpoint < ask)
     {
      const double risk = ask - midpoint;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(midpoint, digits);
      req.tp = NormalizeDouble(ask + 2.0 * risk, digits);
      req.reason = "pre_tokyo_high_break_plus_2pips";
      return true;
     }

   if(close_1 < range_low - buffer && midpoint > bid)
     {
      const double risk = midpoint - bid;
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(midpoint, digits);
      req.tp = NormalizeDouble(bid - 2.0 * risk, digits);
      req.reason = "pre_tokyo_low_break_minus_2pips";
      return req.tp > 0.0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return Strategy_EquityExitRequired();
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
   if(!news_allows || !QM_IsNewBar())
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
