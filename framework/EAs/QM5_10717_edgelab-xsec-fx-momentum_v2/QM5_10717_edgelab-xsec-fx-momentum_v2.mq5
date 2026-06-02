#property strict
#property version   "5.0"
#property description "QM5_10717_v2 Edge Lab Cross-Section FX Momentum"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10717;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_FTMO_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_days       = 63;
input int    strategy_rebalance_dow       = 1;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.0;
input int    strategy_deviation_points    = 30;
input bool   strategy_volfilter_enabled   = true;
input int    strategy_vol_window          = 20;
input int    strategy_vol_percentile_days = 252;
input double strategy_vol_skip_pct        = 0.90;
input int    strategy_max_spread_points   = 0;

const string QM10717_CCY[8] =
  {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};

const string QM10717_PAIRS[28] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX",
   "USDCHF.DWX","USDCAD.DWX","EURGBP.DWX","EURJPY.DWX","EURCHF.DWX",
   "EURAUD.DWX","EURNZD.DWX","EURCAD.DWX","GBPJPY.DWX","GBPCHF.DWX",
   "GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX","AUDJPY.DWX","AUDCHF.DWX",
   "AUDNZD.DWX","AUDCAD.DWX","NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

const string QM10717_USD_PAIRS[7] =
  {"EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
   "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX"};

int QM10717_CcyIndex(const string ccy)
  {
   for(int i = 0; i < 8; ++i)
      if(QM10717_CCY[i] == ccy)
         return i;
   return -1;
  }

int QM10717_PairSlot(const string symbol)
  {
   for(int i = 0; i < 28; ++i)
      if(QM10717_PAIRS[i] == symbol)
         return i;
   return -1;
  }

bool QM10717_FindPair(const string base,
                      const string quote,
                      string &out_symbol,
                      bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < 28; ++i)
     {
      const string symbol = QM10717_PAIRS[i];
      const string sym_base = StringSubstr(symbol, 0, 3);
      const string sym_quote = StringSubstr(symbol, 3, 3);
      if(sym_base == base && sym_quote == quote)
        {
         out_symbol = symbol;
         return true;
        }
      if(sym_base == quote && sym_quote == base)
        {
         out_symbol = symbol;
         out_inverted = true;
         return true;
        }
     }
   return false;
  }

bool QM10717_ReadClosePair(const string symbol,
                           const int lookback,
                           double &out_recent,
                           double &out_past)
  {
   out_recent = 0.0;
   out_past = 0.0;
   if(lookback < 1)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed
   if(copied < lookback + 1)
      return false;

   out_recent = closes[0];
   out_past = closes[lookback];
   return (out_recent > 0.0 && out_past > 0.0);
  }

bool QM10717_CurrencyStrength(double &strength[])
  {
   ArrayInitialize(strength, 0.0);

   double pair_ret[8][8];
   for(int r = 0; r < 8; ++r)
      for(int c = 0; c < 8; ++c)
         pair_ret[r][c] = 0.0;

   for(int i = 0; i < 28; ++i)
     {
      const string symbol = QM10717_PAIRS[i];
      const int base_idx = QM10717_CcyIndex(StringSubstr(symbol, 0, 3));
      const int quote_idx = QM10717_CcyIndex(StringSubstr(symbol, 3, 3));
      if(base_idx < 0 || quote_idx < 0)
         return false;

      double recent;
      double past;
      if(!QM10717_ReadClosePair(symbol, strategy_lookback_days, recent, past))
         return false;

      const double base_vs_quote = (recent / past) - 1.0;
      pair_ret[base_idx][quote_idx] = base_vs_quote;
      pair_ret[quote_idx][base_idx] = (past / recent) - 1.0;
     }

   for(int ccy = 0; ccy < 8; ++ccy)
     {
      double sum = 0.0;
      int n = 0;
      for(int other = 0; other < 8; ++other)
        {
         if(ccy == other)
            continue;
         sum += pair_ret[ccy][other];
         n++;
        }
      if(n != 7)
         return false;
      strength[ccy] = sum / 7.0;
     }

   return true;
  }

bool QM10717_LoadVolCloses(const string symbol, double &closes[])
  {
   ArrayResize(closes, 0);
   ArraySetAsSeries(closes, true);
   const int needed = strategy_vol_window + strategy_vol_percentile_days + 1;
   if(needed < 3)
      return false;
   const int copied = CopyClose(symbol, PERIOD_D1, 1, needed, closes); // perf-allowed
   return (copied >= needed);
  }

bool QM10717_VolFromCloses(const double &closes[],
                           const int start_idx,
                           const int window,
                           double &out_vol)
  {
   out_vol = 0.0;
   if(window < 2 || start_idx < 0 || ArraySize(closes) < start_idx + window + 1)
      return false;

   double sum = 0.0;
   double sumsq = 0.0;
   for(int k = 0; k < window; ++k)
     {
      const double c0 = closes[start_idx + k];
      const double c1 = closes[start_idx + k + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      const double ret = (c0 / c1) - 1.0;
      sum += ret;
      sumsq += ret * ret;
     }

   const double mean = sum / window;
   const double variance = (sumsq / window) - (mean * mean);
   out_vol = (variance > 0.0) ? MathSqrt(variance) : 0.0;
   return true;
  }

bool QM10717_BasketVolAtIndex(double &usd_closes_0[],
                              double &usd_closes_1[],
                              double &usd_closes_2[],
                              double &usd_closes_3[],
                              double &usd_closes_4[],
                              double &usd_closes_5[],
                              double &usd_closes_6[],
                              const int start_idx,
                              double &out_vol)
  {
   out_vol = 0.0;
   double vol = 0.0;
   double sum = 0.0;

   if(!QM10717_VolFromCloses(usd_closes_0, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_1, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_2, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_3, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_4, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_5, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;
   if(!QM10717_VolFromCloses(usd_closes_6, start_idx, strategy_vol_window, vol)) return false;
   sum += vol;

   out_vol = sum / 7.0;
   return true;
  }

bool QM10717_VolFilterRed()
  {
   if(strategy_vol_window < 2 || strategy_vol_percentile_days < 20)
      return false;

   double c0[], c1[], c2[], c3[], c4[], c5[], c6[];
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[0], c0)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[1], c1)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[2], c2)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[3], c3)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[4], c4)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[5], c5)) return false;
   if(!QM10717_LoadVolCloses(QM10717_USD_PAIRS[6], c6)) return false;

   double current_vol = 0.0;
   if(!QM10717_BasketVolAtIndex(c0, c1, c2, c3, c4, c5, c6, 0, current_vol))
      return false;

   int le = 0;
   int total = 0;
   for(int day = 0; day < strategy_vol_percentile_days; ++day)
     {
      double hist_vol = 0.0;
      if(!QM10717_BasketVolAtIndex(c0, c1, c2, c3, c4, c5, c6, day, hist_vol))
         break;
      total++;
      if(hist_vol <= current_vol)
         le++;
     }

   if(total < 20)
      return false;
   const double pct = (double)le / (double)total;
   return (pct >= strategy_vol_skip_pct);
  }

void QM10717_CloseAll()
  {
   const long magic_min = (long)qm_ea_id * 10000L;
   const long magic_max = magic_min + 27L;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic >= magic_min && magic <= magic_max)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool QM10717_OpenLeg(const string strong_ccy,
                     const string weak_ccy)
  {
   string symbol;
   bool inverted = false;
   if(!QM10717_FindPair(strong_ccy, weak_ccy, symbol, inverted))
      return false;

   const int slot = QM10717_PairSlot(symbol);
   if(slot < 0)
      return false;

   SymbolSelect(symbol, true);

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = inverted ? QM_SELL : QM_BUY;
   req.price = QM_BasketMarketPrice(symbol, req.type);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATR(symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.lots = 0.0;
   req.reason = StringFormat("XSEC_MOM_%s_%s", strong_ccy, weak_ccy);
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool QM10717_Rebalance()
  {
   QM10717_CloseAll();

   if(strategy_volfilter_enabled && QM10717_VolFilterRed())
     {
      QM_LogEvent(QM_INFO, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"vol_filter_red\"}");
      return false;
     }

   double strength[8];
   if(!QM10717_CurrencyStrength(strength))
     {
      QM_LogEvent(QM_WARN, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"insufficient_history\"}");
      return false;
     }

   int order[8];
   for(int i = 0; i < 8; ++i)
      order[i] = i;
   for(int a = 0; a < 7; ++a)
      for(int b = 0; b < 7 - a; ++b)
         if(strength[order[b]] < strength[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   const int strong_1 = order[0];
   const int strong_2 = order[1];
   const int weak_2 = order[6];
   const int weak_1 = order[7];

   const bool leg_1_ok = QM10717_OpenLeg(QM10717_CCY[strong_1], QM10717_CCY[weak_1]);
   const bool leg_2_ok = QM10717_OpenLeg(QM10717_CCY[strong_2], QM10717_CCY[weak_2]);

   const string payload = StringFormat(
      "{\"action\":\"rebalance\",\"lookback_days\":%d,"
      "\"long1\":\"%s\",\"short1\":\"%s\",\"long2\":\"%s\",\"short2\":\"%s\","
      "\"leg1_ok\":%s,\"leg2_ok\":%s}",
      strategy_lookback_days,
      QM10717_CCY[strong_1],
      QM10717_CCY[weak_1],
      QM10717_CCY[strong_2],
      QM10717_CCY[weak_2],
      leg_1_ok ? "true" : "false",
      leg_2_ok ? "true" : "false");
   QM_LogEvent(QM_INFO, "BASKET_REBALANCE", payload);

   return (leg_1_ok || leg_2_ok);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.day_of_week != strategy_rebalance_dow)
      return false;

   QM10717_Rebalance();
   return false;
  }

void Strategy_ManageOpenPosition()
  {
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

   string basket_list[28];
   for(int i = 0; i < 28; ++i)
      basket_list[i] = QM10717_PAIRS[i];
   QM_SymbolGuardInit(basket_list);
   QM_BasketWarmupHistory(basket_list, PERIOD_D1, 320);

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_10717_edgelab-xsec-fx-momentum\",\"scope\":\"fx8_basket\"}");
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

