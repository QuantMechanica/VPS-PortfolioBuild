#property strict
#property version   "5.0"
#property description "QM5_1058 Gatev FX pairs z-score reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1058;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_D1;
input int    strategy_lookback_bars               = 60;
input double strategy_entry_z                     = 2.0;
input double strategy_exit_z                      = 0.5;
input double strategy_hard_stop_z                 = 4.0;
input double strategy_min_correlation             = 0.60;
input int    strategy_time_stop_bars              = 20;
input int    strategy_rollover_blackout_minutes   = 30;
input int    strategy_news_blackout_minutes       = 120;
input int    strategy_max_spread_points           = 35;
input double strategy_beta_min                    = 0.10;
input double strategy_beta_max                    = 5.00;

struct PairConfig
  {
   string a;
   string b;
   int    slot_a;
   int    slot_b;
   int    idx;
  };

double g_pair_z[2] = {0.0, 0.0};
bool   g_pair_stats_valid[2] = {false, false};

bool ResolvePairForSymbol(const string symbol, PairConfig &cfg)
  {
   if(symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX")
     {
      cfg.a = "EURUSD.DWX";
      cfg.b = "GBPUSD.DWX";
      cfg.slot_a = 0;
      cfg.slot_b = 1;
      cfg.idx = 0;
      return true;
     }

   if(symbol == "AUDUSD.DWX" || symbol == "NZDUSD.DWX")
     {
      cfg.a = "AUDUSD.DWX";
      cfg.b = "NZDUSD.DWX";
      cfg.slot_a = 2;
      cfg.slot_b = 3;
      cfg.idx = 1;
      return true;
     }

   return false;
  }

int SlotForSymbol(const PairConfig &cfg, const string symbol)
  {
   if(symbol == cfg.a)
      return cfg.slot_a;
   if(symbol == cfg.b)
      return cfg.slot_b;
   return -1;
  }

double CurrentMid(const string symbol)
  {
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return (bid + ask) * 0.5;
   if(bid > 0.0)
      return bid;
   if(ask > 0.0)
      return ask;
   return 0.0;
  }

bool LoadClosedCloses(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const int count,
                      double &closes[])
  {
   if(count <= 0)
      return false;

   ArrayResize(closes, count);
   ArraySetAsSeries(closes, true);
   // perf-allowed: pair z-score needs closed close arrays for two symbols;
   // Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   const int copied = CopyClose(symbol, tf, 1, count, closes);
   return (copied == count);
  }

bool ComputePairStats(const PairConfig &cfg,
                      double &z,
                      double &beta,
                      double &corr)
  {
   z = 0.0;
   beta = 0.0;
   corr = 0.0;

   const int lookback = strategy_lookback_bars;
   if(lookback < 10)
      return false;

   double close_a[];
   double close_b[];
   if(!LoadClosedCloses(cfg.a, strategy_signal_tf, lookback + 1, close_a))
      return false;
   if(!LoadClosedCloses(cfg.b, strategy_signal_tf, lookback + 1, close_b))
      return false;

   double mean_a = 0.0;
   double mean_b = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      if(close_a[i] <= 0.0 || close_b[i] <= 0.0)
         return false;
      mean_a += MathLog(close_a[i]);
      mean_b += MathLog(close_b[i]);
     }
   mean_a /= (double)lookback;
   mean_b /= (double)lookback;

   double cov_ab = 0.0;
   double var_b = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double la = MathLog(close_a[i]);
      const double lb = MathLog(close_b[i]);
      cov_ab += (la - mean_a) * (lb - mean_b);
      var_b += (lb - mean_b) * (lb - mean_b);
     }
   if(var_b <= 1e-12)
      return false;

   beta = cov_ab / var_b;
   if(MathAbs(beta) < strategy_beta_min || MathAbs(beta) > strategy_beta_max)
      return false;

   double spread[];
   ArrayResize(spread, lookback);
   double mean_spread = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      spread[i] = MathLog(close_a[i]) - beta * MathLog(close_b[i]);
      mean_spread += spread[i];
     }
   mean_spread /= (double)lookback;

   double var_spread = 0.0;
   for(int i = 0; i < lookback; ++i)
      var_spread += (spread[i] - mean_spread) * (spread[i] - mean_spread);
   if(var_spread <= 1e-12)
      return false;

   const double std_spread = MathSqrt(var_spread / (double)(lookback - 1));
   if(std_spread <= 0.0)
      return false;
   z = (spread[0] - mean_spread) / std_spread;

   double mean_ra = 0.0;
   double mean_rb = 0.0;
   double ret_a[];
   double ret_b[];
   ArrayResize(ret_a, lookback);
   ArrayResize(ret_b, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(close_a[i + 1] <= 0.0 || close_b[i + 1] <= 0.0)
         return false;
      ret_a[i] = MathLog(close_a[i] / close_a[i + 1]);
      ret_b[i] = MathLog(close_b[i] / close_b[i + 1]);
      mean_ra += ret_a[i];
      mean_rb += ret_b[i];
     }
   mean_ra /= (double)lookback;
   mean_rb /= (double)lookback;

   double cov_r = 0.0;
   double var_ra = 0.0;
   double var_rb = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double da = ret_a[i] - mean_ra;
      const double db = ret_b[i] - mean_rb;
      cov_r += da * db;
      var_ra += da * da;
      var_rb += db * db;
     }
   if(var_ra <= 1e-12 || var_rb <= 1e-12)
      return false;
   corr = cov_r / MathSqrt(var_ra * var_rb);
   return true;
  }

bool HasPositionForSymbolSlot(const string symbol, const int slot)
  {
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool PairHasOpenPosition(const PairConfig &cfg)
  {
   return HasPositionForSymbolSlot(cfg.a, cfg.slot_a) ||
          HasPositionForSymbolSlot(cfg.b, cfg.slot_b);
  }

bool ClosePositionForSymbolSlot(const string symbol, const int slot)
  {
   bool closed_any = false;
   const int magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         closed_any = true;
     }
   return closed_any;
  }

bool ClosePairPositions(const PairConfig &cfg)
  {
   bool closed_any = false;
   if(ClosePositionForSymbolSlot(cfg.a, cfg.slot_a))
      closed_any = true;
   if(ClosePositionForSymbolSlot(cfg.b, cfg.slot_b))
      closed_any = true;
   return closed_any;
  }

bool PairTimeStopExceeded(const PairConfig &cfg)
  {
   const long max_seconds = (long)strategy_time_stop_bars * (long)PeriodSeconds(strategy_signal_tf);
   if(max_seconds <= 0)
      return false;

   const string symbols[2] = {cfg.a, cfg.b};
   const int slots[2] = {cfg.slot_a, cfg.slot_b};
   const datetime now = TimeCurrent();
   for(int leg = 0; leg < 2; ++leg)
     {
      const int magic = QM_MagicChecked(qm_ea_id, slots[leg], symbols[leg]);
      if(magic <= 0)
         continue;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != symbols[leg])
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && now - opened >= max_seconds)
            return true;
        }
     }
   return false;
  }

double PairLegLots(const string symbol, const double exposure_scale)
  {
   // 200-pip nominal SL for lot sizing (disaster stop; real exit is Z-score based).
   const double sl_pip_distance = 200.0 * 0.0001;   // 200 pips in price units
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || exposure_scale <= 0.0)
      return 0.0;

   const double sl_points = sl_pip_distance / point;
   const double raw_lots  = QM_LotsForRisk(symbol, sl_points) * exposure_scale;
   return QM_TM_NormalizeVolume(symbol, raw_lots);
  }

bool NewsBlocksSymbol(const string symbol, const datetime broker_time)
  {
   bool allowed = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      allowed = QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance);
   else
      allowed = QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy);
   if(!allowed)
      return true;

   datetime utc = QM_BrokerToUTC(broker_time);
   if(utc <= 0)
      utc = TimeGMT();
   return QM_NewsInWindow(utc,
                          symbol,
                          strategy_news_blackout_minutes,
                          strategy_news_blackout_minutes);
  }

bool OpenPair(const PairConfig &cfg, const int direction, const double beta)
  {
   if(direction == 0)
      return false;

   const datetime now = TimeCurrent();
   if(NewsBlocksSymbol(cfg.a, now) || NewsBlocksSymbol(cfg.b, now))
      return false;

   const double lots_a = PairLegLots(cfg.a, 1.0);
   const double lots_b = PairLegLots(cfg.b, MathAbs(beta));
   if(lots_a <= 0.0 || lots_b <= 0.0)
      return false;

   QM_BasketOrderRequest req_a;
   req_a.symbol = cfg.a;
   req_a.type = (direction > 0) ? QM_BUY : QM_SELL;
   req_a.price = 0.0;
   req_a.sl = 0.0;
   req_a.tp = 0.0;
   req_a.lots = lots_a;
   req_a.reason = (direction > 0) ? "GGR_LONG_PAIR_A" : "GGR_SHORT_PAIR_A";
   req_a.symbol_slot = cfg.slot_a;
   req_a.expiration_seconds = 0;

   QM_BasketOrderRequest req_b;
   req_b.symbol = cfg.b;
   req_b.type = (direction > 0) ? QM_SELL : QM_BUY;
   req_b.price = 0.0;
   req_b.sl = 0.0;
   req_b.tp = 0.0;
   req_b.lots = lots_b;
   req_b.reason = (direction > 0) ? "GGR_LONG_PAIR_B_SHORT" : "GGR_SHORT_PAIR_B_LONG";
   req_b.symbol_slot = cfg.slot_b;
   req_b.expiration_seconds = 0;

   ulong ticket_a = 0;
   ulong ticket_b = 0;
   const bool opened_a = QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, 20, req_a, ticket_a);
   const bool opened_b = opened_a ? QM_BasketOpenPosition(qm_ea_id, QM_NEWS_OFF, 20, req_b, ticket_b) : false;
   if(!opened_b && opened_a)
      ClosePositionForSymbolSlot(cfg.a, cfg.slot_a);
   return opened_a && opened_b;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   const int blackout = MathMax(0, strategy_rollover_blackout_minutes);
   if(blackout > 0 && (minute_of_day >= 1440 - blackout || minute_of_day <= blackout))
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

   PairConfig cfg;
   if(!ResolvePairForSymbol(_Symbol, cfg))
      return false;

   double z = 0.0;
   double beta = 0.0;
   double corr = 0.0;
   const bool stats_ok = ComputePairStats(cfg, z, beta, corr);
   g_pair_stats_valid[cfg.idx] = stats_ok;
   g_pair_z[cfg.idx] = z;
   if(!stats_ok)
      return false;

   if(PairHasOpenPosition(cfg))
      return false;

   if(corr < strategy_min_correlation)
      return false;

   int direction = 0;
   if(z < -strategy_entry_z)
      direction = 1;
   else if(z > strategy_entry_z)
      direction = -1;
   if(direction == 0)
      return false;

   OpenPair(cfg, direction, beta);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, add-on, or partial-close logic.
  }

bool Strategy_ExitSignal()
  {
   PairConfig cfg;
   if(!ResolvePairForSymbol(_Symbol, cfg))
      return false;
   if(!PairHasOpenPosition(cfg))
      return false;

   if(PairTimeStopExceeded(cfg))
     {
      ClosePairPositions(cfg);
      return false;
     }

   if(!g_pair_stats_valid[cfg.idx])
      return false;

   const double abs_z = MathAbs(g_pair_z[cfg.idx]);
   if(abs_z < strategy_exit_z || abs_z > strategy_hard_stop_z)
     {
      ClosePairPositions(cfg);
      return false;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   PairConfig cfg;
   if(!ResolvePairForSymbol(_Symbol, cfg))
      return false;

   return NewsBlocksSymbol(cfg.a, broker_time) || NewsBlocksSymbol(cfg.b, broker_time);
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

   string symbols[4];
   symbols[0] = "EURUSD.DWX";
   symbols[1] = "GBPUSD.DWX";
   symbols[2] = "AUDUSD.DWX";
   symbols[3] = "NZDUSD.DWX";
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_signal_tf, strategy_lookback_bars + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1058_gatev_fx_pairs_zscore\"}");
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
   Strategy_EntrySignal(req);
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
