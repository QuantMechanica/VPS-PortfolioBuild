#property strict
#property version   "5.0"
#property description "QM5_1012 lien-fader"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1012;
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

enum LienFaderTrailMethod
  {
   LIEN_TRAIL_TWO_BAR_EXTREME = 0,
   LIEN_TRAIL_THREE_BAR_EXTREME = 1,
   LIEN_TRAIL_ATR14X2 = 2,
   LIEN_TRAIL_ATR14X3 = 3,
   LIEN_TRAIL_DONCHIAN5 = 4
  };

input group "Strategy"
input int    adx_period                 = 14;
input double adx_threshold              = 20.0;
input bool   adx_trending_down_required = false;
input int    spike_threshold_pips       = 15;
input int    entry_offset_pips          = 5;
input int    stop_offset_pips           = 20;
input double tp1_rr                     = 1.0;
input LienFaderTrailMethod trail_method = LIEN_TRAIL_TWO_BAR_EXTREME;
input string tf_signal                  = "D1";
input string tf_entry                   = "H1";
input int    max_spread_points          = 0;

string QM_ConfigStrategyName() { return "lien-fader"; }
int    QM_ConfigEaId() { return 1012; }

enum LienFaderState
  {
   LIEN_FADER_WAITING_SPIKE = 0,
   LIEN_FADER_PENDING_LONG = 1,
   LIEN_FADER_PENDING_SHORT = 2,
   LIEN_FADER_SPENT = 3
  };

LienFaderState g_fader_state = LIEN_FADER_WAITING_SPIKE;
datetime       g_setup_day_open = 0;
bool           g_setup_ready = false;
double         g_prev_day_high = 0.0;
double         g_prev_day_low = 0.0;

ENUM_TIMEFRAMES ParseTf(const string value, const ENUM_TIMEFRAMES fallback_tf)
  {
   string v = value;
   StringTrimLeft(v);
   StringTrimRight(v);
   StringToUpper(v);
   if(v == "M30") return PERIOD_M30;
   if(v == "H1")  return PERIOD_H1;
   if(v == "H4")  return PERIOD_H4;
   if(v == "D1")  return PERIOD_D1;
   return fallback_tf;
  }

ENUM_TIMEFRAMES SignalTf()
  {
   return ParseTf(tf_signal, PERIOD_D1);
  }

ENUM_TIMEFRAMES EntryTf()
  {
   return ParseTf(tf_entry, PERIOD_H1);
  }

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool HasManagedPosition()
  {
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
      return true;
     }
   return false;
  }

bool HasManagedOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

void CancelManagedOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void ResetDailyState()
  {
   g_fader_state = LIEN_FADER_WAITING_SPIKE;
   g_setup_ready = false;
   g_prev_day_high = 0.0;
   g_prev_day_low = 0.0;
  }

bool RefreshDailySetup()
  {
   const ENUM_TIMEFRAMES sig_tf = SignalTf();
   const datetime day_open = iTime(_Symbol, sig_tf, 0); // perf-allowed: D1 session boundary for card state reset.
   if(day_open <= 0)
      return false;

   if(day_open == g_setup_day_open)
      return g_setup_ready;

   if(g_setup_day_open > 0)
      CancelManagedOrders("lien_fader_new_day_reset");

   g_setup_day_open = day_open;
   ResetDailyState();

   // perf-allowed: the card's structure is defined by prior-day OHLC extremes.
   g_prev_day_high = iHigh(_Symbol, sig_tf, 1); // perf-allowed: prior-day range defined by card.
   g_prev_day_low = iLow(_Symbol, sig_tf, 1); // perf-allowed: prior-day range defined by card.
   if(g_prev_day_high <= 0.0 || g_prev_day_low <= 0.0 || g_prev_day_high <= g_prev_day_low)
      return false;

   const double adx_now = QM_ADX(_Symbol, sig_tf, adx_period, 1);
   if(adx_now <= 0.0 || adx_now >= adx_threshold)
      return false;

   if(adx_trending_down_required)
     {
      const int compare_shift = 1 + MathMax(adx_period, 1);
      const double adx_then = QM_ADX(_Symbol, sig_tf, adx_period, compare_shift);
      if(adx_then <= 0.0 || adx_now >= adx_then)
         return false;
     }

   g_setup_ready = true;
   return true;
  }

bool BuildPendingRequest(const bool long_side, QM_EntryRequest &req)
  {
   const double entry_dist = PipDistance(entry_offset_pips);
   const double stop_dist = PipDistance(stop_offset_pips);
   if(entry_dist <= 0.0 || stop_dist <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 86400;
   req.tp = 0.0;

   if(long_side)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, g_prev_day_high + entry_dist);
      if(entry <= ask)
         return false;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, entry - stop_dist);
      req.reason = "LIEN_FADER_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   const double entry = QM_TM_NormalizePrice(_Symbol, g_prev_day_low - entry_dist);
   if(entry >= bid)
      return false;
   req.type = QM_SELL_STOP;
   req.price = entry;
   req.sl = QM_TM_NormalizePrice(_Symbol, entry + stop_dist);
   req.reason = "LIEN_FADER_SHORT";
   return (req.sl > req.price);
  }

double ExtremeLow(const ENUM_TIMEFRAMES tf, const int bars)
  {
   double out = 0.0;
   for(int shift = 1; shift <= bars; ++shift)
     {
      // perf-allowed: structural two-bar/DONCHIAN trailing extreme.
      const double value = iLow(_Symbol, tf, shift); // perf-allowed: trailing stop uses closed-bar lows.
      if(value <= 0.0)
         continue;
      if(out <= 0.0 || value < out)
         out = value;
     }
   return out;
  }

double ExtremeHigh(const ENUM_TIMEFRAMES tf, const int bars)
  {
   double out = 0.0;
   for(int shift = 1; shift <= bars; ++shift)
     {
      // perf-allowed: structural two-bar/DONCHIAN trailing extreme.
      const double value = iHigh(_Symbol, tf, shift); // perf-allowed: trailing stop uses closed-bar highs.
      if(value <= 0.0)
         continue;
      if(out <= 0.0 || value > out)
         out = value;
     }
   return out;
  }

bool BreakevenOrBetter(const ENUM_POSITION_TYPE pos_type,
                       const double open_price,
                       const double current_sl)
  {
   if(open_price <= 0.0 || current_sl <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tolerance = (point > 0.0) ? point * 0.5 : 0.0;
   if(pos_type == POSITION_TYPE_BUY)
      return current_sl >= open_price - tolerance;
   return current_sl <= open_price + tolerance;
  }

double TrailStopCandidate(const ENUM_POSITION_TYPE pos_type,
                          const double market_price)
  {
   const ENUM_TIMEFRAMES entry_tf = EntryTf();
   if(trail_method == LIEN_TRAIL_ATR14X2 || trail_method == LIEN_TRAIL_ATR14X3)
     {
      const double atr = QM_ATR(_Symbol, entry_tf, 14, 1);
      const double mult = (trail_method == LIEN_TRAIL_ATR14X2) ? 2.0 : 3.0;
      if(atr <= 0.0 || market_price <= 0.0)
         return 0.0;
      return (pos_type == POSITION_TYPE_BUY)
             ? QM_TM_NormalizePrice(_Symbol, market_price - atr * mult)
             : QM_TM_NormalizePrice(_Symbol, market_price + atr * mult);
     }

   const int bars = (trail_method == LIEN_TRAIL_THREE_BAR_EXTREME) ? 3
                  : (trail_method == LIEN_TRAIL_DONCHIAN5 ? 5 : 2);
   if(pos_type == POSITION_TYPE_BUY)
      return QM_TM_NormalizePrice(_Symbol, ExtremeLow(entry_tf, bars));
   return QM_TM_NormalizePrice(_Symbol, ExtremeHigh(entry_tf, bars));
  }

bool Strategy_NoTradeFilter()
  {
   RefreshDailySetup();
   if(max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!RefreshDailySetup())
      return false;
   if(HasManagedPosition() || HasManagedOrder())
      return false;

   if(g_fader_state == LIEN_FADER_PENDING_LONG || g_fader_state == LIEN_FADER_PENDING_SHORT)
     {
      g_fader_state = LIEN_FADER_SPENT;
      return false;
     }
   if(g_fader_state != LIEN_FADER_WAITING_SPIKE)
      return false;

   const ENUM_TIMEFRAMES entry_tf = EntryTf();
   // perf-allowed: the card's trigger is the last closed H1 bar breaking the prior-day range.
   const double bar_high = iHigh(_Symbol, entry_tf, 1); // perf-allowed: H1 false-breakout trigger.
   const double bar_low = iLow(_Symbol, entry_tf, 1); // perf-allowed: H1 false-breakout trigger.
   if(bar_high <= 0.0 || bar_low <= 0.0)
      return false;

   const double spike_dist = PipDistance(spike_threshold_pips);
   if(spike_dist <= 0.0)
      return false;

   if(bar_low <= g_prev_day_low - spike_dist)
     {
      if(BuildPendingRequest(true, req))
        {
         g_fader_state = LIEN_FADER_PENDING_LONG;
         return true;
        }
      g_fader_state = LIEN_FADER_SPENT;
      return false;
     }

   if(bar_high >= g_prev_day_high + spike_dist)
     {
      if(BuildPendingRequest(false, req))
        {
         g_fader_state = LIEN_FADER_PENDING_SHORT;
         return true;
        }
      g_fader_state = LIEN_FADER_SPENT;
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk_dist = PipDistance((int)MathRound(stop_offset_pips * tp1_rr));
      if(open_price <= 0.0 || market_price <= 0.0 || risk_dist <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(!BreakevenOrBetter(pos_type, open_price, current_sl) && moved >= risk_dist)
        {
         const double half = volume * 0.5;
         if(half > 0.0)
            QM_TM_PartialClose(ticket, half, QM_EXIT_STRATEGY);
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "lien_fader_tp1_breakeven");
         continue;
        }

      if(BreakevenOrBetter(pos_type, open_price, current_sl))
        {
         const double candidate = TrailStopCandidate(pos_type, market_price);
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(candidate <= 0.0 || point <= 0.0)
            continue;
         const bool valid_side = is_buy ? (candidate < market_price) : (candidate > market_price);
         const bool improves = is_buy ? (candidate > current_sl + point * 0.5)
                                      : (candidate < current_sl - point * 0.5);
         if(valid_side && improves)
            QM_TM_MoveSL(ticket, candidate, "lien_fader_trail");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1012\",\"strategy\":\"lien-fader\"}");
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
