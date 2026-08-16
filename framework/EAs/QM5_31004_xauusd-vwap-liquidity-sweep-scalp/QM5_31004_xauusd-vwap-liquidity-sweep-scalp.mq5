#property strict
#property version   "5.0"
#property description "XAUUSD VWAP Liquidity Sweep Scalper"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 31004;
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
input double InpVWAPBandDev = 2.00;
input int    InpRSIPeriod   = 14;

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

bool Strategy_SessionVWAP(double &vwap, double &deviation)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, 64, bars); // perf-allowed: bounded current-session VWAP reconstruction after the framework new-bar gate.
   if(copied < 3)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime now_parts;
   if(!TimeToStruct(utc_now, now_parts))
      return false;

   double weighted_sum = 0.0;
   double volume_sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime parts;
      if(!TimeToStruct(QM_BrokerToUTC(bars[i].time), parts))
         continue;
      const int minute_of_day = parts.hour * 60 + parts.min;
      if(parts.year != now_parts.year ||
         parts.day_of_year != now_parts.day_of_year ||
         minute_of_day < 13 * 60 || minute_of_day >= 17 * 60)
         continue;
      const double volume = (double)bars[i].tick_volume;
      const double price = (bars[i].high + bars[i].low + bars[i].close) / 3.0;
      if(volume <= 0.0 || price <= 0.0)
         continue;
      weighted_sum += price * volume;
      volume_sum += volume;
     }
   if(volume_sum <= 0.0)
      return false;

   vwap = weighted_sum / volume_sum;
   double variance_sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime parts;
      if(!TimeToStruct(QM_BrokerToUTC(bars[i].time), parts))
         continue;
      const int minute_of_day = parts.hour * 60 + parts.min;
      if(parts.year != now_parts.year ||
         parts.day_of_year != now_parts.day_of_year ||
         minute_of_day < 13 * 60 || minute_of_day >= 17 * 60)
         continue;
      const double volume = (double)bars[i].tick_volume;
      const double price = (bars[i].high + bars[i].low + bars[i].close) / 3.0;
      if(volume <= 0.0 || price <= 0.0)
         continue;
      const double delta = price - vwap;
      variance_sum += volume * delta * delta;
     }
   deviation = MathSqrt(variance_sum / volume_sum);
   return vwap > 0.0 && deviation > 0.0;
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
      Strategy_WideSpread(PERIOD_M5) ||
      InpVWAPBandDev < 1.5 || InpVWAPBandDev > 2.5 ||
      InpRSIPeriod < 7 || InpRSIPeriod > 21)
      return false;

   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return false;
   const int minute_of_day = utc.hour * 60 + utc.min;
   if(minute_of_day < 13 * 60 || minute_of_day >= 17 * 60)
      return false;

   double vwap = 0.0;
   double deviation = 0.0;
   if(!Strategy_SessionVWAP(vwap, deviation))
      return false;

   MqlRates signal_bar[];
   ArraySetAsSeries(signal_bar, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, signal_bar) != 1) // perf-allowed: one closed signal bar.
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_M5, InpRSIPeriod, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(rsi < 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double lower_band = vwap - InpVWAPBandDev * deviation;
   const double upper_band = vwap + InpVWAPBandDev * deviation;
   const double stop_buffer = 1.50;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(signal_bar[0].low <= lower_band &&
      signal_bar[0].close > signal_bar[0].open && rsi <= 30.0)
     {
      const double sl = signal_bar[0].low - stop_buffer;
      const double risk = ask - sl;
      const double reward = vwap - ask;
      if(sl <= 0.0 || risk <= 0.0 || reward < 2.2 * risk)
         return false;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(vwap, digits);
      req.reason = "vwap_lower_band_bullish_sweep";
      return true;
     }

   if(signal_bar[0].high >= upper_band &&
      signal_bar[0].close < signal_bar[0].open && rsi >= 70.0)
     {
      const double sl = signal_bar[0].high + stop_buffer;
      const double risk = sl - bid;
      const double reward = bid - vwap;
      if(risk <= 0.0 || reward < 2.2 * risk)
         return false;
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(vwap, digits);
      req.reason = "vwap_upper_band_bearish_sweep";
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
