#property strict
#property version   "5.0"
#property description "QM5_9241 Closed H1 engulfing-zone retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9241
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9241;
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

input group "Strategy"
input int strategy_retest_bars = 8;
input double strategy_wick_threshold = 0.35;
input int strategy_atr_period = 14;
input double strategy_min_engulf_atr = 0.5;
input double strategy_stop_buffer_atr = 0.3;
input double strategy_target_r = 2.0;
input int strategy_max_hold_bars = 24;

bool Strategy_ConfigValid()
{
   return (_Period == PERIOD_H1 && strategy_retest_bars >= 1 && strategy_retest_bars <= 64 &&
           strategy_wick_threshold > 0.0 && strategy_wick_threshold <= 1.0 &&
           strategy_atr_period >= 2 && strategy_atr_period <= 256 &&
           strategy_min_engulf_atr > 0.0 && strategy_stop_buffer_atr > 0.0 &&
           strategy_target_r > 0.0 && strategy_max_hold_bars >= 1 && strategy_max_hold_bars <= 240);
}

// Closed-bar pattern. The engulfed PRIOR candle defines the fixed zone.
int Strategy_EngulfDirection(const int shift, MqlRates &engulf, MqlRates &zone)
{
   if(shift < 1 || !QM_ReadBar(_Symbol, PERIOD_H1, shift, engulf) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, shift + 1, zone)) return 2; // unavailable, never a direction
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
   if(atr <= 0.0) return 2;
   if(engulf.high - engulf.low < strategy_min_engulf_atr * atr) return 0;
   if(zone.close < zone.open && engulf.close > engulf.open &&
      engulf.open <= zone.close && engulf.close > zone.high) return 1;
   if(zone.close > zone.open && engulf.close < engulf.open &&
      engulf.open >= zone.close && engulf.close < zone.low) return -1;
   return 0;
}

// Reviewable conventions: a wick beyond the far zone edge invalidates;
// directional rejection wick divided by full candle range measures strength.
bool Strategy_Invalidated(const int direction, const MqlRates &bar, const MqlRates &zone)
{
   return direction > 0 ? bar.low < zone.low : bar.high > zone.high;
}

bool Strategy_Retest(const int direction, const MqlRates &bar, const MqlRates &zone)
{
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.low > zone.high || bar.high < zone.low ||
      Strategy_Invalidated(direction, bar, zone)) return false;
   if(direction > 0)
      return bar.close > bar.open && (MathMin(bar.open, bar.close) - bar.low) / range >= strategy_wick_threshold;
   return bar.close < bar.open && (bar.high - MathMax(bar.open, bar.close)) / range >= strategy_wick_threshold;
}


// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   if(QM_FrameworkMagic() <= 0 || Strategy_NoTradeFilter()) return false;
   MqlRates retest, current_zone;
   // A new engulfing starts a new setup; it cannot retest itself.
   if(Strategy_EngulfDirection(1, retest, current_zone) != 0) return false;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, retest)) return false;
   for(int shift = 2; shift <= strategy_retest_bars + 1; ++shift)
   {
      MqlRates engulf, zone;
      const int direction = Strategy_EngulfDirection(shift, engulf, zone);
      if(direction == 2) return false;
      if(direction == 0) continue;
      // The most recent qualified engulfing supersedes older setups.
      // Reconstruct consumption from closed bars, including after restart.
      for(int between = shift - 1; between >= 2; --between)
      {
         MqlRates bar;
         if(!QM_ReadBar(_Symbol, PERIOD_H1, between, bar) ||
            Strategy_Invalidated(direction, bar, zone) || Strategy_Retest(direction, bar, zone)) return false;
      }
      if(!Strategy_Retest(direction, retest, zone)) return false;
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid) return false;
      const double price = direction > 0 ? ask : bid;
      const double stop = direction > 0 ? zone.low - strategy_stop_buffer_atr * atr
                                        : zone.high + strategy_stop_buffer_atr * atr;
      req.type = direction > 0 ? QM_BUY : QM_SELL;
      req.sl = QM_TM_NormalizePrice(_Symbol, stop);
      const double risk = direction > 0 ? price - req.sl : req.sl - price;
      if(req.sl <= 0.0 || risk <= 0.0) return false;
      req.tp = QM_TM_NormalizePrice(_Symbol, price + direction * strategy_target_r * risk);
      req.reason = direction > 0 ? "engulf_retest_buy" : "engulf_retest_sell";
      return req.tp > 0.0;
   }
   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   MqlRates bar, zone;
   const int opposite = Strategy_EngulfDirection(1, bar, zone);
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_H1, opened, false); // perf-allowed: once per closed H1 bar, position time stop
      const int direction = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      if(bars_held >= strategy_max_hold_bars || opposite == -direction) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_ConfigValid()) return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   // Seed the clock: attaching mid-bar must not produce a late entry.
   QM_IsNewBar(_Symbol, PERIOD_H1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   Strategy_ManageOpenPosition();
   if(!QM_IsNewBar(_Symbol, PERIOD_H1)) return;
   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
      return;
   }
   if(Strategy_NoTradeFilter()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   QM_EntryRequest req;
   ZeroMemory(req);
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
