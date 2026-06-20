#property strict
#property version   "5.0"
#property description "QM5_11721 Carter Strategy 7 London box breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11721 — Thomas Carter M5 Strategy #7: broker-time box breakout
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\
//       QM5_11721_tc-m5-s7-london-box-breakout.md
//
// Literal card mapping:
//   - At 15:00 DWX broker time, build the prior-hour box from M5 bars whose
//     broker open time is 14:00-14:55.
//   - During 15:00-15:55 broker time, enter at the next M5 bar open when the
//     just-closed M5 close breaks beyond the box by 20% of box height.
//   - Long SL = box low; short SL = box high.
//   - Long TP = box high + 4.0 * box height; short TP = box low - 4.0 * height.
//   - Trail open positions by one box height from the favorable tick extreme.
//
// perf-allowed: this strategy needs a small structural OHLC scan over one M5
// hour. It runs only inside Strategy_EntrySignal, which the framework calls
// after the single QM_IsNewBar() gate. No timestamp gate is reimplemented here.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11721;
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
input int    strategy_box_hour_broker       = 14;
input int    strategy_entry_hour_broker     = 15;
input int    strategy_expiry_hour_broker    = 16;
input int    strategy_box_bars              = 12;
input double strategy_breakout_fraction     = 0.20;
input double strategy_take_profit_box_mult  = 4.0;
input double strategy_max_spread_pips       = 15.0;

datetime g_box_day_broker = 0;
bool     g_box_ready = false;
bool     g_session_signal_consumed = false;
double   g_box_high = 0.0;
double   g_box_low = 0.0;
double   g_box_height = 0.0;
double   g_trail_high = 0.0;
double   g_trail_low = 0.0;

datetime BrokerMidnight(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int BrokerHour(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

bool BuildPriorHourBox(const datetime session_day)
  {
   double hi = 0.0;
   double lo = 0.0;
   bool have = false;

   const int scan_limit = (strategy_box_bars > 0 ? strategy_box_bars : 12) + 18;
   for(int shift = 1; shift <= scan_limit; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M5, shift); // perf-allowed structural read
      if(bar_time <= 0)
         break;
      if(BrokerMidnight(bar_time) != session_day)
        {
         if(bar_time < session_day)
            break;
         continue;
        }

      const int hour = BrokerHour(bar_time);
      if(hour < strategy_box_hour_broker)
         break;
      if(hour != strategy_box_hour_broker)
         continue;

      const double bh = iHigh(_Symbol, PERIOD_M5, shift); // perf-allowed structural read
      const double bl = iLow(_Symbol, PERIOD_M5, shift);  // perf-allowed structural read
      if(bh <= 0.0 || bl <= 0.0)
         continue;

      if(!have)
        {
         hi = bh;
         lo = bl;
         have = true;
        }
      else
        {
         if(bh > hi) hi = bh;
         if(bl < lo) lo = bl;
        }
     }

   g_box_high = hi;
   g_box_low = lo;
   g_box_height = have ? (hi - lo) : 0.0;
   g_box_ready = (have && g_box_height > 0.0);
   return g_box_ready;
  }

void ResetSessionIfNeeded(const datetime bar_time)
  {
   const datetime day = BrokerMidnight(bar_time);
   if(day == g_box_day_broker)
      return;

   g_box_day_broker = day;
   g_box_ready = false;
   g_session_signal_consumed = false;
   g_box_high = 0.0;
   g_box_low = 0.0;
   g_box_height = 0.0;
   g_trail_high = 0.0;
   g_trail_low = 0.0;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_max_spread_pips));
      if(cap > 0.0 && (ask - bid) > cap)
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

   const datetime closed_bar_time = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed structural read
   if(closed_bar_time <= 0)
      return false;

   ResetSessionIfNeeded(closed_bar_time);

   const int closed_hour = BrokerHour(closed_bar_time);
   if(closed_hour < strategy_entry_hour_broker || closed_hour >= strategy_expiry_hour_broker)
      return false;
   if(g_session_signal_consumed)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_box_ready && !BuildPriorHourBox(g_box_day_broker))
      return false;

   const double close_price = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed structural read
   if(close_price <= 0.0)
      return false;

   const double long_trigger = g_box_high + strategy_breakout_fraction * g_box_height;
   const double short_trigger = g_box_low - strategy_breakout_fraction * g_box_height;

   if(close_price > long_trigger)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_low);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_box_high + strategy_take_profit_box_mult * g_box_height);
      req.reason = "QM5_11721_LONG_BOX_BREAKOUT";
      g_session_signal_consumed = true;
      g_trail_high = close_price;
      g_trail_low = 0.0;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_price < short_trigger)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_high);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_box_low - strategy_take_profit_box_mult * g_box_height);
      req.reason = "QM5_11721_SHORT_BOX_BREAKOUT";
      g_session_signal_consumed = true;
      g_trail_high = 0.0;
      g_trail_low = close_price;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_box_height <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(g_trail_high <= 0.0 || bid > g_trail_high)
            g_trail_high = bid;
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, g_trail_high - g_box_height);
         if(new_sl > 0.0 && new_sl < bid && (current_sl <= 0.0 || new_sl > current_sl))
            QM_TM_MoveSL(ticket, new_sl, "box_height_trail");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(g_trail_low <= 0.0 || ask < g_trail_low)
            g_trail_low = ask;
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, g_trail_low + g_box_height);
         if(new_sl > ask && (current_sl <= 0.0 || new_sl < current_sl))
            QM_TM_MoveSL(ticket, new_sl, "box_height_trail");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
