#property strict
#property version   "5.0"
#property description "QM5_9269 Gator + Accumulation/Distribution hidden divergence"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_9269_mql5-gator-ad-hidden, G0 APPROVED 2026-05-19.
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 78, Pattern 7.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9269;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_gator_jaw_period       = 13;
input int    strategy_gator_jaw_shift        = 8;
input int    strategy_gator_teeth_period     = 8;
input int    strategy_gator_teeth_shift      = 5;
input int    strategy_gator_lips_period      = 5;
input int    strategy_gator_lips_shift       = 3;
input int    strategy_atr_period             = 14;
input int    strategy_atr_percentile_bars     = 100;
input double strategy_atr_min_percentile      = 0.20;
input double strategy_structure_atr_buffer    = 0.50;
input double strategy_take_profit_rr          = 2.50;
input int    strategy_time_stop_bars          = 24;
input int    strategy_spread_cap_points       = 1000;

#define STRATEGY_MAX_ATR_LOOKBACK 250

double Strategy_GatorUpper(const int shift)
  {
   const double jaw = QM_SMMA(_Symbol, PERIOD_H4, strategy_gator_jaw_period,
                              shift + strategy_gator_jaw_shift, PRICE_MEDIAN);
   const double teeth = QM_SMMA(_Symbol, PERIOD_H4, strategy_gator_teeth_period,
                                shift + strategy_gator_teeth_shift, PRICE_MEDIAN);
   if(jaw <= 0.0 || teeth <= 0.0)
      return 0.0;
   return MathAbs(jaw - teeth);
  }

double Strategy_GatorLowerMagnitude(const int shift)
  {
   const double teeth = QM_SMMA(_Symbol, PERIOD_H4, strategy_gator_teeth_period,
                                shift + strategy_gator_teeth_shift, PRICE_MEDIAN);
   const double lips = QM_SMMA(_Symbol, PERIOD_H4, strategy_gator_lips_period,
                               shift + strategy_gator_lips_shift, PRICE_MEDIAN);
   if(teeth <= 0.0 || lips <= 0.0)
      return 0.0;
   return MathAbs(teeth - lips);
  }

bool Strategy_ReadClosedBars(MqlRates &older, MqlRates &pullback, MqlRates &current)
  {
   MqlRates rates[];
   ArrayResize(rates, 3);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, 3, rates); // perf-allowed: fixed three-bar structural snapshot, called after the framework new-bar gate.
   if(copied != 3)
      return false;

   older = rates[0];
   pullback = rates[1];
   current = rates[2];
   return true;
  }

double Strategy_ADBarFlow(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   const double multiplier = ((bar.close - bar.low) - (bar.high - bar.close)) / range;
   return multiplier * (double)bar.tick_volume;
  }

bool Strategy_ReadADLine(double &ad_current, double &ad_pullback, double &ad_older)
  {
   MqlRates older;
   MqlRates pullback;
   MqlRates current;
   if(!Strategy_ReadClosedBars(older, pullback, current))
      return false;

   // A/D is cumulative, so an arbitrary older baseline cancels in every
   // comparison used by Pattern 7. Accumulating these three closed bars gives
   // exact relative order without an expensive full-history reconstruction.
   ad_older = Strategy_ADBarFlow(older);
   ad_pullback = ad_older + Strategy_ADBarFlow(pullback);
   ad_current = ad_pullback + Strategy_ADBarFlow(current);
   return true;
  }

bool Strategy_ATRAboveFloor(double &current_atr)
  {
   current_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(current_atr <= 0.0 || strategy_atr_percentile_bars < 5 ||
      strategy_atr_percentile_bars > STRATEGY_MAX_ATR_LOOKBACK ||
      strategy_atr_min_percentile < 0.0 || strategy_atr_min_percentile > 1.0)
      return false;

   int valid = 0;
   int below_current = 0;
   for(int shift = 2; shift < 2 + strategy_atr_percentile_bars; ++shift)
     {
      const double historical_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift);
      if(historical_atr <= 0.0)
         continue;
      valid++;
      if(historical_atr < current_atr)
         below_current++;
     }

   if(valid < strategy_atr_percentile_bars * 4 / 5)
      return false;
   const double percentile_rank = (double)below_current / (double)valid;
   return (percentile_rank >= strategy_atr_min_percentile);
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type,
                             datetime &opened_at,
                             string &position_comment)
  {
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;
   position_comment = "";
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      position_comment = PositionGetString(POSITION_COMMENT);
      return true;
     }
   return false;
  }

double Strategy_StructureLevelFromComment(const string comment,
                                          const ENUM_POSITION_TYPE position_type)
  {
   const string prefix = (position_type == POSITION_TYPE_BUY) ? "GAD7L:" : "GAD7S:";
   if(StringFind(comment, prefix) != 0)
      return 0.0;
   return StringToDouble(StringSubstr(comment, StringLen(prefix)));
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   if(strategy_spread_cap_points <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return true;

   // .DWX Model-4 quotes legitimately have ask == bid. Only a genuinely
   // positive spread can trip this guard.
   if(ask > bid && (ask - bid) / point > (double)strategy_spread_cap_points)
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

   if(strategy_gator_jaw_period <= 0 || strategy_gator_jaw_shift < 0 ||
      strategy_gator_teeth_period <= 0 || strategy_gator_teeth_shift < 0 ||
      strategy_gator_lips_period <= 0 || strategy_gator_lips_shift < 0 ||
      strategy_structure_atr_buffer <= 0.0 || strategy_take_profit_rr <= 0.0)
      return false;

   MqlRates older;
   MqlRates pullback;
   MqlRates current;
   if(!Strategy_ReadClosedBars(older, pullback, current))
      return false;

   const double upper_current = Strategy_GatorUpper(1);
   const double upper_pullback = Strategy_GatorUpper(2);
   const double upper_older = Strategy_GatorUpper(3);
   const double lower_current = Strategy_GatorLowerMagnitude(1);
   const double lower_pullback = Strategy_GatorLowerMagnitude(2);
   const double lower_older = Strategy_GatorLowerMagnitude(3);
   if(upper_current <= 0.0 || upper_pullback <= 0.0 || upper_older <= 0.0 ||
      lower_current <= 0.0 || lower_pullback <= 0.0 || lower_older <= 0.0)
      return false;

   const bool prior_dual_red = (upper_pullback < upper_older &&
                                lower_pullback < lower_older);
   const bool current_dual_green = (upper_current > upper_pullback &&
                                    lower_current > lower_pullback);
   if(!prior_dual_red || !current_dual_green)
      return false;

   double ad_current = 0.0;
   double ad_pullback = 0.0;
   double ad_older = 0.0;
   if(!Strategy_ReadADLine(ad_current, ad_pullback, ad_older))
      return false;

   double atr = 0.0;
   if(!Strategy_ATRAboveFloor(atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool long_signal = (older.low > pullback.low &&
                             current.close > pullback.low &&
                             ad_current >= MathMax(ad_pullback, ad_older));
   if(long_signal)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(
         _Symbol, pullback.low - strategy_structure_atr_buffer * atr);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_take_profit_rr);
      req.reason = "GAD7L:" + DoubleToString(pullback.low, _Digits);
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   const bool short_signal = (older.high < pullback.high &&
                              current.close < pullback.high &&
                              ad_current <= MathMin(ad_pullback, ad_older));
   if(short_signal)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(
         _Symbol, pullback.high + strategy_structure_atr_buffer * atr);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_take_profit_rr);
      req.reason = "GAD7S:" + DoubleToString(pullback.high, _Digits);
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   string position_comment;
   if(!Strategy_GetOurPosition(position_type, opened_at, position_comment))
      return false;

   if(strategy_time_stop_bars > 0 && opened_at > 0)
     {
      const int period_seconds = PeriodSeconds(PERIOD_H4);
      if(period_seconds > 0 &&
         (TimeCurrent() - opened_at) >= (long)strategy_time_stop_bars * period_seconds)
         return true;
     }

   MqlRates older;
   MqlRates pullback;
   MqlRates current;
   if(!Strategy_ReadClosedBars(older, pullback, current))
      return false;

   const double upper_current = Strategy_GatorUpper(1);
   const double upper_pullback = Strategy_GatorUpper(2);
   const double upper_older = Strategy_GatorUpper(3);
   const double lower_current = Strategy_GatorLowerMagnitude(1);
   const double lower_pullback = Strategy_GatorLowerMagnitude(2);
   const double lower_older = Strategy_GatorLowerMagnitude(3);
   if(upper_current <= 0.0 || upper_pullback <= 0.0 || upper_older <= 0.0 ||
      lower_current <= 0.0 || lower_pullback <= 0.0 || lower_older <= 0.0)
      return false;

   const bool upper_two_red = (upper_current < upper_pullback &&
                               upper_pullback < upper_older);
   const bool lower_two_red = (lower_current < lower_pullback &&
                               lower_pullback < lower_older);
   if(upper_two_red || lower_two_red)
      return true;

   double ad_current = 0.0;
   double ad_pullback = 0.0;
   double ad_older = 0.0;
   if(!Strategy_ReadADLine(ad_current, ad_pullback, ad_older))
      return false;

   const double structure_level =
      Strategy_StructureLevelFromComment(position_comment, position_type);
   if(position_type == POSITION_TYPE_BUY)
     {
      if(ad_current < ad_pullback && ad_pullback < ad_older)
         return true;
      return (structure_level > 0.0 && current.close < structure_level);
     }

   if(ad_current > ad_pullback && ad_pullback > ad_older)
      return true;
   return (structure_level > 0.0 && current.close > structure_level);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Framework wiring copied verbatim from EA_Skeleton.mq5.
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
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
