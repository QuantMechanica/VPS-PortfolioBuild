#property strict
#property version   "5.0"
#property description "QM5_11402 Davey Dueling Momentum (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11402
// Source: Kevin J. Davey, "My 5 Favorite Entries" (kjtradingsystems.com), Entry #5.
// Card: cards_approved/QM5_11402_davey-dueling-momentum-d1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11402;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_sl_lookback             = 5;
input int    strategy_slx_lookback            = 25;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.5;
input double strategy_atr_tp_mult             = 1.5;
input double strategy_be_trigger_atr_mult     = 1.0;
input double strategy_sl_cap_pips             = 60.0;
input int    strategy_max_spread_pips         = 25;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Always allows management of an
// already-open position (spread cap applies to fresh entries only).
bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic)
            return false;
      }
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
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

   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   if(strategy_sl_lookback < 1 || strategy_slx_lookback < 1)
      return false;

   double close_1   = iClose(_Symbol, _Period, 1); // perf-allowed
   double close_sl   = iClose(_Symbol, _Period, 1 + strategy_sl_lookback);  // perf-allowed
   double close_slx  = iClose(_Symbol, _Period, 1 + strategy_slx_lookback); // perf-allowed
   if(close_1 <= 0.0 || close_sl <= 0.0 || close_slx <= 0.0)
      return false;

   // Short-term momentum up + long-term momentum down = counter-trend LONG (rebound).
   // Short-term momentum down + long-term momentum up = counter-trend SHORT.
   bool long_setup  = (close_1 > close_sl) && (close_1 < close_slx);
   bool short_setup = (close_1 < close_sl) && (close_1 > close_slx);
   if(!long_setup && !short_setup)
      return false;

   QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   double entry_price = QM_EntryMarketPrice(side);
   if(entry_price <= 0.0)
      return false;

   double atr_sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   double capped_sl = QM_StopFixedPips(_Symbol, side, entry_price, (int)MathRound(strategy_sl_cap_pips));
   if(atr_sl <= 0.0 || capped_sl <= 0.0)
      return false;

   // P2 cap: 60 pips max -> whichever SL is tighter (nearer to entry) wins.
   double atr_dist = MathAbs(entry_price - atr_sl);
   double cap_dist = MathAbs(entry_price - capped_sl);
   double sl_price = (atr_dist <= cap_dist) ? atr_sl : capped_sl;

   double tp_price = QM_TakeATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(tp_price <= 0.0)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = long_setup ? "DAVEY_DUELING_MOMENTUM_LONG" : "DAVEY_DUELING_MOMENTUM_SHORT";
   return true;
}

// Move to breakeven once open profit reaches strategy_be_trigger_atr_mult x ATR(14).
void Strategy_ManageOpenPosition()
{
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0)
         continue;

      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double profit_distance = is_buy ? (market_price - open_price) : (open_price - market_price);
      const double be_trigger_distance = atr * strategy_be_trigger_atr_mult;
      if(be_trigger_distance <= 0.0 || profit_distance < be_trigger_distance)
         continue;

      const bool at_be = is_buy ? (sl >= open_price - _Point * 0.5) : (sl <= open_price + _Point * 0.5);
      if(!at_be)
         QM_TM_MoveSL(ticket, open_price, "be_step_1atr");
   }
}

// Card's stated alternative exit: close when short-term momentum flips back to
// re-align with long-term direction (the counter-trend thesis no longer holds).
bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool found = false;
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
      found = true;
      break;
   }
   if(!found)
      return false;

   double close_1  = iClose(_Symbol, _Period, 1); // perf-allowed
   double close_sl = iClose(_Symbol, _Period, 1 + strategy_sl_lookback); // perf-allowed
   if(close_1 <= 0.0 || close_sl <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && close_1 < close_sl)
      return true;
   if(position_type == POSITION_TYPE_SELL && close_1 > close_sl)
      return true;

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
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
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
