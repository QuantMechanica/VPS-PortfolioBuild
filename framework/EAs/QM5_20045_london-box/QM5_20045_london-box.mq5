#property strict
#property version   "5.0"
#property description "QM5_20045 fixed-UTC London box breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_LondonCalendars.mqh>

// =============================================================================
// QuantMechanica V5 framework inputs
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20045;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
// Backtest setfiles keep RISK_PERCENT at zero and RISK_FIXED at USD 1,000.
// A later governed live setfile may select 0.5% only by setting RISK_FIXED=0.
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_variant_id          = "LONDON_BOX_027_BASELINE";
input ENUM_TIMEFRAMES strategy_timeframe  = PERIOD_M15;
input int    strategy_box_start_hour_utc  = 3;
input int    strategy_box_end_hour_utc    = 6;
input double strategy_extension_fraction  = 0.27;
input double strategy_max_box_pips        = 40.0;
input double strategy_pip_size            = 0.0001;
input int    strategy_pending_expiry_hour_london = 12;
input int    strategy_flat_hour_london    = 16;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points   = 0;

// =============================================================================
// Deterministic strategy state
// =============================================================================

int    g_consumed_date_key = 0;
int    g_box_date_key = 0;
double g_box_high = 0.0;
double g_box_low = 0.0;
double g_box_size = 0.0;
ulong  g_fill_checked_ticket = 0;

void Strategy_LogEntryReject(const int date_key,
                             const string detail,
                             const string diagnostics = "")
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"LONDON_BOX_027_OCO\",\"detail\":\"%s\",\"date_key\":%d,\"broker_now\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            (long)TimeCurrent(),
                            diagnostics));
  }

// =============================================================================
// Broker-clock helpers
// =============================================================================

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_DateStartUtc(const int date_key)
  {
   if(date_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   return StructToTime(parts);
  }

datetime Strategy_LastSundayAtOneUtc(const int year, const int month)
  {
   MqlDateTime next_month;
   ZeroMemory(next_month);
   next_month.year = year;
   next_month.mon = month + 1;
   if(next_month.mon > 12)
     {
      next_month.mon = 1;
      ++next_month.year;
     }
   next_month.day = 1;
   const datetime next_month_start = StructToTime(next_month);
   if(next_month_start <= 86400)
      return 0;

   MqlDateTime last_day;
   if(!TimeToStruct(next_month_start - 86400, last_day))
      return 0;
   last_day.day -= last_day.day_of_week;
   last_day.hour = 1;
   last_day.min = 0;
   last_day.sec = 0;
   return StructToTime(last_day);
  }

bool Strategy_IsLondonDstUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime start_utc = Strategy_LastSundayAtOneUtc(parts.year, 3);
   const datetime end_utc = Strategy_LastSundayAtOneUtc(parts.year, 10);
   return (start_utc > 0 && end_utc > start_utc &&
           utc >= start_utc && utc < end_utc);
  }

datetime Strategy_LondonLocal(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + (Strategy_IsLondonDstUtc(utc) ? 3600 : 0);
  }

datetime Strategy_LondonHourToUtc(const int date_key, const int london_hour)
  {
   const datetime day_start = Strategy_DateStartUtc(date_key);
   if(day_start <= 0 || london_hour < 0 || london_hour > 23)
      return 0;
   const datetime nominal = day_start + london_hour * 3600;
   return nominal - (Strategy_IsLondonDstUtc(nominal) ? 3600 : 0);
  }

bool Strategy_IsUtcWeekday(const int date_key)
  {
   const datetime utc_start = Strategy_DateStartUtc(date_key);
   MqlDateTime parts;
   if(utc_start <= 0 || !TimeToStruct(utc_start, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

// =============================================================================
// Position, order, and history helpers
// =============================================================================

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GBPUSD.DWX" || symbol == "EURGBP.DWX");
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_FindOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

int Strategy_OurPendingCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

int Strategy_PendingSetupDateKey()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         !Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      const datetime setup_broker = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      return Strategy_DateKey(QM_BrokerToUTC(setup_broker));
     }
   return 0;
  }

void Strategy_CancelOurPending(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         !Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_DateAlreadyUsed(const int date_key)
  {
   if(date_key <= 0)
      return true;
   if(g_consumed_date_key == date_key)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(Strategy_DateKey(QM_BrokerToUTC((datetime)OrderGetInteger(ORDER_TIME_SETUP))) ==
         date_key)
         return true;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(Strategy_DateKey(QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME))) ==
         date_key)
         return true;
     }

   const datetime utc_from = Strategy_DateStartUtc(date_key);
   const datetime utc_to = utc_from + 86400;
   if(utc_from <= 0 ||
      !HistorySelect(QM_UTCToBroker(utc_from), QM_UTCToBroker(utc_to)))
      return true;

   for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(Strategy_IsStopOrderType(type) ||
         type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         return true;
     }

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

// =============================================================================
// Price, spread, volume, and box helpers
// =============================================================================

double Strategy_RoundPriceUp(const double price, const double tick_size)
  {
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_TM_NormalizePrice(_Symbol,
                               MathCeil((price - 1.0e-12) / tick_size) * tick_size);
  }

double Strategy_RoundPriceDown(const double price, const double tick_size)
  {
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_TM_NormalizePrice(_Symbol,
                               MathFloor((price + 1.0e-12) / tick_size) * tick_size);
  }

bool Strategy_TradeGeometryAllows(const double entry_price,
                                  const double stop_price,
                                  const double target_price,
                                  string &out_reject_detail)
  {
   out_reject_detail = "";
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 ||
       entry_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0)
     {
      out_reject_detail = "invalid_geometry_inputs";
      return false;
     }

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   if(stop_distance <= 0.0 || target_distance <= 0.0)
     {
      out_reject_detail = "non_positive_distance";
      return false;
     }

   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_distance / point + 1.0e-8 < (double)stop_level ||
      target_distance / point + 1.0e-8 < (double)stop_level)
     {
      out_reject_detail = "broker_stop_level";
      return false;
     }
   return true;
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_VolumeAllows(const double volume,
                           string &out_reject_detail)
  {
   out_reject_detail = "";
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume <= 0.0)
     {
      out_reject_detail = "risk_sizing_unavailable";
      return false;
     }
   if(volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
     {
      out_reject_detail = "invalid_volume_metadata";
      return false;
     }
   if(volume < volume_min - 1.0e-8 || volume > volume_max + 1.0e-8)
     {
      out_reject_detail = "sized_volume_out_of_range";
      return false;
     }

   const double steps = volume / volume_step;
   if(MathAbs(steps - MathRound(steps)) > 1.0e-6)
     {
      out_reject_detail = "sized_volume_step_misaligned";
      return false;
     }
   return true;
  }

bool Strategy_PlacementSideAllows(const double entry_price,
                                  const double stop_price,
                                  const double target_price,
                                  const ENUM_ORDER_TYPE order_type,
                                  double &lots,
                                  string &out_reject_detail)
  {
   lots = 0.0;
   out_reject_detail = "";
   if(!Strategy_TradeGeometryAllows(entry_price,
                                    stop_price,
                                    target_price,
                                    out_reject_detail))
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      out_reject_detail = "invalid_point";
      return false;
     }
   lots = QM_LotsForRiskAtEntry(_Symbol,
                                MathAbs(entry_price - stop_price) / point,
                                order_type,
                                entry_price,
                                QM_RISK_MODE_FIXED,
                                RISK_FIXED);
   return Strategy_VolumeAllows(lots, out_reject_detail);
  }

bool Strategy_OrderVolume(const ulong ticket, double &volume)
  {
   volume = 0.0;
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
   return (volume > 0.0);
  }

bool Strategy_BuildBox(int &date_key,
                       double &box_high,
                       double &box_low,
                       double &box_size)
  {
   date_key = 0;
   box_high = 0.0;
   box_low = 0.0;
   box_size = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: exact twelve-bar fixed-UTC box, called once behind
   // the framework M15 new-bar gate.
   if(CopyRates(_Symbol, strategy_timeframe, 1, 12, rates) != 12) // perf-allowed
      return false;

   const datetime last_open_utc = QM_BrokerToUTC(rates[11].time);
   const datetime box_end_utc = last_open_utc + 15 * 60;
   MqlDateTime end_parts;
   if(last_open_utc <= 0 || !TimeToStruct(box_end_utc, end_parts) ||
      end_parts.hour != strategy_box_end_hour_utc ||
      end_parts.min != 0 || end_parts.sec != 0)
      return false;

   date_key = Strategy_DateKey(box_end_utc);
   const datetime day_start = Strategy_DateStartUtc(date_key);
   if(day_start <= 0 ||
      strategy_box_end_hour_utc - strategy_box_start_hour_utc != 3)
      return false;
   const datetime expected_first =
      day_start + strategy_box_start_hour_utc * 3600;

   box_high = -DBL_MAX;
   box_low = DBL_MAX;
   for(int i = 0; i < 12; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc != expected_first + i * 15 * 60 ||
         rates[i].open <= 0.0 || rates[i].high <= 0.0 ||
         rates[i].low <= 0.0 || rates[i].close <= 0.0 ||
         rates[i].tick_volume <= 0 ||
         rates[i].high < rates[i].low ||
         rates[i].high + 1.0e-12 < MathMax(rates[i].open, rates[i].close) ||
         rates[i].low - 1.0e-12 > MathMin(rates[i].open, rates[i].close))
         return false;
      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
     }

   box_size = box_high - box_low;
   return (box_high > 0.0 && box_low > 0.0 && box_size > 0.0 &&
           box_size <= strategy_max_box_pips * strategy_pip_size + 1.0e-12);
  }

bool Strategy_CurrentNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_PlaceOcoPair(const int date_key,
                           const double box_high,
                           const double box_low,
                           const double box_size)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tick_size <= 0.0 || point <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      Strategy_LogEntryReject(date_key,
                              "invalid_market_metadata_or_quote",
                              StringFormat(",\"tick_size\":%.8f,\"point\":%.8f,\"bid\":%.8f,\"ask\":%.8f",
                                           tick_size, point, bid, ask));
      return false;
     }

   const double buy_entry =
      Strategy_RoundPriceUp(box_high +
                            strategy_extension_fraction * box_size +
                            tick_size,
                            tick_size);
   const double sell_entry =
      Strategy_RoundPriceDown(box_low -
                              strategy_extension_fraction * box_size -
                              tick_size,
                              tick_size);
   const double buy_stop = QM_TM_NormalizePrice(_Symbol, box_low);
   const double sell_stop = QM_TM_NormalizePrice(_Symbol, box_high);
   const double buy_target =
      Strategy_RoundPriceUp(buy_entry + box_size, tick_size);
   const double sell_target =
      Strategy_RoundPriceDown(sell_entry - box_size, tick_size);
   if(buy_entry <= ask || sell_entry >= bid ||
      buy_stop <= 0.0 || sell_stop <= 0.0 ||
      buy_stop >= buy_entry || buy_target <= buy_entry ||
      sell_stop <= sell_entry || sell_target >= sell_entry)
     {
      Strategy_LogEntryReject(date_key,
                              "pending_geometry_invalid",
                              StringFormat(",\"buy_entry\":%.8f,\"sell_entry\":%.8f,\"buy_stop\":%.8f,\"sell_stop\":%.8f,\"buy_target\":%.8f,\"sell_target\":%.8f,\"bid\":%.8f,\"ask\":%.8f",
                                           buy_entry,
                                           sell_entry,
                                           buy_stop,
                                           sell_stop,
                                           buy_target,
                                           sell_target,
                                           bid,
                                           ask));
      return false;
     }

   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double market_clearance =
      (double)MathMax(stop_level, freeze_level) * point;
   if(buy_entry - ask + 1.0e-12 < market_clearance ||
      bid - sell_entry + 1.0e-12 < market_clearance)
     {
      Strategy_LogEntryReject(date_key,
                              "pending_market_clearance",
                              StringFormat(",\"buy_clearance\":%.8f,\"sell_clearance\":%.8f,\"required\":%.8f",
                                           buy_entry - ask,
                                           bid - sell_entry,
                                           market_clearance));
      return false;
     }

   double buy_lots = 0.0;
   double sell_lots = 0.0;
   string side_reject = "";
   if(!Strategy_PlacementSideAllows(buy_entry,
                                    buy_stop,
                                    buy_target,
                                    ORDER_TYPE_BUY,
                                    buy_lots,
                                    side_reject))
     {
      Strategy_LogEntryReject(date_key,
                              "buy_side_" + side_reject,
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"lots\":%.8f",
                                           buy_entry, buy_stop, buy_target, buy_lots));
      return false;
     }
   side_reject = "";
   if(!Strategy_PlacementSideAllows(sell_entry,
                                    sell_stop,
                                    sell_target,
                                    ORDER_TYPE_SELL,
                                    sell_lots,
                                    side_reject))
     {
      Strategy_LogEntryReject(date_key,
                              "sell_side_" + side_reject,
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"lots\":%.8f",
                                           sell_entry, sell_stop, sell_target, sell_lots));
      return false;
     }

   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume_step <= 0.0 ||
      MathAbs(buy_lots - sell_lots) > volume_step * 0.5 + 1.0e-8)
     {
      Strategy_LogEntryReject(date_key,
                              "oco_requested_volume_mismatch",
                              StringFormat(",\"buy_lots\":%.8f,\"sell_lots\":%.8f,\"volume_step\":%.8f",
                                           buy_lots, sell_lots, volume_step));
      return false;
     }

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime expiry_utc =
      Strategy_LondonHourToUtc(date_key,
                               strategy_pending_expiry_hour_london);
   const int expiration_seconds = (int)(expiry_utc - now_utc);
   if(now_utc <= 0 || expiry_utc <= now_utc || expiration_seconds <= 0)
     {
      Strategy_LogEntryReject(date_key,
                              "invalid_london_expiry",
                              StringFormat(",\"now_utc\":%I64d,\"expiry_utc\":%I64d,\"expiration_seconds\":%d",
                                           (long)now_utc,
                                           (long)expiry_utc,
                                           expiration_seconds));
      return false;
     }

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_stop;
   buy_req.tp = buy_target;
   buy_req.reason = "LONDON_BOX_027_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiration_seconds;

   QM_EntryRequest sell_req;
   ZeroMemory(sell_req);
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = sell_stop;
   sell_req.tp = sell_target;
   sell_req.reason = "LONDON_BOX_027_SELL_STOP";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = expiration_seconds;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req,
                           buy_ticket,
                           0,
                           QM_RISK_MODE_FIXED,
                           RISK_FIXED))
     {
      Strategy_LogEntryReject(date_key,
                              "buy_pending_rejected",
                              StringFormat(",\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"lots\":%.8f",
                                           buy_entry, buy_stop, buy_target, buy_lots));
      return false;
     }
   if(!QM_TM_OpenPosition(sell_req,
                          sell_ticket,
                          0,
                          QM_RISK_MODE_FIXED,
                          RISK_FIXED))
     {
      QM_TM_RemovePendingOrder(buy_ticket, "oco_second_leg_rejected");
      Strategy_LogEntryReject(date_key,
                              "sell_pending_rejected",
                              StringFormat(",\"buy_ticket\":%I64u,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"lots\":%.8f",
                                           buy_ticket,
                                           sell_entry,
                                           sell_stop,
                                           sell_target,
                                           sell_lots));
      return false;
     }

   double actual_buy_volume = 0.0;
   double actual_sell_volume = 0.0;
   string actual_buy_reject = "";
   string actual_sell_reject = "";
   if(!Strategy_OrderVolume(buy_ticket, actual_buy_volume) ||
      !Strategy_OrderVolume(sell_ticket, actual_sell_volume) ||
      MathAbs(actual_buy_volume - actual_sell_volume) >
          volume_step * 0.5 + 1.0e-8 ||
      MathAbs(actual_buy_volume - buy_lots) >
         volume_step * 0.5 + 1.0e-8 ||
      MathAbs(actual_sell_volume - sell_lots) >
         volume_step * 0.5 + 1.0e-8 ||
      !Strategy_VolumeAllows(actual_buy_volume, actual_buy_reject) ||
      !Strategy_VolumeAllows(actual_sell_volume, actual_sell_reject))
     {
      QM_TM_RemovePendingOrder(buy_ticket, "oco_volume_mismatch");
      QM_TM_RemovePendingOrder(sell_ticket, "oco_volume_mismatch");
      Strategy_LogEntryReject(date_key,
                              "oco_actual_volume_mismatch",
                              StringFormat(",\"buy_ticket\":%I64u,\"sell_ticket\":%I64u,\"buy_expected\":%.8f,\"sell_expected\":%.8f,\"buy_actual\":%.8f,\"sell_actual\":%.8f,\"buy_detail\":\"%s\",\"sell_detail\":\"%s\"",
                                           buy_ticket,
                                           sell_ticket,
                                           buy_lots,
                                           sell_lots,
                                           actual_buy_volume,
                                           actual_sell_volume,
                                           QM_LoggerEscapeJson(actual_buy_reject),
                                           QM_LoggerEscapeJson(actual_sell_reject)));
      return false;
     }

   g_box_date_key = date_key;
   g_box_high = box_high;
   g_box_low = box_low;
   g_box_size = box_size;
   // This EA intentionally returns false from Strategy_EntrySignal because it
   // submits the two pending legs atomically here.  Signal evidence is valid
   // only after both framework entry calls were accepted and their actual
   // broker volumes were verified.
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"OCO\",\"date_key\":%d,\"buy_ticket\":%I64u,\"sell_ticket\":%I64u,\"buy_entry\":%.8f,\"sell_entry\":%.8f,\"buy_sl\":%.8f,\"sell_sl\":%.8f,\"buy_tp\":%.8f,\"sell_tp\":%.8f,\"lots\":%.8f,\"expiry_utc\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            date_key,
                            buy_ticket,
                            sell_ticket,
                            buy_entry,
                            sell_entry,
                            buy_stop,
                            sell_stop,
                            buy_target,
                            sell_target,
                            actual_buy_volume,
                            (long)expiry_utc));
   return true;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter: configuration, route, and tester risk contract.
bool Strategy_NoTradeFilter()
  {
   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket) ||
      Strategy_OurPendingCount() > 0)
      return false;

   return (!Strategy_IsRoutedSymbol(_Symbol) ||
           !QM_LondonPublicHolidayCalendarReady() ||
           _Period != strategy_timeframe ||
           strategy_variant_id != "LONDON_BOX_027_BASELINE" ||
           strategy_timeframe != PERIOD_M15 ||
           strategy_box_start_hour_utc != 3 ||
           strategy_box_end_hour_utc != 6 ||
           strategy_extension_fraction != 0.27 ||
           strategy_max_box_pips != 40.0 ||
           strategy_pip_size != 0.0001 ||
           strategy_pending_expiry_hour_london != 12 ||
           strategy_flat_hour_london != 16 ||
           Strategy_WideSpread() ||
           RISK_FIXED != 1000.0 ||
           RISK_PERCENT != 0.0);
  }

// Trade Entry: freeze the twelve complete 03:00-06:00 UTC M15 bars and place
// both stop legs as one fail-closed OCO attempt. The hook opens both framework
// requests itself so a rejected second leg can cancel the first atomically.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket) ||
      Strategy_OurPendingCount() > 0)
      return false;

   int date_key = 0;
   double box_high = 0.0;
   double box_low = 0.0;
   double box_size = 0.0;
   if(!Strategy_BuildBox(date_key, box_high, box_low, box_size) ||
      date_key <= 0 || !Strategy_IsUtcWeekday(date_key) ||
      Strategy_DateAlreadyUsed(date_key))
      return false;

   // A symbol-date is consumed by its one 06:00 attempt, including every
   // fail-closed outcome. Later bars cannot chase or retry.
   g_consumed_date_key = date_key;
   const QM_LondonPublicDayType london_day_type =
      QM_LondonPublicHolidayClassify(date_key);
   if(london_day_type != QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY)
     {
      const bool jurisdictional_holiday =
         (london_day_type ==
          QM_LONDON_PUBLIC_DAY_PUBLIC_OR_BANK_HOLIDAY);
      const string calendar_detail = jurisdictional_holiday
         ? "BROKER_SESSION_CALENDAR_UNRESOLVED_ON_LONDON_HOLIDAY"
         : (london_day_type == QM_LONDON_PUBLIC_DAY_OUT_OF_COVERAGE)
           ? "LONDON_TRADING_DAY_CALENDAR_OUT_OF_COVERAGE"
           : "LONDON_TRADING_DAY_CALENDAR_INVALID";
      Strategy_LogEntryReject(
         date_key,
         calendar_detail,
         StringFormat(",\"london_day_type\":\"%s\",\"jurisdictional_holiday_only\":%s,\"fx_closure_inferred\":false,\"lse_calendar_used\":false,\"broker_session_calendar_ready\":false,\"box_bars_complete\":true",
                      QM_LoggerEscapeJson(
                         QM_LondonPublicDayTypeName(london_day_type)),
                      jurisdictional_holiday ? "true" : "false"));
      return false;
     }
   Strategy_PlaceOcoPair(date_key, box_high, box_low, box_size);
   return false;
  }

// Trade Management: cancel the opposite OCO leg after first fill; cancel both
// pending legs on governed news or London-noon expiry; preserve immutable SL;
// and correct the provisional target to exactly one box from actual fill.
void Strategy_ManageOpenPosition()
  {
   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket))
     {
      Strategy_CancelOurPending("oco_first_fill");
      if(g_fill_checked_ticket == position_ticket ||
         !PositionSelectByTicket(position_ticket))
         return;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double current_target = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double tick_size =
         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      double box_size = g_box_size;
      if(box_size <= 0.0 && current_target > 0.0 && open_price > 0.0)
         box_size = MathAbs(current_target - open_price);
      if(box_size <= 0.0 || tick_size <= 0.0)
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double target_price =
         is_buy
         ? Strategy_RoundPriceUp(open_price + box_size, tick_size)
         : Strategy_RoundPriceDown(open_price - box_size, tick_size);
      string geometry_reject = "";
      string volume_reject = "";
      if(open_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0 ||
         (is_buy && (open_price <= stop_price || target_price <= open_price)) ||
         (!is_buy && (open_price >= stop_price || target_price >= open_price)) ||
         !Strategy_TradeGeometryAllows(open_price,
                                       stop_price,
                                       target_price,
                                       geometry_reject) ||
         !Strategy_VolumeAllows(volume, volume_reject))
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }

      if(MathAbs(current_target - target_price) > tick_size * 0.5 &&
         !QM_TM_MoveTP(position_ticket,
                       target_price,
                       "one_box_from_actual_fill"))
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }
      g_fill_checked_ticket = position_ticket;
      return;
     }

   if(Strategy_OurPendingCount() <= 0)
      return;
   int setup_date_key = Strategy_PendingSetupDateKey();
   if(setup_date_key <= 0)
      setup_date_key = g_box_date_key;
   const datetime now_broker = TimeCurrent();
   const datetime now_utc = QM_BrokerToUTC(now_broker);
   const datetime expiry_utc =
      Strategy_LondonHourToUtc(setup_date_key,
                               strategy_pending_expiry_hour_london);
   if(now_utc <= 0 || expiry_utc <= 0 || now_utc >= expiry_utc)
     {
      Strategy_CancelOurPending("london_noon_expiry");
      g_consumed_date_key = setup_date_key;
      return;
     }

   if(!Strategy_CurrentNewsAllows(now_broker))
     {
      Strategy_CancelOurPending("news_pause_consumes_date");
      g_consumed_date_key = setup_date_key;
     }
  }

// Trade Close: first tradable quote at or after 16:00 Europe/London.
bool Strategy_ExitSignal()
  {
   ulong position_ticket = 0;
   if(!Strategy_FindOurPosition(position_ticket) ||
      !PositionSelectByTicket(position_ticket))
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc =
      QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME));
   const datetime now_london = Strategy_LondonLocal(now_utc);
   const datetime open_london = Strategy_LondonLocal(open_utc);
   if(now_london <= 0 || open_london <= 0)
      return false;

   const int now_date = Strategy_DateKey(now_london);
   const int open_date = Strategy_DateKey(open_london);
   if(now_date > open_date)
      return true;
   if(now_date < open_date)
      return false;

   MqlDateTime parts;
   if(!TimeToStruct(now_london, parts))
      return false;
   return (parts.hour >= strategy_flat_hour_london);
  }

// News Filter Hook: the central framework gate handles new entries. Pending
// OCO cancellation is performed in Strategy_ManageOpenPosition so management
// remains active during the blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

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

   const bool calendar_ready = QM_LondonPublicHolidayCalendarLoad();
   QM_LogEvent(calendar_ready ? QM_INFO : QM_ERROR,
               "LONDON_PUBLIC_HOLIDAY_CALENDAR_STATE",
               StringFormat("{\"required\":true,\"ready\":%s,\"file\":\"%s\",\"coverage_start\":%d,\"coverage_end\":%d,\"manifest_sha256\":\"%s\",\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"error\":\"%s\",\"fixed_utc_box_unchanged\":true,\"jurisdictional_context_only\":true,\"fx_closure_inferred\":false,\"lse_calendar_used\":false,\"broker_session_calendar_ready\":false}",
                            calendar_ready ? "true" : "false",
                            QM_LONDON_PUBLIC_HOLIDAY_FILE,
                            QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_START,
                            QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_END,
                            QM_LondonCalendarManifestActualSha256(),
                            QM_LONDON_PUBLIC_HOLIDAY_SHA256,
                            QM_LondonPublicHolidayCalendarActualSha256(),
                            QM_LoggerEscapeJson(
                               QM_LondonPublicHolidayCalendarLastError())));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"card\":\"QM5_20045\",\"routed\":%s,\"period\":%d,\"strategy_tf\":%d,\"variant\":\"%s\",\"holiday_calendar_ready\":%s,\"broker_session_calendar_ready\":false}",
                            Strategy_IsRoutedSymbol(_Symbol) ? "true" : "false",
                            (int)_Period,
                            (int)strategy_timeframe,
                            QM_LoggerEscapeJson(strategy_variant_id),
                            calendar_ready ? "true" : "false"));
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
