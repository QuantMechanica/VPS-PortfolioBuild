#property strict
#property version   "5.0"
#property description "QM5_10098 MQL5 Market Memory Zones"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10098 mql5-memory
// Card: artifacts/cards_approved/QM5_10098_mql5-memory.md
// Source: Hlomohang John Borotho, MQL5 Market Memory Zones article.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10098;
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
input ENUM_TIMEFRAMES strategy_ltf              = PERIOD_M5;
input int    strategy_swing_bars                = 3;
input int    strategy_scan_bars                 = 160;
input int    strategy_atr_period                = 14;
input double strategy_atr_buffer_mult           = 0.50;
input int    strategy_zone_expiry_hours         = 12;
input int    strategy_max_trades_per_day        = 3;
input double strategy_midpoint_extension_mult   = 1.0;
input double strategy_fallback_rr               = 2.0;
input int    strategy_spread_cap_points         = 0;

#define STRATEGY_MAX_ZONES 16

struct StrategySwingPoint
  {
   bool     found;
   double   price;
   datetime time;
   int      index;
  };

struct StrategyMemoryZone
  {
   bool     active;
   bool     triggered;
   int      direction;
   double   high;
   double   low;
   double   midpoint;
   double   target;
   double   source_extreme;
   datetime created;
   datetime expires;
   string   source;
  };

StrategyMemoryZone g_zones[STRATEGY_MAX_ZONES];
datetime           g_trade_zone_time = 0;
int                g_trade_zone_direction = 0;
double             g_trade_zone_high = 0.0;
double             g_trade_zone_low = 0.0;

void Strategy_ResetSwing(StrategySwingPoint &p)
  {
   p.found = false;
   p.price = 0.0;
   p.time = 0;
   p.index = -1;
  }

bool Strategy_LoadClosedBars(const ENUM_TIMEFRAMES tf, const int requested, MqlRates &bars[])
  {
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, tf, 1, requested, bars); // perf-allowed: one closed-bar gated structural scan.
   return (copied >= requested);
  }

bool Strategy_IsSwingHigh(const MqlRates &bars[], const int i, const int wing)
  {
   const double price = bars[i].high;
   if(price <= 0.0)
      return false;
   for(int j = 1; j <= wing; ++j)
      if(price <= bars[i - j].high || price <= bars[i + j].high)
         return false;
   return true;
  }

bool Strategy_IsSwingLow(const MqlRates &bars[], const int i, const int wing)
  {
   const double price = bars[i].low;
   if(price <= 0.0)
      return false;
   for(int j = 1; j <= wing; ++j)
      if(price >= bars[i - j].low || price >= bars[i + j].low)
         return false;
   return true;
  }

bool Strategy_FindRecentSwings(const MqlRates &bars[],
                               const int copied,
                               const int wing,
                               StrategySwingPoint &last_high,
                               StrategySwingPoint &last_low)
  {
   Strategy_ResetSwing(last_high);
   Strategy_ResetSwing(last_low);
   if(copied < wing * 2 + 3)
      return false;

   for(int i = wing; i < copied - wing; ++i)
     {
      if(!last_high.found && Strategy_IsSwingHigh(bars, i, wing))
        {
         last_high.found = true;
         last_high.price = bars[i].high;
         last_high.time = bars[i].time;
         last_high.index = i;
        }
      if(!last_low.found && Strategy_IsSwingLow(bars, i, wing))
        {
         last_low.found = true;
         last_low.price = bars[i].low;
         last_low.time = bars[i].time;
         last_low.index = i;
        }
      if(last_high.found && last_low.found)
         return true;
     }
   return (last_high.found && last_low.found);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

double Strategy_MinStopDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return MathMax((double)(stops_level + 1) * point, point);
  }

double Strategy_AdjustStop(const QM_OrderType side, const double entry, const double raw_sl)
  {
   const double min_dist = Strategy_MinStopDistance();
   if(entry <= 0.0 || raw_sl <= 0.0 || min_dist <= 0.0)
      return 0.0;

   double sl = raw_sl;
   if(QM_OrderTypeIsBuy(side) && entry - sl < min_dist)
      sl = entry - min_dist;
   if(!QM_OrderTypeIsBuy(side) && sl - entry < min_dist)
      sl = entry + min_dist;
   return Strategy_NormalizePrice(sl);
  }

void Strategy_AddZone(const int direction,
                      const MqlRates &source_bar,
                      const double source_extreme,
                      const double target,
                      const string source)
  {
   if(direction == 0 || source_bar.high <= source_bar.low || source_bar.time <= 0)
      return;

   const double zone_high = MathMax(source_bar.high, source_bar.low);
   const double zone_low = MathMin(source_bar.high, source_bar.low);
   if(zone_high <= zone_low || zone_low <= 0.0)
      return;

   for(int i = 0; i < STRATEGY_MAX_ZONES; ++i)
     {
      if(g_zones[i].active &&
         g_zones[i].created == source_bar.time &&
         g_zones[i].direction == direction &&
         g_zones[i].source == source)
         return;
     }

   int slot = -1;
   datetime oldest = TimeCurrent() + 100000000;
   const datetime now = TimeCurrent();
   for(int i = 0; i < STRATEGY_MAX_ZONES; ++i)
     {
      if(!g_zones[i].active || (!g_zones[i].triggered && g_zones[i].expires <= now))
        {
         slot = i;
         break;
        }
      if(g_zones[i].created < oldest)
        {
         oldest = g_zones[i].created;
         slot = i;
        }
     }
   if(slot < 0)
      return;

   g_zones[slot].active = true;
   g_zones[slot].triggered = false;
   g_zones[slot].direction = direction;
   g_zones[slot].high = zone_high;
   g_zones[slot].low = zone_low;
   g_zones[slot].midpoint = (zone_high + zone_low) * 0.5;
   g_zones[slot].target = target;
   g_zones[slot].source_extreme = source_extreme;
   g_zones[slot].created = source_bar.time;
   g_zones[slot].expires = source_bar.time + strategy_zone_expiry_hours * 3600;
   g_zones[slot].source = source;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_TradesToday()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const datetime now = TimeCurrent();
   if(!HistorySelect(Strategy_DayStart(now), now))
      return 0;

   int count = 0;
   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
     }
   return count;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

bool Strategy_LtfConfirms(const int direction)
  {
   MqlRates ltf_bars[];
   if(!Strategy_LoadClosedBars(strategy_ltf, 2, ltf_bars))
      return false;
   if(direction > 0)
      return (ltf_bars[0].close > ltf_bars[0].open && ltf_bars[0].close > ltf_bars[1].high);
   if(direction < 0)
      return (ltf_bars[0].close < ltf_bars[0].open && ltf_bars[0].close < ltf_bars[1].low);
   return false;
  }

void Strategy_DetectZones(const MqlRates &bars[],
                          const StrategySwingPoint &last_high,
                          const StrategySwingPoint &last_low)
  {
   if(ArraySize(bars) < 3)
      return;

   const MqlRates break_bar = bars[0];
   const MqlRates prev_bar = bars[1];

   if(last_high.found && break_bar.close > last_high.price && prev_bar.close <= last_high.price)
      Strategy_AddZone(1, prev_bar, prev_bar.low, last_high.price, "CHOCH_BREAK_UP");

   if(last_low.found && break_bar.close < last_low.price && prev_bar.close >= last_low.price)
      Strategy_AddZone(-1, prev_bar, prev_bar.high, last_low.price, "CHOCH_BREAK_DOWN");

   if(last_low.found)
     {
      if(break_bar.low < last_low.price && break_bar.close > last_low.price)
         Strategy_AddZone(1, break_bar, MathMin(break_bar.low, last_low.price),
                          last_high.found ? last_high.price : 0.0, "SWEEP_SAME_UP");
      if(prev_bar.low < last_low.price && break_bar.close > last_low.price)
         Strategy_AddZone(1, prev_bar, MathMin(prev_bar.low, last_low.price),
                          last_high.found ? last_high.price : 0.0, "SWEEP_NEXT_UP");
     }

   if(last_high.found)
     {
      if(break_bar.high > last_high.price && break_bar.close < last_high.price)
         Strategy_AddZone(-1, break_bar, MathMax(break_bar.high, last_high.price),
                          last_low.found ? last_low.price : 0.0, "SWEEP_SAME_DOWN");
      if(prev_bar.high > last_high.price && break_bar.close < last_high.price)
         Strategy_AddZone(-1, prev_bar, MathMax(prev_bar.high, last_high.price),
                          last_low.found ? last_low.price : 0.0, "SWEEP_NEXT_DOWN");
     }
  }

// No Trade Filter (time, spread, news): only card timeframe and optional spread cap.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
      return true;

   return false;
  }

// Trade Entry: active memory-zone return plus lower-timeframe confirmation.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_swing_bars < 1 ||
      strategy_scan_bars < strategy_swing_bars * 2 + 10 ||
      strategy_atr_period < 1 ||
      strategy_atr_buffer_mult <= 0.0 ||
      strategy_zone_expiry_hours <= 0 ||
      strategy_fallback_rr <= 0.0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_max_trades_per_day > 0 && Strategy_TradesToday() >= strategy_max_trades_per_day)
      return false;

   MqlRates bars[];
   if(!Strategy_LoadClosedBars((ENUM_TIMEFRAMES)_Period, strategy_scan_bars, bars))
      return false;

   StrategySwingPoint last_high;
   StrategySwingPoint last_low;
   if(!Strategy_FindRecentSwings(bars, ArraySize(bars), strategy_swing_bars, last_high, last_low))
      return false;

   Strategy_DetectZones(bars, last_high, last_low);

   const datetime now = TimeCurrent();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   int selected = -1;
   datetime selected_created = 0;
   for(int i = 0; i < STRATEGY_MAX_ZONES; ++i)
     {
      if(!g_zones[i].active)
         continue;
      if(!g_zones[i].triggered && g_zones[i].expires <= now)
        {
         g_zones[i].active = false;
         continue;
        }
      if(g_zones[i].triggered || g_zones[i].expires <= now)
         continue;

      const int dir = g_zones[i].direction;
      const double probe = (dir > 0) ? ask : bid;
      if(probe < g_zones[i].low || probe > g_zones[i].high)
         continue;
      if(!Strategy_LtfConfirms(dir))
         continue;
      if(selected < 0 || g_zones[i].created > selected_created)
        {
         selected = i;
         selected_created = g_zones[i].created;
        }
     }

   if(selected < 0)
      return false;

   const StrategyMemoryZone zone = g_zones[selected];
   const bool is_buy = (zone.direction > 0);
   const QM_OrderType side = is_buy ? QM_BUY : QM_SELL;
   const double entry = is_buy ? ask : bid;
   const double anchor = is_buy ? MathMin(zone.low, zone.source_extreme)
                                : MathMax(zone.high, zone.source_extreme);
   const double raw_sl = is_buy ? (anchor - atr * strategy_atr_buffer_mult)
                                : (anchor + atr * strategy_atr_buffer_mult);
   const double sl = Strategy_AdjustStop(side, entry, raw_sl);
   if(sl <= 0.0 || (is_buy && sl >= entry) || (!is_buy && sl <= entry))
      return false;

   const double risk = MathAbs(entry - sl);
   const double zone_height = zone.high - zone.low;
   double tp = 0.0;
   if(is_buy && zone.target > entry)
      tp = zone.target;
   if(!is_buy && zone.target > 0.0 && zone.target < entry)
      tp = zone.target;

   if(tp <= 0.0 && zone_height > 0.0 && strategy_midpoint_extension_mult > 0.0)
      tp = is_buy ? (zone.midpoint + zone_height * strategy_midpoint_extension_mult)
                  : (zone.midpoint - zone_height * strategy_midpoint_extension_mult);

   if((is_buy && tp <= entry) || (!is_buy && (tp <= 0.0 || tp >= entry)))
      tp = is_buy ? (entry + risk * strategy_fallback_rr)
                  : (entry - risk * strategy_fallback_rr);

   const double min_dist = Strategy_MinStopDistance();
   if(min_dist <= 0.0)
      return false;
   if(is_buy && tp - entry < min_dist)
      tp = entry + MathMax(risk * strategy_fallback_rr, min_dist);
   if(!is_buy && entry - tp < min_dist)
      tp = entry - MathMax(risk * strategy_fallback_rr, min_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(tp);
   req.reason = is_buy ? "MEMORY_ZONE_BUY_RETEST" : "MEMORY_ZONE_SELL_RETEST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_zones[selected].triggered = true;
   g_trade_zone_time = zone.created;
   g_trade_zone_direction = zone.direction;
   g_trade_zone_high = zone.high;
   g_trade_zone_low = zone.low;
   return true;
  }

// Trade Management: no trailing, partial close, or break-even rule in the card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close early when the last closed bar invalidates the source zone.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
     {
      g_trade_zone_time = 0;
      g_trade_zone_direction = 0;
      g_trade_zone_high = 0.0;
      g_trade_zone_low = 0.0;
      return false;
     }

   if(g_trade_zone_direction == 0 || g_trade_zone_high <= g_trade_zone_low)
      return false;

   MqlRates last_bar[];
   if(!Strategy_LoadClosedBars((ENUM_TIMEFRAMES)_Period, 1, last_bar))
      return false;

   const double close_1 = last_bar[0].close;
   if(g_trade_zone_direction > 0 && close_1 < g_trade_zone_low)
      return true;
   if(g_trade_zone_direction < 0 && close_1 > g_trade_zone_high)
      return true;

   return false;
  }

// News Filter Hook: callable P8 hook; defer to the framework news gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line
// -----------------------------------------------------------------------------

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
