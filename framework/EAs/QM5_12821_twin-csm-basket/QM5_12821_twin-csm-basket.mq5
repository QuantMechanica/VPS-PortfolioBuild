#property strict
#property version   "5.0"
#property description "QM5_12821 T-WIN Currency-Strength Cluster Basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12821;
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
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_gap_threshold_pct   = 0.20;
input int    strategy_cluster_size        = 6;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_basket_tp_pct       = 1.25;
input double strategy_basket_stop_pct     = 1.00;
input int    strategy_london_start_hhmm   = 630;
input int    strategy_london_end_hhmm     = 830;
input int    strategy_overlap_start_hhmm  = 930;
input int    strategy_overlap_end_hhmm    = 1000;
input int    strategy_flat_hhmm           = 2100;
input int    strategy_deviation_points    = 20;
input int    strategy_warmup_bars         = 320;

const string QM12821_CCY[8] =
  {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};

const string QM12821_PAIRS[28] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX",
   "USDCHF.DWX","USDCAD.DWX","EURGBP.DWX","EURJPY.DWX","EURCHF.DWX",
   "EURAUD.DWX","EURNZD.DWX","EURCAD.DWX","GBPJPY.DWX","GBPCHF.DWX",
   "GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX","AUDJPY.DWX","AUDCHF.DWX",
   "AUDNZD.DWX","AUDCAD.DWX","NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

int    g_active_strong_idx = -1;
int    g_active_weak_idx   = -1;
bool   g_cycle_stopped     = false;

int QM12821_CcyIndex(const string ccy)
  {
   for(int i = 0; i < 8; ++i)
      if(QM12821_CCY[i] == ccy)
         return i;
   return -1;
  }

int QM12821_PairSlot(const string symbol)
  {
   for(int i = 0; i < 28; ++i)
      if(QM12821_PAIRS[i] == symbol)
         return i;
   return -1;
  }

bool QM12821_FindPair(const string base,
                      const string quote,
                      string &out_symbol,
                      bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < 28; ++i)
     {
      const string symbol = QM12821_PAIRS[i];
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

int QM12821_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   return hh * 60 + mm;
  }

int QM12821_BrokerHhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 100 + dt.min;
  }

bool QM12821_InWindow(const int now_hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = QM12821_HhmmToMinutes(now_hhmm);
   const int start_m = QM12821_HhmmToMinutes(start_hhmm);
   const int end_m = QM12821_HhmmToMinutes(end_hhmm);
   if(start_m <= end_m)
      return (now_m >= start_m && now_m <= end_m);
   return (now_m >= start_m || now_m <= end_m);
  }

bool QM12821_InEntrySession(const datetime broker_time)
  {
   const int now_hhmm = QM12821_BrokerHhmm(broker_time);
   if(QM12821_InWindow(now_hhmm, strategy_london_start_hhmm, strategy_london_end_hhmm))
      return true;
   if(QM12821_InWindow(now_hhmm, strategy_overlap_start_hhmm, strategy_overlap_end_hhmm))
      return true;
   return false;
  }

bool QM12821_ReadPerf(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      double &out_perf)
  {
   out_perf = 0.0;

   if(tf == PERIOD_H1)
     {
      MqlRates h1_rates[];
      MqlRates d1_rates[];
      if(CopyRates(symbol, PERIOD_H1, 1, 1, h1_rates) != 1) // perf-allowed: one closed H1 bar for explicit 28-pair CSM, called only from framework QM_IsNewBar-gated entry path.
         return false;
      if(CopyRates(symbol, PERIOD_D1, 0, 1, d1_rates) != 1) // perf-allowed: current broker-day open for daily-open CSM denominator.
         return false;
      if(d1_rates[0].open <= 0.0 || h1_rates[0].close <= 0.0)
         return false;
      out_perf = ((h1_rates[0].close - d1_rates[0].open) / d1_rates[0].open) * 100.0;
      return true;
     }

   if(tf == PERIOD_D1)
     {
      MqlRates d1_closed[];
      if(CopyRates(symbol, PERIOD_D1, 1, 1, d1_closed) != 1) // perf-allowed: one closed D1 bar for the card's H1/D1 CSM coherence gate.
         return false;
      if(d1_closed[0].open <= 0.0 || d1_closed[0].close <= 0.0)
         return false;
      out_perf = ((d1_closed[0].close - d1_closed[0].open) / d1_closed[0].open) * 100.0;
      return true;
     }

   return false;
  }

bool QM12821_CurrencyStrength(const ENUM_TIMEFRAMES tf,
                              double &strength[],
                              int &out_strong_idx,
                              int &out_weak_idx,
                              double &out_gap)
  {
   ArrayResize(strength, 8);
   ArrayInitialize(strength, 0.0);
   out_strong_idx = -1;
   out_weak_idx = -1;
   out_gap = 0.0;

   for(int i = 0; i < 28; ++i)
     {
      const string symbol = QM12821_PAIRS[i];
      const int base_idx = QM12821_CcyIndex(StringSubstr(symbol, 0, 3));
      const int quote_idx = QM12821_CcyIndex(StringSubstr(symbol, 3, 3));
      if(base_idx < 0 || quote_idx < 0)
         return false;

      double perf = 0.0;
      if(!QM12821_ReadPerf(symbol, tf, perf))
         return false;

      strength[base_idx] += perf;
      strength[quote_idx] -= perf;
     }

   double max_strength = -DBL_MAX;
   double min_strength = DBL_MAX;
   for(int c = 0; c < 8; ++c)
     {
      if(strength[c] > max_strength)
        {
         max_strength = strength[c];
         out_strong_idx = c;
        }
      if(strength[c] < min_strength)
        {
         min_strength = strength[c];
         out_weak_idx = c;
        }
     }

   if(out_strong_idx < 0 || out_weak_idx < 0)
      return false;
   out_gap = max_strength - min_strength;
   return (out_gap >= strategy_gap_threshold_pct);
  }

bool QM12821_StrengthState(int &out_strong_idx,
                           int &out_weak_idx,
                           double &out_gap,
                           double &out_h1_strength[])
  {
   out_strong_idx = -1;
   out_weak_idx = -1;
   out_gap = 0.0;

   double d1_strength[];
   int h1_strong = -1;
   int h1_weak = -1;
   int d1_strong = -1;
   int d1_weak = -1;
   double h1_gap = 0.0;
   double d1_gap = 0.0;

   if(!QM12821_CurrencyStrength(PERIOD_H1, out_h1_strength, h1_strong, h1_weak, h1_gap))
      return false;
   if(!QM12821_CurrencyStrength(PERIOD_D1, d1_strength, d1_strong, d1_weak, d1_gap))
      return false;
   if(h1_strong != d1_strong || h1_weak != d1_weak)
      return false;

   out_strong_idx = h1_strong;
   out_weak_idx = h1_weak;
   out_gap = h1_gap;
   return true;
  }

bool QM12821_HasOwnedPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(QM_FrameworkOwnsMagicSymbol(magic, symbol))
         return true;
     }
   return false;
  }

double QM12821_BasketFloatingPnL()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

int QM12821_CloseAllOwned(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!QM_FrameworkOwnsMagicSymbol(magic, symbol))
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   if(closed > 0)
     {
      g_active_strong_idx = -1;
      g_active_weak_idx = -1;
     }
   return closed;
  }

void QM12821_CheckBasketRisk()
  {
   if(!QM12821_HasOwnedPositions())
     {
      g_active_strong_idx = -1;
      g_active_weak_idx = -1;
      g_cycle_stopped = false;
      return;
     }

   const int now_hhmm = QM12821_BrokerHhmm(TimeCurrent());
   if(QM12821_HhmmToMinutes(now_hhmm) >= QM12821_HhmmToMinutes(strategy_flat_hhmm))
     {
      const int closed = QM12821_CloseAllOwned(QM_EXIT_TIME_STOP);
      if(closed > 0)
         QM_LogEvent(QM_INFO, "BASKET_FLAT_TIME", StringFormat("{\"closed\":%d,\"hhmm\":%d}", closed, now_hhmm));
      return;
     }

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return;

   const double pnl = QM12821_BasketFloatingPnL();
   const double stop_money = -equity * strategy_basket_stop_pct / 100.0;
   const double take_money = equity * strategy_basket_tp_pct / 100.0;

   if(strategy_basket_stop_pct > 0.0 && pnl <= stop_money)
     {
      g_cycle_stopped = true;
      const int closed = QM12821_CloseAllOwned(QM_EXIT_KILLSWITCH);
      QM_LogEvent(QM_WARN, "BASKET_EQUITY_STOP",
                  StringFormat("{\"pnl\":%.2f,\"threshold\":%.2f,\"closed\":%d}", pnl, stop_money, closed));
      return;
     }

   if(strategy_basket_tp_pct > 0.0 && pnl >= take_money)
     {
      const int closed = QM12821_CloseAllOwned(QM_EXIT_TP_HIT);
      QM_LogEvent(QM_INFO, "BASKET_TAKE_PROFIT",
                  StringFormat("{\"pnl\":%.2f,\"threshold\":%.2f,\"closed\":%d}", pnl, take_money, closed));
     }
  }

bool QM12821_OpenBasketLeg(const string counterpart,
                           const string weak_ccy,
                           const int cluster_count)
  {
   string symbol = "";
   bool inverted = false;
   if(!QM12821_FindPair(counterpart, weak_ccy, symbol, inverted))
      return false;

   const int slot = QM12821_PairSlot(symbol);
   if(slot < 0)
      return false;

   if(!SymbolSelect(symbol, true))
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = inverted ? QM_SELL : QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.lots = 0.0;
   req.reason = StringFormat("TWIN_CSM_WEAK_%s_VS_%s", weak_ccy, counterpart);
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   const double entry = QM_BasketMarketPrice(req.symbol, req.type);
   const double atr = QM_ATR(req.symbol, PERIOD_H1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(req.symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(req.symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double sl_points = MathAbs(entry - req.sl) / point;
   const double base_lots = QM_LotsForRisk(req.symbol, sl_points);
   if(base_lots <= 0.0)
      return false;
   req.lots = base_lots / (double)MathMax(1, cluster_count);

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool QM12821_OpenWeakCurrencyCluster(const int strong_idx,
                                     const int weak_idx,
                                     const double &strength[])
  {
   if(strong_idx < 0 || weak_idx < 0 || weak_idx >= 8)
      return false;

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

   const int cluster_count = MathMin(7, MathMax(1, strategy_cluster_size));
   int attempted = 0;
   int opened = 0;
   const string weak_ccy = QM12821_CCY[weak_idx];

   for(int i = 0; i < 8 && attempted < cluster_count; ++i)
     {
      const int counter_idx = order[i];
      if(counter_idx == weak_idx)
         continue;
      attempted++;
      if(QM12821_OpenBasketLeg(QM12821_CCY[counter_idx], weak_ccy, cluster_count))
         opened++;
     }

   if(opened > 0)
     {
      g_active_strong_idx = strong_idx;
      g_active_weak_idx = weak_idx;
      g_cycle_stopped = false;
      QM_LogEvent(QM_INFO, "BASKET_CYCLE_OPEN",
                  StringFormat("{\"strong\":\"%s\",\"weak\":\"%s\",\"attempted\":%d,\"opened\":%d}",
                               QM12821_CCY[strong_idx], weak_ccy, attempted, opened));
      return true;
     }

   return false;
  }

void QM12821_CloseOnStrengthShift(const int strong_idx, const int weak_idx)
  {
   if(!QM12821_HasOwnedPositions())
      return;

   if(g_active_strong_idx < 0 || g_active_weak_idx < 0)
     {
      g_active_strong_idx = strong_idx;
      g_active_weak_idx = weak_idx;
      return;
     }

   if(g_active_strong_idx == strong_idx && g_active_weak_idx == weak_idx)
      return;

   const int old_strong_idx = g_active_strong_idx;
   const int old_weak_idx = g_active_weak_idx;
   const int closed = QM12821_CloseAllOwned(QM_EXIT_OPPOSITE_SIGNAL);
   QM_LogEvent(QM_INFO, "BASKET_STRENGTH_SHIFT_EXIT",
               StringFormat("{\"closed\":%d,\"old_strong\":\"%s\",\"old_weak\":\"%s\",\"new_strong\":\"%s\",\"new_weak\":\"%s\"}",
                            closed,
                            QM12821_CCY[old_strong_idx],
                            QM12821_CCY[old_weak_idx],
                            QM12821_CCY[strong_idx],
                            QM12821_CCY[weak_idx]));
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;

   if(QM12821_HasOwnedPositions())
      return false;

   if(!QM12821_InEntrySession(TimeCurrent()))
      return true;

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

   double h1_strength[];
   int strong_idx = -1;
   int weak_idx = -1;
   double gap = 0.0;
   if(!QM12821_StrengthState(strong_idx, weak_idx, gap, h1_strength))
      return false;

   if(QM12821_HasOwnedPositions())
     {
      QM12821_CloseOnStrengthShift(strong_idx, weak_idx);
      return false;
     }

   if(g_cycle_stopped)
      return false;

   if(!QM12821_InEntrySession(TimeCurrent()))
      return false;

   QM12821_OpenWeakCurrencyCluster(strong_idx, weak_idx, h1_strength);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   QM12821_CheckBasketRisk();
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

   string basket_symbols[28];
   for(int i = 0; i < 28; ++i)
      basket_symbols[i] = QM12821_PAIRS[i];
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_H1, strategy_warmup_bars);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(40, strategy_warmup_bars / 24));

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_12821_twin-csm-basket\",\"scope\":\"fx8_csm_basket\"}");
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
