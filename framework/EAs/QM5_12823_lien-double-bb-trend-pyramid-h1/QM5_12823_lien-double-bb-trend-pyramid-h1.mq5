#property strict
#property version   "5.0"
#property description "QM5_12823 lien double BB trend pyramid H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_12823 lien-double-bb-trend-pyramid-h1
// -----------------------------------------------------------------------------
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_12823_lien-double-bb-trend-pyramid-h1.md (APPROVED).
//
// Base signal: Kathy Lien Double Bollinger Band trend-zone survivor QM5_11476,
// long-only on USDJPY.DWX H1.
//
// Overlay: bounded add-to-winner pyramid. Slot 0 is the host unit; slots 1..4
// are registered add units. Adds are attempted only from Strategy_EntrySignal,
// so the framework's single QM_IsNewBar gate remains the only bar gate.
// =============================================================================

#define QM12823_SYMBOL             "USDJPY.DWX"
#define QM12823_MAX_ADD_SLOTS      4

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12823;
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
input int    strategy_bb_period              = 20;
input double strategy_bb_dev_inner           = 1.0;
input double strategy_bb_dev_outer           = 2.0;
input int    strategy_slope_bars             = 5;
input double strategy_sl_fixed_pips          = 40.0;
input double strategy_sl_cap_pips            = 60.0;
input double strategy_spread_cap_pips        = 20.0;
input bool   strategy_no_friday_entry        = true;
input int    strategy_max_adds               = 3;
input int    strategy_add_size_mode          = 0;      // 0 equal; 1 decreasing 1.0/0.75/0.5
input double strategy_aggregate_risk_cap_pct = 1.0;
input int    strategy_trail_method           = 0;      // 0 band; 1 structure; 2 ATR
input int    strategy_trail_structure_bars   = 10;
input int    strategy_trail_atr_period       = 20;
input double strategy_trail_atr_mult         = 2.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int QM12823_MaxAdds()
  {
   if(strategy_max_adds < 0)
      return 0;
   if(strategy_max_adds > QM12823_MAX_ADD_SLOTS)
      return QM12823_MAX_ADD_SLOTS;
   return strategy_max_adds;
  }

long QM12823_MagicBase()
  {
   return (long)qm_ea_id * 10000L;
  }

bool QM12823_SlotFromMagic(const long magic, int &slot)
  {
   slot = -1;
   const long base = QM12823_MagicBase();
   if(magic < base || magic > base + QM12823_MAX_ADD_SLOTS)
      return false;
   slot = (int)(magic - base);
   return (slot >= 0 && slot <= QM12823_MAX_ADD_SLOTS);
  }

bool QM12823_IsOwnPyramidPosition(int &slot)
  {
   slot = -1;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
      return false;
   return QM12823_SlotFromMagic(PositionGetInteger(POSITION_MAGIC), slot);
  }

double QM12823_Close(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read for Double-BB zone state
  }

bool QM12823_BuyZoneAt(const int shift)
  {
   const double bb1_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, shift);
   const double bb2_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, shift);
   const double close  = QM12823_Close(shift);
   if(bb1_up <= 0.0 || bb2_up <= 0.0 || close <= 0.0)
      return false;
   return (close >= bb1_up && close <= bb2_up);
  }

bool QM12823_MiddleBandSlopeUp()
  {
   if(strategy_slope_bars < 1)
      return true;

   const double mid_now = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double mid_old = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,
                                       1 + strategy_slope_bars);
   if(mid_now <= 0.0 || mid_old <= 0.0)
      return false;
   return (mid_now > mid_old);
  }

bool QM12823_BaseEntryEvent()
  {
   if(!QM12823_BuyZoneAt(1))
      return false;
   if(QM12823_BuyZoneAt(2))
      return false;
   return QM12823_MiddleBandSlopeUp();
  }

bool QM12823_ContinuationState(const double avg_entry)
  {
   if(!QM12823_BuyZoneAt(1))
      return false;
   if(!QM12823_MiddleBandSlopeUp())
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (bid > 0.0 && avg_entry > 0.0 && bid > avg_entry);
  }

double QM12823_BaseLongStop(const double entry)
  {
   if(entry <= 0.0)
      return 0.0;

   double sl = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(sl <= 0.0 || sl >= entry)
      sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_fixed_pips);
   else if(cap_dist > 0.0 && (entry - sl) > cap_dist)
      return 0.0;

   if(sl <= 0.0 || sl >= entry)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

double QM12823_AddSizeFactor(const int add_slot)
  {
   if(strategy_add_size_mode != 1)
      return 1.0;
   if(add_slot <= 1)
      return 1.0;
   if(add_slot == 2)
      return 0.75;
   return 0.50;
  }

double QM12823_AddLongStop(const double entry, const int add_slot)
  {
   double sl = QM12823_BaseLongStop(entry);
   if(sl <= 0.0 || sl >= entry)
      return 0.0;

   const double factor = QM12823_AddSizeFactor(add_slot);
   if(factor > 0.0 && factor < 1.0)
     {
      const double dist = entry - sl;
      sl = entry - (dist / factor);
     }
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

bool QM12823_ReadGroupState(int &count,
                            int &add_count,
                            double &total_volume,
                            double &avg_entry,
                            ulong &host_ticket)
  {
   count = 0;
   add_count = 0;
   total_volume = 0.0;
   avg_entry = 0.0;
   host_ticket = 0;

   double weighted_entry = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      int slot = -1;
      if(!QM12823_IsOwnPyramidPosition(slot))
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      if(volume <= 0.0 || entry <= 0.0)
         continue;

      count++;
      if(slot > 0)
         add_count++;
      if(slot == qm_magic_slot_offset)
         host_ticket = ticket;
      if(host_ticket == 0)
         host_ticket = ticket;

      total_volume += volume;
      weighted_entry += entry * volume;
     }

   if(count <= 0 || total_volume <= 0.0)
      return false;

   avg_entry = weighted_entry / total_volume;
   return (avg_entry > 0.0);
  }

bool QM12823_SlotHasOpenPosition(const int sought_slot)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      int slot = -1;
      if(!QM12823_IsOwnPyramidPosition(slot))
         continue;
      if(slot == sought_slot)
         return true;
     }
   return false;
  }

int QM12823_NextAddSlot()
  {
   const int max_adds = QM12823_MaxAdds();
   for(int slot = 1; slot <= max_adds; ++slot)
      if(!QM12823_SlotHasOpenPosition(slot))
         return slot;
   return -1;
  }

double QM12823_RiskCapMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0 || strategy_aggregate_risk_cap_pct <= 0.0)
      return 0.0;
   return equity * strategy_aggregate_risk_cap_pct / 100.0;
  }

double QM12823_AggregateRiskStop(const double avg_entry, const double total_volume)
  {
   const double risk_cap = QM12823_RiskCapMoney();
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(avg_entry <= 0.0 || total_volume <= 0.0 || risk_cap <= 0.0 ||
      tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;

   const double price_distance = risk_cap * tick_size / (tick_value * total_volume);
   if(price_distance <= 0.0)
      return 0.0;
   return avg_entry - price_distance;
  }

double QM12823_MethodTrailStop()
  {
   if(strategy_trail_method == 1)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return QM_StopStructure(_Symbol, QM_BUY, bid, strategy_trail_structure_bars);
     }
   if(strategy_trail_method == 2)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return QM_StopATR(_Symbol, QM_BUY, bid, strategy_trail_atr_period, strategy_trail_atr_mult);
     }

   return QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
  }

double QM12823_ClampLongStopBelowBid(const double raw_stop)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(raw_stop <= 0.0 || bid <= 0.0 || point <= 0.0)
      return 0.0;

   int stop_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_level_points < 1)
      stop_level_points = 1;
   const double max_stop = bid - (stop_level_points + 1) * point;
   double stop = raw_stop;
   if(stop >= max_stop)
      stop = max_stop;
   if(stop <= 0.0 || stop >= bid)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

bool QM12823_TrailAggregateStop()
  {
   int count = 0;
   int add_count = 0;
   double total_volume = 0.0;
   double avg_entry = 0.0;
   ulong host_ticket = 0;
   if(!QM12823_ReadGroupState(count, add_count, total_volume, avg_entry, host_ticket))
      return false;

   double target = QM12823_AggregateRiskStop(avg_entry, total_volume);
   const double method_stop = QM12823_MethodTrailStop();
   if(method_stop > target)
      target = method_stop;

   target = QM12823_ClampLongStopBelowBid(target);
   if(target <= 0.0)
      return false;

   bool moved_any = false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      int slot = -1;
      if(!QM12823_IsOwnPyramidPosition(slot))
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      if(current_sl > 0.0 && point > 0.0 && target <= current_sl + point * 0.5)
         continue;

      if(QM_TM_MoveSL(ticket, target, "aggregate_pyramid_stop"))
         moved_any = true;
     }
   return moved_any;
  }

bool QM12823_CloseAddSlots()
  {
   bool closed_any = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      int slot = -1;
      if(!QM12823_IsOwnPyramidPosition(slot))
         continue;
      if(slot == qm_magic_slot_offset)
         continue;

      if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         closed_any = true;
     }
   return closed_any;
  }

bool QM12823_TrendExitSignal()
  {
   const double bb1_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double close1 = QM12823_Close(1);
   if(bb1_up <= 0.0 || close1 <= 0.0)
      return false;
   return (close1 < bb1_up);
  }

bool QM12823_TryPyramidAdd()
  {
   int count = 0;
   int add_count = 0;
   double total_volume = 0.0;
   double avg_entry = 0.0;
   ulong host_ticket = 0;
   if(!QM12823_ReadGroupState(count, add_count, total_volume, avg_entry, host_ticket))
      return false;

   const int next_slot = QM12823_NextAddSlot();
   if(next_slot < 1)
      return false;
   if(!QM12823_ContinuationState(avg_entry))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   QM_EntryRequest add_req;
   add_req.type = QM_BUY;
   add_req.price = 0.0;
   add_req.sl = QM12823_AddLongStop(entry, next_slot);
   add_req.tp = 0.0;
   add_req.reason = StringFormat("double_bb_pyramid_add_%d", next_slot);
   add_req.symbol_slot = next_slot;
   add_req.expiration_seconds = 0;

   if(add_req.sl <= 0.0)
      return false;

   const bool ok = QM_TM_AddToPosition(host_ticket, add_req);
   if(ok)
      QM12823_TrailAggregateStop();
   return ok;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != QM12823_SYMBOL)
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   int count = 0;
   int add_count = 0;
   double total_volume = 0.0;
   double avg_entry = 0.0;
   ulong host_ticket = 0;
   const bool has_group = QM12823_ReadGroupState(count, add_count, total_volume, avg_entry, host_ticket);
   if(has_group)
     {
      QM12823_TryPyramidAdd();
      return false;
     }

   if(!QM12823_BaseEntryEvent())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM12823_BaseLongStop(entry);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "double_bb_buy_zone";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   QM12823_TrailAggregateStop();
  }

bool Strategy_ExitSignal()
  {
   int count = 0;
   int add_count = 0;
   double total_volume = 0.0;
   double avg_entry = 0.0;
   ulong host_ticket = 0;
   if(!QM12823_ReadGroupState(count, add_count, total_volume, avg_entry, host_ticket))
      return false;

   if(!QM12823_TrendExitSignal())
      return false;

   QM12823_CloseAddSlots();
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - unchanged except the single-symbol basket guard for slots 0..4.
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

   string pyramid_symbols[1];
   pyramid_symbols[0] = QM12823_SYMBOL;
   QM_SymbolGuardInit(pyramid_symbols);

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
