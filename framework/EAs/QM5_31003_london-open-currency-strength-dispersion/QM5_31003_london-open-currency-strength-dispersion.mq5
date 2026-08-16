#property strict
#property version   "5.0"
#property description "London Open Currency Strength Dispersion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 31003;
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
input int    InpEvalHourGMT   = 8;
input double InpMinDispersion = 0.80;

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

string g_strength_currencies[8] =
  {
   "AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"
  };

string g_strength_pairs[28] =
  {
   "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX",
   "AUDUSD.DWX", "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX",
   "EURAUD.DWX", "EURCAD.DWX", "EURCHF.DWX", "EURGBP.DWX",
   "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX", "GBPAUD.DWX",
   "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
   "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX",
   "NZDUSD.DWX", "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };

int g_strength_signal_day = 0;

int Strategy_UTCDateKey(const datetime value)
  {
   MqlDateTime parts;
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_CurrencyIndex(const string currency)
  {
   for(int i = 0; i < 8; ++i)
      if(g_strength_currencies[i] == currency)
         return i;
   return -1;
  }

bool Strategy_CalculateStrength(double &strength[])
  {
   int counts[8];
   ArrayInitialize(strength, 0.0);
   ArrayInitialize(counts, 0);

   for(int i = 0; i < 28; ++i)
     {
      double closes[];
      ArraySetAsSeries(closes, true);
      if(CopyClose(g_strength_pairs[i], PERIOD_M15, 1, 97, closes) != 97) // perf-allowed: daily bounded 24-hour G8 cross-section read.
         return false;

      const double current_close = closes[0];
      const double old_close = closes[96];
      if(current_close <= 0.0 || old_close <= 0.0)
         return false;

      const int base_index =
         Strategy_CurrencyIndex(StringSubstr(g_strength_pairs[i], 0, 3));
      const int quote_index =
         Strategy_CurrencyIndex(StringSubstr(g_strength_pairs[i], 3, 3));
      if(base_index < 0 || quote_index < 0)
         return false;

      const double roc_percent =
         (current_close / old_close - 1.0) * 100.0;
      strength[base_index] += roc_percent;
      strength[quote_index] -= roc_percent;
      ++counts[base_index];
      ++counts[quote_index];
     }

   for(int i = 0; i < 8; ++i)
     {
      if(counts[i] != 7)
         return false;
      strength[i] /= 7.0;
     }
   return true;
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
      Strategy_WideSpread(PERIOD_M15) ||
      InpEvalHourGMT < 0 || InpEvalHourGMT > 23 ||
      InpMinDispersion <= 0.0)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc_parts;
   if(!TimeToStruct(utc_now, utc_parts) ||
      utc_parts.hour != InpEvalHourGMT || utc_parts.min >= 15)
      return false;

   const int date_key = Strategy_UTCDateKey(utc_now);
   if(date_key == 0 || g_strength_signal_day == date_key)
      return false;

   double strength[8];
   if(!Strategy_CalculateStrength(strength))
      return false;

   int strongest = 0;
   int weakest = 0;
   for(int i = 1; i < 8; ++i)
     {
      if(strength[i] > strength[strongest])
         strongest = i;
      if(strength[i] < strength[weakest])
         weakest = i;
     }

   const string host_base = StringSubstr(_Symbol, 0, 3);
   const string host_quote = StringSubstr(_Symbol, 3, 3);
   const int base_index = Strategy_CurrencyIndex(host_base);
   const int quote_index = Strategy_CurrencyIndex(host_quote);
   if(base_index < 0 || quote_index < 0)
      return false;

   const double side_threshold = 0.5 * InpMinDispersion;
   int signal = 0;
   if(base_index == strongest && quote_index == weakest &&
      strength[base_index] >= side_threshold &&
      strength[quote_index] <= -side_threshold &&
      strength[base_index] - strength[quote_index] >= InpMinDispersion)
      signal = 1;
   else if(base_index == weakest && quote_index == strongest &&
           strength[base_index] <= -side_threshold &&
           strength[quote_index] >= side_threshold &&
           strength[quote_index] - strength[base_index] >= InpMinDispersion)
      signal = -1;
   if(signal == 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, 14, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double stop_distance = 1.5 * atr;
   if(signal > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - stop_distance, digits);
      req.tp = NormalizeDouble(ask + 2.5 * stop_distance, digits);
      req.reason = "g8_strongest_base_weakest_quote";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + stop_distance, digits);
      req.tp = NormalizeDouble(bid - 2.5 * stop_distance, digits);
      req.reason = "g8_weakest_base_strongest_quote";
     }

   g_strength_signal_day = date_key;
   return req.sl > 0.0 && req.tp > 0.0;
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

