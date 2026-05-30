#property strict
#property version   "5.0"
#property description "QM5_11911 Larry Williams Smash Day Reversal (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11911
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11911;
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
input int    strategy_atr_period        = 14;
input double strategy_atr_smash_mult    = 0.5;
input int    strategy_order_validity    = 5;
input double strategy_rr_ratio          = 2.0;
input int    strategy_time_stop_bars    = 10;
input double strategy_buffer_pips       = 1.0;

// State to track pending setups since orders might not be placed natively as real pending orders 
// if we use market execution on break, but the framework QM_EntryRequest supports Stop orders?
// In QM V5, if we want a pending order, we use QM_BUY_STOP / QM_SELL_STOP.
// However, the framework entry request handling is typically market or requires us to check entry.
// Wait, QM_OrderType includes QM_BUY, QM_SELL. Does it include QM_BUY_STOP?
// Let's implement execution by triggering a market order when price breaches the level,
// simulating a stop order to ensure compatibility with standard QM_EntryRequest.
// We will track the "valid setup" level.

double g_smash_long_level = 0.0;
double g_smash_long_sl = 0.0;
int    g_smash_long_bars_left = 0;

double g_smash_short_level = 0.0;
double g_smash_short_sl = 0.0;
int    g_smash_short_bars_left = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   // 1. Process new closed bar for setups
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close2 = iClose(_Symbol, PERIOD_D1, 2);
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);
   const double high2  = iHigh(_Symbol, PERIOD_D1, 2);
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);
   const double low2   = iLow(_Symbol, PERIOD_D1, 2);
   const double open1  = iOpen(_Symbol, PERIOD_D1, 1);
   const double atr1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(close1 <= 0.0 || atr1 <= 0.0) return false;

   // Bullish Smash Day Setup
   if(high1 > high2 && low1 > low2 && close1 > close2 && (open1 - close1) > (strategy_atr_smash_mult * atr1))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_smash_long_level = high1 + (strategy_buffer_pips * 10 * point);
      g_smash_long_sl = low1 - (5.0 * 10 * point); // 5 pips below low
      g_smash_long_bars_left = strategy_order_validity;
   }
   
   // Bearish Smash Day Setup
   if(high1 < high2 && low1 < low2 && close1 < close2 && (close1 - open1) > (strategy_atr_smash_mult * atr1))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_smash_short_level = low1 - (strategy_buffer_pips * 10 * point);
      g_smash_short_sl = high1 + (5.0 * 10 * point); // 5 pips above high
      g_smash_short_bars_left = strategy_order_validity;
   }

   // Decrease validity
   if(g_smash_long_bars_left > 0)  g_smash_long_bars_left--;
   if(g_smash_short_bars_left > 0) g_smash_short_bars_left--;

   // In real-time (tick by tick), if we were checking this in OnTick, we would trigger.
   // But Strategy_EntrySignal is only called on a new closed bar in the skeleton.
   // Wait, the skeleton says:
   // "Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of per-tick recompute mistakes"
   // If it's a stop order intraday, checking it only on new bar close means we miss the intraday break!
   // Since the skeleton restricts Strategy_EntrySignal to QM_IsNewBar(), we must enter at the open 
   // of the bar following the break, or we assume the breakout happened if the new bar's close 
   // or high breached the level.
   // To be precise with the skeleton's limitations, we trigger if the previous bar's range breached the stop level.
   // Let's check if the bar that just closed (bar 1) breached our active stop levels.
   
   // Actually, if we just set the setup, we can check if bar 0 (current price) breaches it?
   // The skeleton limits `req` generation to `if(!QM_IsNewBar()) return;`
   // So we can only enter at the Open of the next day. This is a framework constraint for standard implementations.
   // We will enter if the bar that just closed (bar 1) breached the level.
   
   bool trigger_long = false;
   bool trigger_short = false;

   if(g_smash_long_bars_left >= 0 && g_smash_long_level > 0.0)
   {
      if(high1 >= g_smash_long_level)
      {
         trigger_long = true;
         g_smash_long_bars_left = 0; // consumed
      }
   }
   
   if(g_smash_short_bars_left >= 0 && g_smash_short_level > 0.0)
   {
      if(low1 <= g_smash_short_level)
      {
         trigger_short = true;
         g_smash_short_bars_left = 0; // consumed
      }
   }

   if(!trigger_long && !trigger_short) return false;

   QM_OrderType side = trigger_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = (side == QM_BUY) ? g_smash_long_sl : g_smash_short_sl;
   double risk_dist = MathAbs(entry - sl);
   double tp = (side == QM_BUY) ? entry + (risk_dist * strategy_rr_ratio) : entry - (risk_dist * strategy_rr_ratio);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "WILLIAMS_SMASH_LONG" : "WILLIAMS_SMASH_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
   }
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
