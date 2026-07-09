#property strict
#property version   "5.0"
#property description "QM5_9351 DeMark TD Demand/Supply Active Line Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9351;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H4;
input int    strategy_scan_bars                = 120;
input int    strategy_atr_period               = 14;
input int    strategy_min_line_age_bars        = 3;
input double strategy_break_atr_mult           = 0.10;
input double strategy_sl_atr_buffer            = 0.30;
input double strategy_spread_atr_mult          = 0.15;
input int    strategy_time_stop_bars           = 40;

struct TDLine
  {
   bool   valid;
   int    recent_idx;
   int    older_idx;
   double recent_price;
   double older_price;
   double slope_per_bar;
  };

void TDLine_Reset(TDLine &line)
  {
   line.valid = false;
   line.recent_idx = -1;
   line.older_idx = -1;
   line.recent_price = 0.0;
   line.older_price = 0.0;
   line.slope_per_bar = 0.0;
  }

double TDLine_ValueAt(const TDLine &line, const int idx)
  {
   if(!line.valid)
      return 0.0;
   return line.recent_price + ((double)(idx - line.recent_idx) * line.slope_per_bar);
  }

bool IsSupplyPivot(MqlRates &rates[], const int count, const int idx)
  {
   if(idx <= 0 || idx >= count - 1)
      return false;
   return (rates[idx].high > rates[idx - 1].high && rates[idx].high > rates[idx + 1].high);
  }

bool IsDemandPivot(MqlRates &rates[], const int count, const int idx)
  {
   if(idx <= 0 || idx >= count - 1)
      return false;
   return (rates[idx].low < rates[idx - 1].low && rates[idx].low < rates[idx + 1].low);
  }

bool FindSupplyLine(MqlRates &rates[], const int count, TDLine &line)
  {
   TDLine_Reset(line);
   for(int i = 1; i < count - 1; ++i)
     {
      if(!IsSupplyPivot(rates, count, i))
         continue;
      if(line.recent_idx < 0)
        {
         line.recent_idx = i;
         line.recent_price = rates[i].high;
         continue;
        }
      line.older_idx = i;
      line.older_price = rates[i].high;
      break;
     }

   if(line.recent_idx < strategy_min_line_age_bars || line.older_idx <= line.recent_idx)
      return false;
   if(line.recent_price <= line.older_price)
      return false;

   line.slope_per_bar = (line.older_price - line.recent_price) /
                        (double)(line.older_idx - line.recent_idx);
   line.valid = true;
   return true;
  }

bool FindDemandLine(MqlRates &rates[], const int count, TDLine &line)
  {
   TDLine_Reset(line);
   for(int i = 1; i < count - 1; ++i)
     {
      if(!IsDemandPivot(rates, count, i))
         continue;
      if(line.recent_idx < 0)
        {
         line.recent_idx = i;
         line.recent_price = rates[i].low;
         continue;
        }
      line.older_idx = i;
      line.older_price = rates[i].low;
      break;
     }

   if(line.recent_idx < strategy_min_line_age_bars || line.older_idx <= line.recent_idx)
      return false;
   if(line.recent_price >= line.older_price)
      return false;

   line.slope_per_bar = (line.older_price - line.recent_price) /
                        (double)(line.older_idx - line.recent_idx);
   line.valid = true;
   return true;
  }

bool FindRecentDemandPivot(MqlRates &rates[], const int count, double &out_low)
  {
   out_low = 0.0;
   for(int i = 1; i < count - 1; ++i)
     {
      if(IsDemandPivot(rates, count, i))
        {
         out_low = rates[i].low;
         return true;
        }
     }
   return false;
  }

bool FindRecentSupplyPivot(MqlRates &rates[], const int count, double &out_high)
  {
   out_high = 0.0;
   for(int i = 1; i < count - 1; ++i)
     {
      if(IsSupplyPivot(rates, count, i))
        {
         out_high = rates[i].high;
         return true;
        }
     }
   return false;
  }

bool HasOpenStrategyPosition()
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

bool SpreadAllowsEntry(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr_value)
      return false;
   return true;
  }

double ThreeBarLow(MqlRates &rates[], const int count)
  {
   if(count < 3)
      return 0.0;
   double value = rates[0].low;
   for(int i = 1; i < 3; ++i)
      if(rates[i].low < value)
         value = rates[i].low;
   return value;
  }

double ThreeBarHigh(MqlRates &rates[], const int count)
  {
   if(count < 3)
      return 0.0;
   double value = rates[0].high;
   for(int i = 1; i < 3; ++i)
      if(rates[i].high > value)
         value = rates[i].high;
   return value;
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   if(strategy_scan_bars < 20 ||
      strategy_atr_period <= 0 ||
      strategy_min_line_age_bars < 1 ||
      strategy_break_atr_mult <= 0.0 ||
      strategy_sl_atr_buffer < 0.0 ||
      strategy_time_stop_bars <= 0)
      return false;

   if(HasOpenStrategyPosition())
      return false;

   const double atr_value = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0 || !SpreadAllowsEntry(atr_value))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, strategy_scan_bars, rates); // perf-allowed: bounded structural H4 scan inside framework new-bar entry gate
   if(copied < 30)
      return false;

   const double break_buffer = strategy_break_atr_mult * atr_value;
   const double close_now = rates[0].close;
   const double close_prev = rates[1].close;

   TDLine supply;
   TDLine demand;
   const bool have_supply = FindSupplyLine(rates, copied, supply);
   const bool have_demand = FindDemandLine(rates, copied, demand);

   if(have_supply)
     {
      const double line_now = TDLine_ValueAt(supply, 0);
      const double line_prev = TDLine_ValueAt(supply, 1);
      if(line_now > 0.0 &&
         close_now > line_now + break_buffer &&
         close_prev <= line_prev)
        {
         double demand_low = 0.0;
         if(!FindRecentDemandPivot(rates, copied, demand_low) || demand_low >= close_now)
            return false;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         const double stop_base = ThreeBarLow(rates, copied);
         const double raw_sl = stop_base - strategy_sl_atr_buffer * atr_value;
         const double target_distance = close_now - demand_low;
         const double raw_tp = entry + target_distance;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, raw_tp);
         if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
            return false;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "TD_SUPPLY_ACTIVE_BREAK";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
        }
     }

   if(have_demand)
     {
      const double line_now = TDLine_ValueAt(demand, 0);
      const double line_prev = TDLine_ValueAt(demand, 1);
      if(line_now > 0.0 &&
         close_now < line_now - break_buffer &&
         close_prev >= line_prev)
        {
         double supply_high = 0.0;
         if(!FindRecentSupplyPivot(rates, copied, supply_high) || supply_high <= close_now)
            return false;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         const double stop_base = ThreeBarHigh(rates, copied);
         const double raw_sl = stop_base + strategy_sl_atr_buffer * atr_value;
         const double target_distance = supply_high - close_now;
         const double raw_tp = entry - target_distance;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, raw_tp);
         if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
            return false;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "TD_DEMAND_ACTIVE_BREAK";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(seconds_per_bar <= 0)
      return false;
   const int hold_seconds = strategy_time_stop_bars * seconds_per_bar;
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (now - opened) >= hold_seconds)
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
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
