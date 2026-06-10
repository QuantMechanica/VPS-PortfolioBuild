#property strict
#property version   "5.0"
#property description "QM5_9411 PAQ Pin Bar Rejection — H1 multi-symbol (EURUSD/GBPUSD/USDJPY/XAUUSD)"

#include <QM/QM_Common.mqh>

// =============================================================================
// Cached per-closed-bar state (updated by Strategy_EntrySignal each new bar).
// Strategy_ExitSignal runs per-tick and reads these without consuming QM_IsNewBar.
// =============================================================================
bool g_bull_pin_cached      = false; // bullish pin bar detected on last closed bar
bool g_bear_pin_cached      = false; // bearish pin bar detected on last closed bar
bool g_ema_cross_long_exit  = false; // last bar close < EMA20 (flag long exit)
bool g_ema_cross_short_exit = false; // last bar close > EMA20 (flag short exit)

// =============================================================================
// Framework inputs
// =============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9411;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input double strategy_wick_body_ratio  = 2.0;  // min wick/body ratio for pin bar rejection
input int    strategy_min_body_pts     = 5;    // min body size in broker points
input int    strategy_atr_period       = 14;   // ATR period for SL offset
input double strategy_sl_atr_mult      = 0.25; // SL offset multiplier of ATR
input double strategy_tp_rr_mult       = 2.0;  // TP reward-risk multiple
input int    strategy_context_lookback = 10;   // prior bars to determine high/low context
input int    strategy_ema_period       = 20;   // EMA period for context filter and exit
input int    strategy_max_hold_bars    = 24;   // max hold in bars (H1 = 24 hours)

// =============================================================================
// Strategy hooks
// =============================================================================

// No trade filter — framework handles duplicate-position guard (QM_ENTRY_REJECTED_DUPLICATE).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry signal: detect pin bar on last closed bar (shift=1), apply context filter.
// Called only after QM_IsNewBar() — runs once per closed H1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;

   // --- Read last closed bar OHLC (shift=1, gated by QM_IsNewBar) ---
   const double open1  = iOpen (_Symbol, _Period, 1); // perf-allowed: pin-bar OHLC on new-bar gate
   const double high1  = iHigh (_Symbol, _Period, 1); // perf-allowed
   const double low1   = iLow  (_Symbol, _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed

   const double atr   = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double ema20 = QM_EMA(_Symbol, _Period, strategy_ema_period,  1);

   // --- Pin bar geometry ---
   const double body        = MathAbs(close1 - open1);
   const double upper_wick  = high1 - MathMax(open1, close1);
   const double lower_wick  = MathMin(open1, close1) - low1;
   const double min_body_sz = strategy_min_body_pts * _Point;

   // --- Update EMA-cross exit cache for open positions ---
   g_ema_cross_long_exit  = (close1 < ema20);
   g_ema_cross_short_exit = (close1 > ema20);

   // --- Pin bar shape conditions ---
   const bool bull_shape = (body >= min_body_sz) &&
                           (lower_wick > body * strategy_wick_body_ratio) &&
                           (upper_wick < body * 0.5);
   const bool bear_shape = (body >= min_body_sz) &&
                           (upper_wick > body * strategy_wick_body_ratio) &&
                           (lower_wick < body * 0.5);

   // --- Context filter: prior N-bar high/low (bounded loop on new-bar gate) ---
   double prior_low  = DBL_MAX;
   double prior_high = -DBL_MAX;
   for(int k = 2; k <= strategy_context_lookback + 1; k++)
     {
      const double lo = iLow (_Symbol, _Period, k); // perf-allowed: context lookback gated by QM_IsNewBar
      const double hi = iHigh(_Symbol, _Period, k); // perf-allowed
      if(lo < prior_low)  prior_low  = lo;
      if(hi > prior_high) prior_high = hi;
     }

   // P2 context: buy if pin-bar low below prior 10-bar low OR close below EMA20
   const bool bull_ctx = (low1  < prior_low)  || (close1 < ema20);
   // P2 context: sell if pin-bar high above prior 10-bar high OR close above EMA20
   const bool bear_ctx = (high1 > prior_high) || (close1 > ema20);

   // --- Cache opposite-signal exit flags ---
   g_bull_pin_cached = (bull_shape && bull_ctx);
   g_bear_pin_cached = (bear_shape && bear_ctx);

   // --- Entry: bullish pin bar with rejection context ---
   if(bull_shape && bull_ctx)
     {
      const double sl_price = low1 - strategy_sl_atr_mult * atr;
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk_pts = MathMax((ask - sl_price) / _Point, 1.0);
      req.type   = QM_BUY;
      req.price  = 0.0; // resolved as current ASK by framework
      req.sl     = sl_price;
      req.tp     = ask + strategy_tp_rr_mult * risk_pts * _Point;
      req.reason = "bull_pin";
      return true;
     }

   // --- Entry: bearish pin bar with rejection context ---
   if(bear_shape && bear_ctx)
     {
      const double sl_price = high1 + strategy_sl_atr_mult * atr;
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double risk_pts = MathMax((sl_price - bid) / _Point, 1.0);
      req.type   = QM_SELL;
      req.price  = 0.0; // resolved as current BID by framework
      req.sl     = sl_price;
      req.tp     = bid - strategy_tp_rr_mult * risk_pts * _Point;
      req.reason = "bear_pin";
      return true;
     }

   return false;
  }

// Trade management: no active management beyond framework SL/TP.
void Strategy_ManageOpenPosition()
  {
  }

// Exit signal: time stop, EMA close-through, and opposite pin bar (per cached flags).
// Runs per-tick; expensive checks guarded by elapsed-time to avoid false exits on
// the entry bar itself (entry bar may have close on the "wrong" side of EMA by design).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                   continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;

      const ENUM_POSITION_TYPE ptype   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime           open_tm = (datetime)PositionGetInteger(POSITION_TIME);
      const long               period_s = (long)PeriodSeconds(_Period);

      // Time exit: close after max_hold_bars full bar-periods
      if(TimeCurrent() >= open_tm + (long)strategy_max_hold_bars * period_s)
         return true;

      // EMA cross-through and opposite-pin exits: only after at least 1 full bar
      // has elapsed since entry (avoids false-exit on the entry bar when the pin bar's
      // close is naturally on the "filter side" of EMA — that's our entry context, not an exit).
      if(TimeCurrent() >= open_tm + period_s)
        {
         if(ptype == POSITION_TYPE_BUY)
           {
            if(g_ema_cross_long_exit) return true; // closed below EMA20 against long
            if(g_bear_pin_cached)     return true; // opposite bearish pin formed
           }
         else
           {
            if(g_ema_cross_short_exit) return true; // closed above EMA20 against short
            if(g_bull_pin_cached)      return true; // opposite bullish pin formed
           }
        }

      break; // one position per magic
     }
   return false;
  }

// News filter hook: defer to framework two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line
// =============================================================================

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
