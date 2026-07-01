#property strict
#property version   "5.0"
#property description "QM5_9574 DeMark TD Anti-Differential 3-Bar H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9574 - DeMark TD Anti-Differential 3-Bar Variant
// -----------------------------------------------------------------------------
// Closed H4 reversal pattern:
//   - three monotone closes into an exhaustion bar
//   - reversal close with ATR-normalized anti-differential asymmetry
//   - structure stop beyond the four-bar setup, 1.8R target, 12-bar time stop
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9574;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period              = 14;
input double strategy_asymmetry_mult          = 0.60;
input double strategy_exhaustion_range_atr    = 0.70;
input double strategy_stop_buffer_atr         = 0.30;
input double strategy_rr_target               = 1.80;
input int    strategy_max_hold_bars           = 12;
input double strategy_max_setup_range_atr     = 4.00;
input double strategy_spread_atr_fraction     = 0.20;

enum Strategy_SignalSide
  {
   STRATEGY_SIGNAL_NONE = 0,
   STRATEGY_SIGNAL_LONG = 1,
   STRATEGY_SIGNAL_SHORT = -1
  };

struct Strategy_SetupState
  {
   Strategy_SignalSide side;
   double              setup_low;
   double              setup_high;
   double              atr_value;
  };

string Strategy_ExpectedSymbolForSlot(const int slot)
  {
   switch(slot)
     {
      case 0:  return "EURUSD.DWX";
      case 1:  return "GBPUSD.DWX";
      case 2:  return "USDJPY.DWX";
      case 3:  return "AUDUSD.DWX";
      case 4:  return "USDCAD.DWX";
      case 5:  return "USDCHF.DWX";
      case 6:  return "NZDUSD.DWX";
      case 7:  return "XAUUSD.DWX";
      case 8:  return "XTIUSD.DWX";
      case 9:  return "GDAXI.DWX";
      case 10: return "NDX.DWX";
      case 11: return "WS30.DWX";
      case 12: return "UK100.DWX";
     }
   return "";
  }

bool Strategy_SymbolSlotMatches()
  {
   const string expected = Strategy_ExpectedSymbolForSlot(qm_magic_slot_offset);
   return (StringLen(expected) > 0 && _Symbol == expected);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry(const double atr_value)
  {
   if(strategy_spread_atr_fraction <= 0.0 || atr_value <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask < bid)
      return true;
   if(ask == bid)
      return true;

   return ((ask - bid) <= atr_value * strategy_spread_atr_fraction);
  }

double Strategy_Max4(const double a, const double b, const double c, const double d)
  {
   return MathMax(MathMax(a, b), MathMax(c, d));
  }

double Strategy_Min4(const double a, const double b, const double c, const double d)
  {
   return MathMin(MathMin(a, b), MathMin(c, d));
  }

bool Strategy_LoadSetup(Strategy_SetupState &state)
  {
   state.side = STRATEGY_SIGNAL_NONE;
   state.setup_low = 0.0;
   state.setup_high = 0.0;
   state.atr_value = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, 4, rates); // perf-allowed: bounded four-bar H4 pattern read on closed-bar path.
   if(copied != 4)
      return false;

   const double atr_t = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_t2 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 3);
   if(atr_t <= 0.0 || atr_t2 <= 0.0)
      return false;

   const double setup_high = Strategy_Max4(rates[0].high, rates[1].high, rates[2].high, rates[3].high);
   const double setup_low = Strategy_Min4(rates[0].low, rates[1].low, rates[2].low, rates[3].low);
   if(setup_high <= setup_low)
      return false;
   if((setup_high - setup_low) > atr_t * strategy_max_setup_range_atr)
      return false;

   const bool three_down = (rates[3].close > rates[2].close && rates[2].close > rates[1].close);
   const bool long_reversal = (rates[0].close > rates[1].close);
   const bool long_asymmetry =
      ((rates[0].close - rates[1].close) >= strategy_asymmetry_mult * (rates[2].close - rates[1].close));
   const bool long_exhaustion =
      (rates[1].low < rates[2].low &&
       (rates[1].high - rates[1].low) >= strategy_exhaustion_range_atr * atr_t2);

   const bool three_up = (rates[3].close < rates[2].close && rates[2].close < rates[1].close);
   const bool short_reversal = (rates[0].close < rates[1].close);
   const bool short_asymmetry =
      ((rates[1].close - rates[0].close) >= strategy_asymmetry_mult * (rates[1].close - rates[2].close));
   const bool short_exhaustion =
      (rates[1].high > rates[2].high &&
       (rates[1].high - rates[1].low) >= strategy_exhaustion_range_atr * atr_t2);

   if(three_down && long_reversal && long_asymmetry && long_exhaustion)
      state.side = STRATEGY_SIGNAL_LONG;
   else if(three_up && short_reversal && short_asymmetry && short_exhaustion)
      state.side = STRATEGY_SIGNAL_SHORT;
   else
      return true;

   state.setup_low = setup_low;
   state.setup_high = setup_high;
   state.atr_value = atr_t;
   return true;
  }

bool Strategy_BuildEntryRequest(const Strategy_SetupState &state, QM_EntryRequest &req)
  {
   if(state.side == STRATEGY_SIGNAL_NONE || state.atr_value <= 0.0)
      return false;

   req.type = (state.side == STRATEGY_SIGNAL_LONG) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (state.side == STRATEGY_SIGNAL_LONG) ? "TD_ANTI_DIFF_3BAR_LONG" : "TD_ANTI_DIFF_3BAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   const double stop_buffer = state.atr_value * strategy_stop_buffer_atr;
   if(req.type == QM_BUY)
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.setup_low - stop_buffer);
   else
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.setup_high + stop_buffer);

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, strategy_rr_target);
   return (req.tp > 0.0);
  }

bool Strategy_CloseOppositeSignal(const Strategy_SetupState &state)
  {
   if(state.side == STRATEGY_SIGNAL_NONE)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool closed_any = false;
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
      const bool long_position = (pos_type == POSITION_TYPE_BUY);
      const bool opposite = (long_position && state.side == STRATEGY_SIGNAL_SHORT) ||
                            (!long_position && state.side == STRATEGY_SIGNAL_LONG);
      if(opposite)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         closed_any = true;
        }
     }
   return closed_any;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   if(!Strategy_SymbolSlotMatches())
      return true;
   if(strategy_atr_period <= 0)
      return true;
   if(strategy_asymmetry_mult <= 0.0 || strategy_exhaustion_range_atr <= 0.0)
      return true;
   if(strategy_stop_buffer_atr < 0.0 || strategy_rr_target <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_max_setup_range_atr <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "TD_ANTI_DIFF_3BAR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_SetupState state;
   if(!Strategy_LoadSetup(state))
      return false;

   if(Strategy_CloseOppositeSignal(state))
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(state.side == STRATEGY_SIGNAL_NONE)
      return false;
   if(!Strategy_SpreadAllowsEntry(state.atr_value))
      return false;

   return Strategy_BuildEntryRequest(state, req);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_H4);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9574\",\"ea\":\"demark-td-anti-diff-3bar-h4\"}");
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
