#property strict
#property version   "5.0"
#property description "QM5_10132 TradingView MTF Body Break Of Structure"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10132;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_structure_lookback         = 20;
input int    strategy_atr_period                 = 14;
input int    strategy_htf_sma_period             = 50;
input double strategy_atr_stop_mult              = 1.5;
input double strategy_signal_atr_buffer          = 0.25;
input double strategy_take_profit_rr             = 2.0;
input double strategy_max_spread_stop_fraction   = 0.10;

// No Trade Filter: time, spread, news. Time has no extra card gate; news is
// handled by the framework; spread is checked at entry after stop distance exists.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: body close outside prior body, BOS confirmation, and 4x HTF SMA.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_structure_lookback < 1 ||
      strategy_atr_period < 1 ||
      strategy_htf_sma_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_signal_atr_buffer < 0.0 ||
      strategy_take_profit_rr <= 0.0 ||
      strategy_max_spread_stop_fraction < 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlRates rates[];
   const int bars_needed = strategy_structure_lookback + 1;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, bars_needed, rates); // perf-allowed: bounded closed-bar body/BOS window; EntrySignal is framework-gated.
   if(copied != bars_needed)
      return false;

   const MqlRates signal = rates[0];
   const MqlRates prior = rates[1];
   if(signal.open <= 0.0 || signal.high <= 0.0 || signal.low <= 0.0 || signal.close <= 0.0 ||
      prior.open <= 0.0 || prior.close <= 0.0)
      return false;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 1; i <= strategy_structure_lookback; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         return false;
      prior_high = MathMax(prior_high, rates[i].high);
      prior_low = MathMin(prior_low, rates[i].low);
     }

   ENUM_TIMEFRAMES htf = PERIOD_H1;
   switch(_Period)
     {
      case PERIOD_M1:  htf = PERIOD_M5;  break;
      case PERIOD_M5:  htf = PERIOD_M20; break;
      case PERIOD_M15: htf = PERIOD_H1;  break;
      case PERIOD_M30: htf = PERIOD_H2;  break;
      case PERIOD_H1:  htf = PERIOD_H4;  break;
      case PERIOD_H4:  htf = PERIOD_D1;  break;
      default:         htf = PERIOD_H1;  break;
     }

   MqlRates htf_rates[];
   ArraySetAsSeries(htf_rates, true);
   const int htf_copied = CopyRates(_Symbol, htf, 1, 1, htf_rates); // perf-allowed: single closed HTF candle for fixed MTF filter.
   if(htf_copied != 1)
      return false;

   const double htf_close = htf_rates[0].close;
   const double htf_sma = QM_SMA(_Symbol, htf, strategy_htf_sma_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(htf_sma <= 0.0 || atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double prior_body_high = MathMax(prior.open, prior.close);
   const double prior_body_low = MathMin(prior.open, prior.close);

   QM_OrderType side = QM_BUY;
   double entry = 0.0;
   double sl = 0.0;
   string reason = "";

   if(signal.close > prior_body_high && signal.close > prior_high && htf_close > htf_sma)
     {
      side = QM_BUY;
      entry = ask;
      sl = MathMin(signal.low - strategy_signal_atr_buffer * atr,
                   entry - strategy_atr_stop_mult * atr);
      reason = "BODY_BOS_LONG";
     }
   else if(signal.close < prior_body_low && signal.close < prior_low && htf_close < htf_sma)
     {
      side = QM_SELL;
      entry = bid;
      sl = MathMax(signal.high + strategy_signal_atr_buffer * atr,
                   entry + strategy_atr_stop_mult * atr);
      reason = "BODY_BOS_SHORT";
     }
   else
      return false;

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double stop_points = MathAbs(entry - sl) / point;
   const double spread_points = (ask - bid) / point;
   if(stop_points <= 0.0 || spread_points < 0.0)
      return false;
   if(spread_points > stop_points * strategy_max_spread_stop_fraction)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0 || QM_LotsForRisk(_Symbol, stop_points) <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   return true;
  }

// Trade Management: no card-authorized trailing, break-even, partial close, or add.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: body closes back across the prior body in the opposite direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 2, rates); // perf-allowed: bounded two-bar close rule; framework calls ExitSignal before its new-bar gate.
   if(copied != 2)
      return false;

   const MqlRates signal = rates[0];
   const MqlRates prior = rates[1];
   if(signal.close <= 0.0 || prior.open <= 0.0 || prior.close <= 0.0)
      return false;

   const double prior_body_high = MathMax(prior.open, prior.close);
   const double prior_body_low = MathMin(prior.open, prior.close);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && signal.close < prior_body_low)
         return true;
      if(type == POSITION_TYPE_SELL && signal.close > prior_body_high)
         return true;
     }

   return false;
  }

// News Filter Hook: central V5 news filter handles the card's 30-minute blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
