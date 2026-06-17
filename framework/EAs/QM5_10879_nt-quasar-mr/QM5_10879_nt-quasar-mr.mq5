#property strict
#property version   "5.0"
#property description "QM5_10879 NexusTrade Quasar RSI-SMA Mean-Reversion Rebalance"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10879 nt-quasar-mr
// -----------------------------------------------------------------------------
// Mean-reversion long-only D1 strategy ported from the NexusTrade "Quasar"
// blog (Austin Starks, 2025-04-14). Buys an index CFD when BOTH the traded
// symbol AND a market-leader proxy (SP500.DWX) are oversold (close < SMA20 and
// RSI(14) < threshold). A 14-calendar-day fill throttle and a one-position
// cap enforce the source's rebalance cadence. Exit on mean reversion
// (close >= SMA20 OR RSI >= exit threshold), a 20-trading-day time stop, or a
// catastrophic ATR stop.
//
// BASKET: this EA reads a foreign proxy symbol, so it registers the universe
// {_Symbol, proxy} via QM_SymbolGuardInit + warms its history. When the proxy
// equals the traded symbol (e.g. SP500 tests) the universe collapses to one
// symbol, which is still valid.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// All other framework wiring is unchanged from the skeleton.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10879;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// All parameters from the card mechanics + "Parameters To Test" section.
input int    strategy_sma_period        = 20;     // close vs SMA(close, N)
input int    strategy_rsi_period        = 14;     // RSI period
input double strategy_rsi_oversold      = 30.0;   // entry: RSI below this
input double strategy_rsi_exit          = 45.0;   // exit: RSI at/above this
input int    strategy_atr_period        = 14;     // ATR period for stop
input double strategy_atr_sl_mult       = 3.0;    // entry_price - mult*ATR
input int    strategy_throttle_days     = 14;     // calendar days since last fill
input int    strategy_time_stop_bars    = 20;     // trading-day time stop
input int    strategy_min_bars          = 60;     // skip if fewer D1 bars available
// Market-leader proxy. SP500.DWX is the source's leader index. Set equal to the
// traded symbol to self-gate (e.g. running ON SP500.DWX). Leave default to use
// SP500.DWX as the cross-symbol leader for NDX/WS30 tests.
input string strategy_proxy_symbol      = "SP500.DWX";

// -----------------------------------------------------------------------------
// File-scope strategy state (advanced only on closed bars / fills).
// -----------------------------------------------------------------------------
string   g_proxy_symbol     = "";    // resolved proxy (defaults to _Symbol if input blank)
datetime g_last_fill_time   = 0;     // broker time of the last entry fill (throttle)

// Resolve the effective proxy symbol once.
string QM_ResolveProxySymbol()
  {
   if(StringLen(strategy_proxy_symbol) == 0)
      return _Symbol;
   return strategy_proxy_symbol;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. No regime/session restriction in this strategy.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Returns TRUE if both the traded symbol and the proxy are oversold on the
// last closed D1 bar. Caller guarantees QM_IsNewBar()==true.
bool QM_BothOversold()
  {
   // Self leg (shift 1 = last closed bar).
   // perf-allowed: single closed-bar close read; no QM helper exposes raw close.
   const double self_close = iClose(_Symbol, PERIOD_D1, 1);
   if(self_close <= 0.0)
      return false;
   const double self_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double self_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(self_sma <= 0.0)
      return false;
   const bool self_oversold = (self_close < self_sma) && (self_rsi < strategy_rsi_oversold);
   if(!self_oversold)
      return false;

   // Proxy leg. If proxy == self, reuse the self values (avoids a redundant read).
   if(g_proxy_symbol == _Symbol)
      return true;

   // perf-allowed: single closed-bar foreign-symbol close (basket leg).
   const double proxy_close = iClose(g_proxy_symbol, PERIOD_D1, 1);
   if(proxy_close <= 0.0)
      return false;
   const double proxy_sma = QM_SMA(g_proxy_symbol, PERIOD_D1, strategy_sma_period, 1);
   const double proxy_rsi = QM_RSI(g_proxy_symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(proxy_sma <= 0.0)
      return false;
   return (proxy_close < proxy_sma) && (proxy_rsi < strategy_rsi_oversold);
  }

// Populate `req` and return TRUE for a new LONG entry. Caller guarantees
// QM_IsNewBar()==true (one call per closed D1 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Need enough D1 history.
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_bars)
      return false;

   // 14-calendar-day fill throttle since the last filled entry under this magic.
   if(g_last_fill_time > 0)
     {
      // perf-allowed: single bar-open time read for the calendar-day throttle.
      const datetime now_bar = iTime(_Symbol, PERIOD_D1, 0);
      if(now_bar > 0 &&
         (now_bar - g_last_fill_time) < (datetime)((long)strategy_throttle_days * 86400))
         return false;
     }

   if(!QM_BothOversold())
      return false;

   // Build LONG market entry. Framework sizes lots from the SL distance.
   const double entry_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sl_price = QM_StopATR(_Symbol, QM_BUY, entry_px,
                                      strategy_atr_period, strategy_atr_sl_mult);

   req.type   = QM_BUY;
   req.price  = 0.0;        // framework fills at market
   req.sl     = sl_price;   // catastrophic ATR stop (price); 0.0 if ATR unavailable
   req.tp     = 0.0;        // no fixed TP — exits are rule-based
   req.reason = "quasar_mr_oversold";

   // Record fill time for the throttle (closed-bar cadence).
   // perf-allowed: single bar-open time read.
   g_last_fill_time = iTime(_Symbol, PERIOD_D1, 0);
   return true;
  }

// No active trade management beyond the static ATR stop and rule-based exits.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when price reverts to/above the SMA, RSI recovers to the exit
// threshold, or the position has been held for the time-stop bar count.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Only evaluate exits on a freshly closed D1 bar to keep it closed-bar based.
   // The framework's single-consume QM_IsNewBar is used by the entry gate in
   // OnTick; here we derive bar cadence from the position's own bar count and
   // the last closed bar's indicator values without consuming the new-bar event.
   // perf-allowed: single closed-bar close read for the mean-reversion exit.
   const double last_close = iClose(_Symbol, PERIOD_D1, 1);
   if(last_close <= 0.0)
      return false;
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);

   // Mean-reversion target reached.
   if(sma > 0.0 && last_close >= sma)
      return true;
   if(rsi >= strategy_rsi_exit)
      return true;

   // Time stop: close after N trading days held. Use the open position's
   // entry time vs the current D1 bar-open time.
   // perf-allowed: single bar-open time read for the time-stop bar count.
   const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // Bars elapsed on D1 since entry (broker-day proxy for trading days).
      const int held_bars = Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   // BASKET wiring: register the cross-symbol universe and warm its history so
   // foreign-symbol reads return real data in the tester. When proxy==_Symbol
   // the universe is a single symbol (still valid).
   g_proxy_symbol = QM_ResolveProxySymbol();
   string universe[];
   if(g_proxy_symbol == _Symbol)
     {
      ArrayResize(universe, 1);
      universe[0] = _Symbol;
     }
   else
     {
      ArrayResize(universe, 2);
      universe[0] = _Symbol;
      universe[1] = g_proxy_symbol;
     }
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, 300);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"proxy\":\"%s\"}", g_proxy_symbol));
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation.
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
