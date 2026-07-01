#property strict
#property version   "5.0"
#property description "QM5_12748 EIA Winter Distillate Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12748 - EIA Winter Distillate Pullback (card: EIA-HEATOIL-PB-2026)
// D1 long-only structural WTI sleeve:
//   - active October 1 through March 31 (winter heating-oil season)
//   - entry after short pullback below N-bar low, above slow trend SMA,
//     below short rebound SMA, with minimum close-to-close drop
//   - exits on rebound, trend failure, season end, max hold, or ATR hard stop
// Runtime: MT5 OHLC only; no EIA, weather, inventory, or external feeds.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12748;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_start_month         = 10;    // Winter window start month (Oct)
input int    strategy_start_day           = 1;     // Winter window start day
input int    strategy_end_month           = 3;     // Winter window end month (Mar)
input int    strategy_end_day             = 31;    // Winter window end day
input int    strategy_pullback_lookback   = 5;     // Completed D1 bars for pullback low
input double strategy_min_down_return_pct = 0.75;  // Min prior D1 close-to-close drop %
input int    strategy_trend_period        = 50;    // Slow SMA trend filter period
input int    strategy_rebound_period      = 5;     // Short SMA rebound exit period
input int    strategy_atr_period          = 20;    // ATR hard-stop period
input double strategy_atr_sl_mult         = 2.75;  // ATR hard-stop distance multiplier
input int    strategy_max_hold_days       = 8;     // Calendar-day max hold
input int    strategy_max_spread_points   = 1000;  // Entry spread cap in points

// -----------------------------------------------------------------------------
// Helper: test whether a D1 bar close time is inside the winter window.
// The window wraps the year boundary (Oct-Dec and Jan-Mar).
// -----------------------------------------------------------------------------
bool Strategy_InWinterWindow(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key   = strategy_end_month   * 100 + strategy_end_day;
   const int cur_key   = dt.mon * 100 + dt.day;
   if(start_key <= end_key)
      return (cur_key >= start_key && cur_key <= end_key);
   return (cur_key >= start_key || cur_key <= end_key);
  }

// -----------------------------------------------------------------------------
// Helper: lowest iLow over completed D1 bars at shifts [2, lookback+1].
// Shift 1 = signal bar (excluded per card rule); shift 2+ = prior completed bars.
// perf-allowed: bespoke pullback-low with signal-bar exclusion; no QM_* equivalent.
// Called only inside QM_IsNewBar gate (once per D1 bar), not per tick.
// -----------------------------------------------------------------------------
double Strategy_PullbackLow(const int lookback)
  {
   if(lookback <= 0)
      return 0.0;
   double lowest = DBL_MAX;
   for(int i = 2; i < lookback + 2; ++i)
     {
      const double lo = iLow(_Symbol, PERIOD_D1, i); // perf-allowed: bespoke pullback-low with signal-bar exclusion at shifts 2..N+1; no QM_* equivalent.
      if(lo <= 0.0)
         return 0.0;
      lowest = MathMin(lowest, lo);
     }
   return (lowest < DBL_MAX) ? lowest : 0.0;
  }

// -----------------------------------------------------------------------------
// No-trade filter: host-chart guard and degenerate-parameter guard.
// Runs every tick; O(1).
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_pullback_lookback <= 1 || strategy_trend_period <= 1 || strategy_rebound_period <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Entry signal: evaluate all conditions on the last closed D1 bar.
// Called only inside QM_IsNewBar gate (once per D1 bar).
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = 0.0;
   req.tp               = 0.0;
   req.reason           = "EIA_WINTER_DISTILLATE_PULLBACK_LONG";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per magic — no pyramiding.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return false;
     }

   // Spread guard (DWX tester quotes ask==bid=0 modeled spread; only block real wide spread).
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask > 0 && bid > 0 && ask > bid)
        {
         const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(pt > 0.0 && MathRound((ask - bid) / pt) > strategy_max_spread_points)
            return false;
        }
     }

   // Winter season window: use the prior closed D1 bar's open time.
   const datetime bar1_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: calendar gate; bar open time at fixed shift; no QM_* equivalent.
   if(bar1_time <= 0)
      return false;
   if(!Strategy_InWinterWindow(bar1_time))
      return false;

   // Prior closed D1 close and prior-to-prior close for return calc.
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: signal-bar close at fixed shift; no QM_* equivalent.
   const double close2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: prior-bar close for down-return calc; no QM_* equivalent.
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Trend filter: close must be ABOVE slow SMA (QM_SMA uses pooled handle + CopyBuffer).
   const double trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1);
   if(trend_sma <= 0.0 || close1 <= trend_sma)
      return false;

   // Rebound filter: close must remain BELOW short SMA (not yet rebounded).
   const double rebound_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_rebound_period, 1);
   if(rebound_sma <= 0.0 || close1 >= rebound_sma)
      return false;

   // Pullback low: prior close at or below the N-bar low (excluding signal bar).
   const double pb_low = Strategy_PullbackLow(strategy_pullback_lookback);
   if(pb_low <= 0.0 || close1 > pb_low)
      return false;

   // Minimum close-to-close down return.
   const double down_pct = ((close1 / close2) - 1.0) * 100.0;
   if(down_pct > -strategy_min_down_return_pct)
      return false;

   // ATR-based hard stop (entry at market; req.price=0 means framework fills market price).
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   return true;
  }

// -----------------------------------------------------------------------------
// Trade management: no trailing/partial/BE in v1.
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Intentionally empty — v1 holds until exit conditions fire.
  }

// -----------------------------------------------------------------------------
// Exit signal: check whether any open position meets an exit condition.
// Evaluated every tick but uses only O(1) bar reads and QM_SMA (pooled handle).
// Returning true closes ALL positions for this magic via the OnTick scaffold.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   // Read closed-bar state for deterministic exits (O(1) per-tick reads).
   const datetime bar1_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: calendar exit gate; bar time at fixed shift; no QM_* equivalent.
   if(bar1_time <= 0)
      return false;

   // Exit if prior closed bar is outside the winter window.
   if(!Strategy_InWinterWindow(bar1_time))
      return true;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: trend/rebound exit on closed bar close; no QM_* equivalent.
   if(close1 <= 0.0)
      return false;

   // Exit if trend filter breached (close below slow SMA).
   const double trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1);
   if(trend_sma > 0.0 && close1 < trend_sma)
      return true;

   // Exit if price has rebounded above the short SMA.
   const double rebound_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_rebound_period, 1);
   if(rebound_sma > 0.0 && close1 >= rebound_sma)
      return true;

   // Exit if max calendar hold exceeded.
   const datetime now = TimeCurrent();
   const int hold_secs = strategy_max_hold_days * 86400;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (now - opened) >= hold_secs)
         return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// News filter hook: defer to framework QM_NewsAllowsTrade2.
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do not edit.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12748\",\"ea\":\"eia-distill-pb\"}");
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
