#property strict
#property version   "5.0"
#property description "QM5_11362 RoboForex One-Two -- BB Zone + 2-Candle Reversal (M15)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11362;
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
input int    strategy_bb_period               = 20;
input double strategy_bb_deviation            = 2.0;
input int    strategy_sl_offset_pips          = 5;
input int    strategy_sl_cap_pips             = 20;
input int    strategy_max_signal_bar_pips     = 15;
input int    strategy_max_spread_pips         = 5;

// -----------------------------------------------------------------------------
// Card: RoboForex, Strategy Collection -- "Strategy One-Two". Source:
// D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11362_robo-one-two-bb-reversal.md
//
// Price sits in the lower (upper) half of BB(20,2) and the two most recent
// closed bars show consecutive declining (rising) closes -- exhausted
// selling (buying). Entry at the next bar's open. SL a fixed pip offset
// from the signal bar's extreme (skip if that bar's range is too wide). TP
// is the BB middle band, tracked live as a dynamic exit rather than a
// static broker TP so it follows the band.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_bb_period <= 0 || strategy_sl_offset_pips <= 0 || strategy_sl_cap_pips <= 0)
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

bool Strategy_HasOpenPosition(int &out_pos_type)
  {
   out_pos_type = -1;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      out_pos_type = (int)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// TP is the live BB middle band rather than a fixed broker TP, so the
// target tracks the band as it moves (card: "P2: BB middle band as
// dynamic TP").
bool Strategy_ExitSignal()
  {
   int pos_type = -1;
   if(!Strategy_HasOpenPosition(pos_type))
      return false;

   const double bb_mid_1 = QM_BB_Middle(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_mid_1 <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
      return (SymbolInfoDouble(_Symbol, SYMBOL_BID) >= bb_mid_1);

   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= bb_mid_1);
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double bb_lower_1 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_1   = QM_BB_Middle(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper_1 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   const double close_3 = iClose(_Symbol, PERIOD_CURRENT, 3);
   const double high_1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double low_1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   if(bb_lower_1 <= 0.0 || bb_mid_1 <= 0.0 || bb_upper_1 <= 0.0 ||
      close_1 <= 0.0 || close_2 <= 0.0 || close_3 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0)
      return false;

   const double signal_bar_range = high_1 - low_1;
   const double max_range_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_signal_bar_pips);
   if(max_range_dist > 0.0 && signal_bar_range > max_range_dist)
      return false;

   const bool in_lower_zone = (close_1 > bb_lower_1) && (close_1 < bb_mid_1);
   const bool in_upper_zone = (close_1 < bb_upper_1) && (close_1 > bb_mid_1);
   const bool two_bear = (close_2 < close_3) && (close_1 < close_2);
   const bool two_bull = (close_2 > close_3) && (close_1 > close_2);

   const bool go_long  = in_lower_zone && two_bear;
   const bool go_short = in_upper_zone && two_bull;
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double offset_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_offset_pips);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(offset_dist <= 0.0)
      return false;

   double sl_price = go_long ? (low_1 - offset_dist) : (high_1 + offset_dist);
   double sl_dist = MathAbs(entry - sl_price);
   if(cap_dist > 0.0 && sl_dist > cap_dist)
      sl_dist = cap_dist;
   if(sl_dist <= 0.0)
      return false;
   sl_price = go_long ? (entry - sl_dist) : (entry + sl_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = 0.0;
   req.reason = go_long ? "ROBO_ONETWO_BB_LONG" : "ROBO_ONETWO_BB_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

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
