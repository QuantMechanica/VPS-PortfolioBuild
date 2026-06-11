#property strict
#property version   "5.0"
#property description "QM5_9636 Brooks Failed Outside Bar H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9636 — Brooks Failed Single Outside Bar H4
// Card: artifacts/cards_approved/QM5_9636_brooks-failed-ob-h4.md
// Source: 6e967762-b26d-59a3-b076-35c17f2e7c36
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9636;
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
input int    strategy_atr_period        = 14;    // ATR lookback period (H4)
input double strategy_ob_range_min      = 1.2;   // OB min range: ATR multiples
input double strategy_ob_range_max      = 3.5;   // OB max range: ATR multiples
input double strategy_ob_close_pct      = 0.65;  // Close location threshold for bull OB
input double strategy_breakout_offset   = 0.05;  // Breakout probe: ATR multiples beyond OB extreme
input double strategy_sl_atr_buffer     = 0.25;  // SL buffer beyond failed-breakout extreme: ATR multiples
input double strategy_tp_r_multiple     = 1.8;   // TP as R multiple from entry
input int    strategy_time_stop_bars    = 12;    // Max H4 bars to hold; close after this

// -----------------------------------------------------------------------------
// File-scope cached bar data — populated once per new H4 bar in EntrySignal.
// Avoids re-running CopyRates on subsequent per-tick calls.
// -----------------------------------------------------------------------------
MqlRates g_rates[];    // perf-allowed: bespoke structural OB scan; populated once per QM_IsNewBar gate
datetime g_rates_bar_time = 0;
bool     g_rates_valid    = false;

const int RATES_NEEDED = 6; // bar[0..5]: bar[1]=potential failed-breakout, bar[2..4]=OB, bar[5]=OB reference

// Refresh the per-bar cache. Called at the start of EntrySignal (which runs only inside QM_IsNewBar gate).
bool RefreshRateCache()
  {
   ArraySetAsSeries(g_rates, true);
   if(CopyRates(_Symbol, PERIOD_H4, 0, RATES_NEEDED, g_rates) < RATES_NEEDED) // perf-allowed: called only from Strategy_EntrySignal inside QM_IsNewBar gate
     {
      g_rates_valid = false;
      return false;
     }
   g_rates_bar_time = g_rates[0].time;
   g_rates_valid = true;
   return true;
  }

// -----------------------------------------------------------------------------
// DetectOBFailureSignal
// Returns QM_SELL for a failed-bull-OB short signal, QM_BUY for a failed-bear-OB
// long signal, or -1 for no signal. Populates out_sl_price on match.
// Runs only inside QM_IsNewBar gate (via EntrySignal).
// -----------------------------------------------------------------------------
int DetectOBFailureSignal(double &out_sl_price)
  {
   out_sl_price = 0.0;
   if(!g_rates_valid || ArraySize(g_rates) < RATES_NEEDED)
      return -1;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return -1;

   // bar[1]: just-closed bar (potential failed-breakout bar)
   const double b1_high  = g_rates[1].high;
   const double b1_low   = g_rates[1].low;
   const double b1_close = g_rates[1].close;

   // Check OB candidates at shifts 2, 3, 4 (i.e. 1, 2, 3 bars before bar[1]).
   // The failed breakout at bar[1] means entry fires at bar[0] open.
   for(int k = 2; k <= 4; k++)
     {
      const double ob_high  = g_rates[k].high;
      const double ob_low   = g_rates[k].low;
      const double ob_close = g_rates[k].close;
      const double ob_range = ob_high - ob_low;

      // Reference bar (bar before the OB)
      const double prev_high = g_rates[k + 1].high;
      const double prev_low  = g_rates[k + 1].low;

      // Outside bar: must engulf the prior bar's range
      if(ob_high <= prev_high) continue;
      if(ob_low  >= prev_low)  continue;

      // Range filter: not too small, not excessively large
      if(ob_range < strategy_ob_range_min * atr) continue;
      if(ob_range > strategy_ob_range_max * atr) continue;

      // Bull OB: close in upper 35% of range (close >= low + 0.65*range)
      const bool bull_ob = (ob_close >= ob_low + strategy_ob_close_pct * ob_range);
      // Bear OB: close in lower 35% of range (close <= low + (1-0.65)*range)
      const bool bear_ob = (ob_close <= ob_low + (1.0 - strategy_ob_close_pct) * ob_range);

      if(bull_ob)
        {
         // Failed bull OB → short entry
         // bar[1] must have probed above OB_High + offset AND closed back below OB_High
         const double break_thresh = ob_high + strategy_breakout_offset * atr;
         if(b1_high > break_thresh && b1_close < ob_high)
           {
            // SL: above the failed breakout high, plus ATR buffer
            out_sl_price = b1_high + strategy_sl_atr_buffer * atr;
            return QM_SELL;
           }
        }

      if(bear_ob)
        {
         // Failed bear OB → long entry
         // bar[1] must have probed below OB_Low - offset AND closed back above OB_Low
         const double break_thresh = ob_low - strategy_breakout_offset * atr;
         if(b1_low < break_thresh && b1_close > ob_low)
           {
            // SL: below the failed breakout low, minus ATR buffer
            out_sl_price = b1_low - strategy_sl_atr_buffer * atr;
            return QM_BUY;
           }
        }
     }

   return -1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No additional filter beyond standard framework news/Friday-close guards.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry signal: detect a failed OB pattern on the just-closed H4 bar.
// Closes any opposite-direction position before opening the new one.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Refresh OHLC cache for this new bar (runs once per QM_IsNewBar gate).
   if(!RefreshRateCache())
      return false;

   double sl_price = 0.0;
   const int sig = DetectOBFailureSignal(sl_price);
   if(sig < 0)
      return false;

   const int magic = QM_FrameworkMagic();

   // Check for an existing position with this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_long  = (ptype == POSITION_TYPE_BUY);
      const bool want_sell = (sig == QM_SELL);
      const bool want_buy  = (sig == QM_BUY);

      if((want_sell && is_long) || (want_buy && !is_long))
        {
         // Opposite-direction: close existing position before reversing.
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      else
        {
         // Same direction already open: skip.
         return false;
        }
     }

   // Build the entry request (market order at bar open).
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.price              = 0.0; // market order: framework resolves to current ASK/BID

   if(sig == QM_SELL)
     {
      // Short: SL above failed breakout high, TP at 1.8R below entry
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price <= 0.0 || sl_price <= entry_price)
         return false;
      const double sl_dist = sl_price - entry_price;
      req.type   = QM_SELL;
      req.sl     = sl_price;
      req.tp     = entry_price - strategy_tp_r_multiple * sl_dist;
      req.reason = "BROOKS_FAILED_BULL_OB_SHORT";
     }
   else
     {
      // Long: SL below failed breakout low, TP at 1.8R above entry
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price <= 0.0 || sl_price >= entry_price)
         return false;
      const double sl_dist = entry_price - sl_price;
      req.type   = QM_BUY;
      req.sl     = sl_price;
      req.tp     = entry_price + strategy_tp_r_multiple * sl_dist;
      req.reason = "BROOKS_FAILED_BEAR_OB_LONG";
     }

   return true;
  }

// No active position management: SL/TP are fixed at entry.
void Strategy_ManageOpenPosition()
  {
   // Card §Exit: no trailing stop or partial close; SL/TP set at entry.
  }

// Time stop: close position after 12 H4 bars (48 hours).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   const long time_stop_secs = (long)strategy_time_stop_bars * 4 * 3600;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(broker_now - open_time >= time_stop_secs)
         return true;
     }
   return false;
  }

// Defer news filtering entirely to the framework 2-axis model.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   ArraySetAsSeries(g_rates, true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9636_brooks-failed-ob-h4\"}");
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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
