#property strict
#property version   "5.0"
#property description "QM5_10787 TradingView EMA Cross + RSI + ADX (tv-ema-rsi-adx)"
// Strategy Card: QM5_10787 (tv-ema-rsi-adx), G0 APPROVED 2026-05-22.
// Source: varuns_back, "EMA Cross + RSI + ADX - Autotrade Strategy V2",
//   TradingView open-source script e7XQPek8 (see card for full citation/URL).

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — tv-ema-rsi-adx
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   Long  : EMA(fast) crosses ABOVE EMA(slow) AND RSI > long-threshold
//           AND (ADX filter off OR ADX > adx-threshold) AND no open position.
//   Short : EMA(fast) crosses BELOW EMA(slow) AND RSI < short-threshold
//           AND (ADX filter off OR ADX > adx-threshold) AND no open position.
//   Exit  : opposite EMA crossover closes the open position (Strategy_ExitSignal),
//           or the fixed stop-loss is hit (SL on the order).
//   V5 baseline disables instant auto-reversal: an opposite cross CLOSES the
//   current position on its bar; a fresh entry can only fire on the NEXT bar.
//   This is enforced by g_suppress_entry_after_exit (set when the opposite-cross
//   close fires, consumed by Strategy_EntrySignal on the same closed bar).
// All per-tick scaffolding (OnInit/OnTick wiring, risk, magic, news,
// Friday-close, kill-switch) is framework boilerplate left intact below.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10787;
input int    qm_magic_slot_offset       = 0;
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
// --- EMA crossover (card: EMA 9 / EMA 21 baseline; P3 sweeps 12/26, 20/50) ---
input int    strategy_ema_fast          = 9;
input int    strategy_ema_slow          = 21;
// --- RSI momentum filter (card: long>55, short<45; P3 sweeps 52/48, 60/40) ---
input int    strategy_rsi_period        = 14;
input double strategy_rsi_long_thresh   = 55.0;
input double strategy_rsi_short_thresh  = 45.0;
// --- ADX trend-strength filter (card: optional, ADX>20; P3 axis off/15/20/25) ---
input bool   strategy_adx_filter_on     = true;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 20.0;
// --- Stop loss (card: ATR-normalized P2 baseline; fixed-pct ablation; P3 axis) ---
input int    strategy_stop_mode         = 0;     // 0 = ATR(period)*mult, 1 = fixed percent
input int    strategy_stop_atr_period   = 14;
input double strategy_stop_atr_mult     = 2.0;
input double strategy_stop_fixed_pct    = 2.0;   // fixed-percent stop distance (card source default)

// File-scope reversal latch (NOT a new-bar reimplementation): set on the bar
// where an opposite-cross close fires, consumed by Strategy_EntrySignal so the
// reversing entry waits until the next closed bar (card: no instant reversal).
bool g_suppress_entry_after_exit = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Return the open position type for THIS EA's magic on the current symbol.
// out_type valid only when the function returns true.
bool Strategy_GetOpenPosition(ENUM_POSITION_TYPE &out_type)
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
      out_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// Resolve the stop price for a fresh entry per the selected stop mode.
double Strategy_ResolveStop(const QM_OrderType side, const double entry)
  {
   if(entry <= 0.0)
      return 0.0;

   if(strategy_stop_mode == 1)
     {
      // Fixed-percent stop (card source default: 2% from entry).
      const double dist = entry * (strategy_stop_fixed_pct / 100.0);
      if(dist <= 0.0)
         return 0.0;
      const double raw = QM_OrderTypeIsBuy(side) ? (entry - dist) : (entry + dist);
      return NormalizeDouble(raw, _Digits);
     }

   // Default: ATR-normalized stop (P2 baseline).
   return QM_StopATR(_Symbol, side, entry, strategy_stop_atr_period, strategy_stop_atr_mult);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick gate. News / spread / Friday-close are handled by the framework;
// ADX/regime gating lives in the entry rule, so nothing to block here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Fired once per closed bar (caller guarantees QM_IsNewBar()). Builds a market
// entry on an EMA cross confirmed by RSI and (optionally) ADX.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // No-instant-reversal latch: if we just closed on an opposite cross this bar,
   // skip the entry and let the next closed bar evaluate fresh.
   if(g_suppress_entry_after_exit)
     {
      g_suppress_entry_after_exit = false;
      return false;
     }

   // One position per symbol/magic (framework also enforces duplicate guard).
   ENUM_POSITION_TYPE open_type;
   if(Strategy_GetOpenPosition(open_type))
      return false;

   const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                     strategy_ema_fast, strategy_ema_slow, 1);
   if(cross == 0)
      return false;

   // Optional ADX trend-strength gate.
   if(strategy_adx_filter_on)
     {
      const double adx = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
      if(adx <= strategy_adx_threshold)
         return false;
     }

   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);

   req.price = 0.0;            // market order; framework resolves Ask/Bid
   req.tp = 0.0;              // no fixed target — exit on opposite cross or SL
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(cross > 0 && rsi > strategy_rsi_long_thresh)
     {
      req.type = QM_BUY;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = Strategy_ResolveStop(QM_BUY, entry);
      req.reason = "tv_ema_rsi_adx_long";
      return (req.sl > 0.0);
     }

   if(cross < 0 && rsi < strategy_rsi_short_thresh)
     {
      req.type = QM_SELL;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = Strategy_ResolveStop(QM_SELL, entry);
      req.reason = "tv_ema_rsi_adx_short";
      return (req.sl > 0.0);
     }

   return false;
  }

// Card: no trailing / break-even / partial-close logic in the baseline.
void Strategy_ManageOpenPosition()
  {
  }

// Card exit: opposite EMA crossover closes the open position. Only fires when we
// actually hold a position whose direction is opposed by the latest cross — and
// sets the reversal latch so the framework-driven close is not re-entered on the
// same bar.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE open_type;
   if(!Strategy_GetOpenPosition(open_type))
      return false;

   const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                     strategy_ema_fast, strategy_ema_slow, 1);
   if(cross == 0)
      return false;

   const bool exit_long  = (open_type == POSITION_TYPE_BUY  && cross < 0);
   const bool exit_short = (open_type == POSITION_TYPE_SELL && cross > 0);
   if(exit_long || exit_short)
     {
      g_suppress_entry_after_exit = true;   // no instant reversal this bar
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10787_tv-ema-rsi-adx\"}");
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
