#property strict
#property version   "5.0"
#property description "QM5_11388 Russ Horn Golden Strategy SMMA55 Channel + WPR55 + Stoch555"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11388
// Source: Russ Horn, "The Golden Strategy" (RapidResultsMethod.com).
// Card: cards_approved/QM5_11388_russ-horn-golden-smma55-wpr55-stoch555.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11388;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// The approved P2 card explicitly runs without a news filter.  Keep the
// backtest-safe defaults independent of calendar/cache availability; later
// governed phases may opt in through sealed setfiles.
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
input int    strategy_smma_period       = 55;
input int    strategy_wpr_period        = 55;
input double strategy_wpr_overbought    = -25.0;
input double strategy_wpr_oversold      = -75.0;
input int    strategy_stoch_k_period    = 5;
input int    strategy_stoch_d_period    = 5;
input int    strategy_stoch_slowing     = 5;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_sl_cap_pips       = 20.0;
input double strategy_tp_rr             = 2.0;
input int    strategy_max_spread_pips   = 15;

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

   double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed
   double smma_high_1 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_HIGH);
   double smma_low_1  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_LOW);
   double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   double stoch_k_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   double stoch_d_1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(close_1 <= 0.0 || smma_high_1 <= 0.0 || smma_low_1 <= 0.0)
      return false;

   bool long_setup = (close_1 > smma_high_1) &&
                      (wpr_prev <= strategy_wpr_overbought && wpr_now > strategy_wpr_overbought) &&
                      (stoch_k_1 > stoch_d_1);
   bool short_setup = (close_1 < smma_low_1) &&
                       (wpr_prev >= strategy_wpr_oversold && wpr_now < strategy_wpr_oversold) &&
                       (stoch_k_1 < stoch_d_1);
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

   // P2 cap: 20 pips max -> whichever SL is tighter (nearer to entry) wins.
   double atr_dist = MathAbs(entry_price - atr_sl);
   double cap_dist = MathAbs(entry_price - capped_sl);
   double sl_price = (atr_dist <= cap_dist) ? atr_sl : capped_sl;

   double tp_price = QM_TakeRR(_Symbol, side, entry_price, sl_price, strategy_tp_rr);
   if(tp_price <= 0.0)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = long_setup ? "GOLDEN_SMMA_WPR_STOCH_LONG" : "GOLDEN_SMMA_WPR_STOCH_SHORT";
   return true;
}

void Strategy_ManageOpenPosition() {}

// SL/TP are set on the order at entry; no discretionary exit beyond them.
bool Strategy_ExitSignal()
{
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
