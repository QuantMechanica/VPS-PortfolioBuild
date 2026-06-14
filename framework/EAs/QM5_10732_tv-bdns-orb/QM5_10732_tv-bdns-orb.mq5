#property strict
#property version   "5.0"
#property description "QM5_10732 TradingView BDNS ORB Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10732;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_or_start_hhmm_ny        = 930;
input int    strategy_or_end_hhmm_ny          = 935;
input int    strategy_trade_end_hhmm_ny       = 1030;
input int    strategy_breakout_offset_ticks   = 24;
input int    strategy_adx_period              = 14;
input double strategy_adx_threshold           = 24.0;
input bool   strategy_vwap_filter_enabled     = true;
input double strategy_sl_or_width_mult        = 0.75;
input double strategy_tp_or_width_mult        = 1.00;
input double strategy_be_or_width_mult        = 0.50;
input bool   strategy_large_range_filter      = false;
input double strategy_large_range_atr_mult    = 2.0;
input int    strategy_max_spread_points       = 0;

int    g_day_key            = 0;
double g_or_high            = 0.0;
double g_or_low             = 0.0;
bool   g_or_has_range       = false;
bool   g_or_ready           = false;
bool   g_skip_day           = false;
bool   g_trade_taken_today  = false;
double g_vwap_pv_sum        = 0.0;
double g_vwap_volume_sum    = 0.0;
double g_vwap               = 0.0;

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (QM_IsUSDSTUTC(utc) ? -4 * 3600 : -5 * 3600);
  }

int Strategy_DayKeyNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNewYork(broker_time), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_HhmmNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNewYork(broker_time), dt);
   return dt.hour * 100 + dt.min;
  }

void Strategy_ResetDay(const int day_key)
  {
   g_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_has_range = false;
   g_or_ready = false;
   g_skip_day = false;
   g_trade_taken_today = false;
   g_vwap_pv_sum = 0.0;
   g_vwap_volume_sum = 0.0;
   g_vwap = 0.0;
  }

double Strategy_TickSize()
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size > 0.0)
      return tick_size;
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

double Strategy_SpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return DBL_MAX;
   return (ask - bid) / point;
  }

bool Strategy_HasOurOpenPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &position_type,
                                 double &open_price,
                                 double &current_sl)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl = PositionGetDouble(POSITION_SL);
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

bool Strategy_HasOurOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double current_sl;
   return Strategy_HasOurOpenPosition(ticket, position_type, open_price, current_sl);
  }

void Strategy_AdvanceStateOnClosedBar(const MqlRates &bar)
  {
   const int day_key = Strategy_DayKeyNY(bar.time);
   if(day_key != g_day_key)
      Strategy_ResetDay(day_key);

   const int hhmm = Strategy_HhmmNY(bar.time);

   if(hhmm >= strategy_or_start_hhmm_ny && hhmm < strategy_trade_end_hhmm_ny)
     {
      const double typical = (bar.high + bar.low + bar.close) / 3.0;
      const double volume = (bar.tick_volume > 0) ? (double)bar.tick_volume : 1.0;
      g_vwap_pv_sum += typical * volume;
      g_vwap_volume_sum += volume;
      if(g_vwap_volume_sum > 0.0)
         g_vwap = g_vwap_pv_sum / g_vwap_volume_sum;
     }

   if(hhmm >= strategy_or_start_hhmm_ny && hhmm < strategy_or_end_hhmm_ny)
     {
      if(!g_or_has_range)
        {
         g_or_high = bar.high;
         g_or_low = bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar.high);
         g_or_low = MathMin(g_or_low, bar.low);
        }
      g_or_ready = false;
      return;
     }

   if(!g_or_ready && hhmm >= strategy_or_end_hhmm_ny && g_or_has_range && g_or_high > g_or_low)
     {
      g_or_ready = true;
      if(strategy_large_range_filter)
        {
         const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_adx_period, 1);
         if(atr > 0.0 && (g_or_high - g_or_low) > strategy_large_range_atr_mult * atr)
            g_skip_day = true;
        }
     }
  }

// No Trade Filter (time, spread, news): central framework handles news;
// this strategy adds the card's NY trading window and optional spread guard.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition())
      return false;

   const int hhmm = Strategy_HhmmNY(TimeCurrent());
   if(hhmm < strategy_or_start_hhmm_ny || hhmm >= strategy_trade_end_hhmm_ny)
      return true;
   if(g_trade_taken_today || g_skip_day)
      return true;
   if(strategy_max_spread_points > 0 && Strategy_SpreadPoints() > strategy_max_spread_points)
      return true;

   return false;
  }

// Trade Entry: 09:30-09:35 NY opening range, 24-tick breakout offset,
// ADX confirmation, optional VWAP bias, one market entry per NY date.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates closed_bar[1];
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, closed_bar) != 1) // perf-allowed: closed-bar-gated ORB/VWAP structural read.
      return false;

   Strategy_AdvanceStateOnClosedBar(closed_bar[0]);

   if(Strategy_HasOurOpenPosition() || g_trade_taken_today || g_skip_day)
      return false;
   if(!g_or_ready || !g_or_has_range || g_or_high <= g_or_low || g_or_low <= 0.0)
      return false;

   const int hhmm = Strategy_HhmmNY(closed_bar[0].time);
   if(hhmm < strategy_or_end_hhmm_ny || hhmm >= strategy_trade_end_hhmm_ny)
      return false;

   const double tick_size = Strategy_TickSize();
   if(tick_size <= 0.0 || strategy_breakout_offset_ticks < 0)
      return false;

   const double adx = QM_ADX(_Symbol, PERIOD_M5, strategy_adx_period, 1);
   if(adx < strategy_adx_threshold)
      return false;

   const double or_width = g_or_high - g_or_low;
   const double long_trigger = g_or_high + strategy_breakout_offset_ticks * tick_size;
   const double short_trigger = g_or_low - strategy_breakout_offset_ticks * tick_size;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(or_width <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(closed_bar[0].close > long_trigger &&
      (!strategy_vwap_filter_enabled || (g_vwap > 0.0 && closed_bar[0].close > g_vwap)))
     {
      const double entry = ask;
      const double raw_sl = entry - strategy_sl_or_width_mult * or_width;
      const double sl = MathMax(raw_sl, g_or_low);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(entry + strategy_tp_or_width_mult * or_width);
      req.reason = "BDNS_ORB_LONG";
      g_trade_taken_today = true;
      return (req.sl > 0.0 && req.tp > entry);
     }

   if(closed_bar[0].close < short_trigger &&
      (!strategy_vwap_filter_enabled || (g_vwap > 0.0 && closed_bar[0].close < g_vwap)))
     {
      const double entry = bid;
      const double raw_sl = entry + strategy_sl_or_width_mult * or_width;
      const double sl = MathMin(raw_sl, g_or_high);
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(entry - strategy_tp_or_width_mult * or_width);
      req.reason = "BDNS_ORB_SHORT";
      g_trade_taken_today = true;
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Trade Management: move SL to breakeven after price reaches TP1 distance
// (0.5 opening-range width). No partial exits in the P2 baseline.
void Strategy_ManageOpenPosition()
  {
   if(!g_or_ready || g_or_high <= g_or_low)
      return;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double current_sl;
   if(!Strategy_HasOurOpenPosition(ticket, position_type, open_price, current_sl))
      return;

   const double or_width = g_or_high - g_or_low;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(or_width <= 0.0 || point <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(moved < strategy_be_or_width_mult * or_width)
      return;

   const double be_sl = Strategy_NormalizePrice(open_price);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (be_sl > current_sl + point * 0.5)
                                 : (be_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, be_sl, "BDNS_ORB_TP1_BREAKEVEN");
  }

// Trade Close: card time exit at 10:30 NY or session close if still open.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;
   return (Strategy_HhmmNY(TimeCurrent()) >= strategy_trade_end_hhmm_ny);
  }

// News Filter Hook: callable for P8; central framework news filter remains authoritative.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10732\",\"ea\":\"tv-bdns-orb\"}");
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
