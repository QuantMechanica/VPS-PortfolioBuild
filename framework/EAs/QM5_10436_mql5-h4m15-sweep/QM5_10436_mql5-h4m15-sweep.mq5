#property strict
#property version   "5.0"
#property description "QM5_10436 H4/M15 Liquidity Sweep"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10436;
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
input int    strategy_swing_range_h4       = 21;
input int    strategy_level_max_age_h4     = 60;
input int    strategy_sl_points            = 1500;
input double strategy_rr                   = 0.2;
input int    strategy_atr_period_m15       = 14;
input double strategy_max_stop_atr_mult    = 4.0;

double g_consumed_swing_low = 0.0;
double g_consumed_swing_high = 0.0;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool HasOpenPositionForThisMagic()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool IsSameLevel(const double a, const double b)
  {
   if(a <= 0.0 || b <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return MathAbs(a - b) <= 0.00000001;
   return MathAbs(a - b) <= point * 0.5;
  }

bool IsSwingHigh(MqlRates &rates[], const int shift, const int range)
  {
   const double level = rates[shift].high;
   if(level <= 0.0)
      return false;

   for(int k = 1; k <= range; ++k)
     {
      if(rates[shift - k].high >= level)
         return false;
      if(rates[shift + k].high >= level)
         return false;
     }

   return true;
  }

bool IsSwingLow(MqlRates &rates[], const int shift, const int range)
  {
   const double level = rates[shift].low;
   if(level <= 0.0)
      return false;

   for(int k = 1; k <= range; ++k)
     {
      if(rates[shift - k].low <= level)
         return false;
      if(rates[shift + k].low <= level)
         return false;
     }

   return true;
  }

bool LoadMostRecentH4Levels(double &swing_low, double &swing_high)
  {
   swing_low = 0.0;
   swing_high = 0.0;

   const int range = MathMax(1, strategy_swing_range_h4);
   const int max_age = MathMax(range + 1, strategy_level_max_age_h4);
   const int bars_needed = max_age + (2 * range) + 4;

   MqlRates h4[];
   ArraySetAsSeries(h4, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, bars_needed, h4); // perf-allowed: bespoke H4 swing scan, called only from closed-bar entry hook.
   if(copied < bars_needed)
      return false;

   const int oldest_candidate = MathMin(max_age, copied - range - 1);
   for(int shift = range + 1; shift <= oldest_candidate; ++shift)
     {
      if(swing_low <= 0.0 && IsSwingLow(h4, shift, range))
        {
         const double level = h4[shift].low;
         if(!IsSameLevel(level, g_consumed_swing_low))
            swing_low = level;
        }

      if(swing_high <= 0.0 && IsSwingHigh(h4, shift, range))
        {
         const double level = h4[shift].high;
         if(!IsSameLevel(level, g_consumed_swing_high))
            swing_high = level;
        }

      if(swing_low > 0.0 && swing_high > 0.0)
         return true;
     }

   return (swing_low > 0.0 || swing_high > 0.0);
  }

bool LoadLastM15SweepBar(MqlRates &bar)
  {
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, 1, m15); // perf-allowed: single completed M15 bar read under framework new-bar gate.
   if(copied != 1)
      return false;
   bar = m15[0];
   return (bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

bool BuildMarketRequest(const QM_OrderType side,
                        const double entry,
                        const double raw_stop,
                        const double swing_level,
                        const string reason,
                        QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || raw_stop <= 0.0)
      return false;

   const double min_stop_distance = strategy_sl_points * point;
   const double structure_distance = MathAbs(entry - raw_stop);
   const double stop_distance = MathMax(min_stop_distance, structure_distance);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(atr <= 0.0 || stop_distance > (strategy_max_stop_atr_mult * atr))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_rr);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   if(side == QM_BUY)
      g_consumed_swing_low = swing_level;
   else
      g_consumed_swing_high = swing_level;

   return true;
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

   if(HasOpenPositionForThisMagic())
      return false;

   double swing_low = 0.0;
   double swing_high = 0.0;
   if(!LoadMostRecentH4Levels(swing_low, swing_high))
      return false;

   MqlRates sweep_bar;
   if(!LoadLastM15SweepBar(sweep_bar))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = MathMax(ask - bid, 0.0);

   if(swing_low > 0.0 && sweep_bar.low < swing_low && sweep_bar.close > swing_low)
     {
      const double raw_stop = sweep_bar.low - spread;
      return BuildMarketRequest(QM_BUY, ask, raw_stop, swing_low, "H4_M15_SWEEP_LONG", req);
     }

   if(swing_high > 0.0 && sweep_bar.high > swing_high && sweep_bar.close < swing_high)
     {
      const double raw_stop = sweep_bar.high + spread;
      return BuildMarketRequest(QM_SELL, bid, raw_stop, swing_high, "H4_M15_SWEEP_SHORT", req);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial, or add-on management.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10436_mql5_h4m15_sweep\"}");
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
