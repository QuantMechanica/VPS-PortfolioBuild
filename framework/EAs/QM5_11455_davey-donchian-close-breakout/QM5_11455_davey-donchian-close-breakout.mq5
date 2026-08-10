#property strict
#property version   "5.0"
#property description "QM5_11455 Davey — Donchian Close Breakout (D1)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11455;
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
input int    strategy_length                 = 20;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_atr_tp_mult            = 3.0;
input int    strategy_sl_cap_pips            = 120;
input int    strategy_max_spread_pips        = 25;

// -----------------------------------------------------------------------------
// Card: Kevin Davey, "My 5 Favorite Entries", Entry #4 — Donchian Close
// Breakout. Source: D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11455_davey-donchian-close-breakout.md
//
// Entry LONG: today's close is a new Length-bar closing high
// (Close[1] >= highest close of bars [2..Length+1]). Entry SHORT: today's
// close is a new Length-bar closing low. Enter at open of bar[0]. Fixed
// ATR(14) SL(1.5x, capped) / TP(3.0x trend-following). Opposite-signal
// reversal: an opposing breakout closes the open position so the new
// signal can be taken on the same bar.
// -----------------------------------------------------------------------------

int g_cached_signal_dir = 0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_length <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_sl_cap_pips <= 0)
      return true;

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > bid && max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
         return true;
     }
   return false;
  }

void Strategy_ComputeSignal()
  {
   g_cached_signal_dir = 0;

   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close_1 <= 0.0)
      return;

   double highest_close = 0.0;
   double lowest_close = 0.0;
   bool have_bar = false;
   for(int s = 2; s <= strategy_length + 1; ++s)
     {
      const double c = iClose(_Symbol, PERIOD_CURRENT, s);
      if(c <= 0.0)
         continue;
      if(!have_bar)
        {
         highest_close = c;
         lowest_close = c;
         have_bar = true;
        }
      else
        {
         if(c > highest_close)
            highest_close = c;
         if(c < lowest_close)
            lowest_close = c;
        }
     }
   if(!have_bar)
      return;

   const bool go_long  = (close_1 >= highest_close);
   const bool go_short = (close_1 <= lowest_close);
   if(go_long && go_short)
      return;
   if(go_long)
      g_cached_signal_dir = 1;
   else if(go_short)
      g_cached_signal_dir = -1;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_cached_signal_dir == 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      if(pos_type == POSITION_TYPE_BUY && g_cached_signal_dir < 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      if(pos_type == POSITION_TYPE_SELL && g_cached_signal_dir > 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
     }
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0 || g_cached_signal_dir == 0)
      return false;

   const bool go_long = (g_cached_signal_dir > 0);
   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value) || atr_value <= 0.0)
      return false;

   const double sl_dist_raw = atr_value * strategy_atr_sl_mult;
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double sl_dist = (cap_dist > 0.0) ? MathMin(sl_dist_raw, cap_dist) : sl_dist_raw;
   const double tp_dist = atr_value * strategy_atr_tp_mult;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   const double sl_price = go_long ? (entry - sl_dist) : (entry + sl_dist);
   const double tp_price = go_long ? (entry + tp_dist) : (entry - tp_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = NormalizeDouble(tp_price, _Digits);
   req.reason = go_long ? "DAVEY_DONCHIAN_CLOSE_LONG" : "DAVEY_DONCHIAN_CLOSE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_ExitSignal() { return false; }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   if(QM_IsNewBar())
      Strategy_ComputeSignal();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
