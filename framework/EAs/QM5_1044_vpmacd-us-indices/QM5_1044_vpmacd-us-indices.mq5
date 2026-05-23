#property strict
#property version   "5.0"
#property description "QM5_1044 VP-MACD US Indices"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1044;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_D1;
input int    strategy_fast_ema          = 12;
input int    strategy_slow_ema          = 26;
input int    strategy_signal_ema        = 9;
input double strategy_lambda            = 0.88;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input double strategy_max_spread_points = 250.0;
input bool   strategy_cash_session_only = true;
input int    strategy_cash_start_hhmm   = 1630;
input int    strategy_cash_end_hhmm     = 2300;

datetime g_exit_eval_bar = 0;
bool     g_exit_signal_cached = false;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_SymbolSlot()
  {
   if(_Symbol == "NDX.DWX")
      return 0;
   if(_Symbol == "WS30.DWX")
      return 1;
   return qm_magic_slot_offset;
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

double Strategy_VPStar(const MqlRates &bar)
  {
   const double volume = (bar.tick_volume > 0) ? (double)bar.tick_volume : 1.0;
   const double sigma = MathMax(bar.high - bar.low, _Point);
   const double range = MathMax(bar.high - bar.low, _Point);
   const double direction = (bar.close - bar.open) / range;
   const double typical = (bar.high + bar.low + bar.close) / 3.0;
   return (typical * volume * sigma * direction) / volume;
  }

bool Strategy_VPMacdAt(const int shift, double &out_macd, double &out_signal)
  {
   out_macd = 0.0;
   out_signal = 0.0;

   if(strategy_fast_ema <= 0 || strategy_slow_ema <= strategy_fast_ema || strategy_signal_ema <= 0)
      return false;
   if(strategy_lambda <= 0.0)
      return false;

   const int bars_needed = strategy_slow_ema + strategy_signal_ema + 20;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, shift, bars_needed, rates); // perf-allowed: EntrySignal is called only after QM_IsNewBar().
   if(copied < strategy_slow_ema + strategy_signal_ema + 2)
      return false;

   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double signal = 0.0;
   const double alpha_fast = 2.0 / (strategy_fast_ema + 1.0);
   const double alpha_slow = 2.0 / (strategy_slow_ema + 1.0);
   const double alpha_signal = 2.0 / (strategy_signal_ema + 1.0);

   for(int i = copied - 1; i >= 0; --i)
     {
      const double vp = Strategy_VPStar(rates[i]);
      if(i == copied - 1)
        {
         ema_fast = vp;
         ema_slow = vp;
        }
      else
        {
         ema_fast = alpha_fast * vp + (1.0 - alpha_fast) * ema_fast;
         ema_slow = alpha_slow * vp + (1.0 - alpha_slow) * ema_slow;
        }

      const double macd = ema_fast - ema_slow;
      if(i == copied - 1)
         signal = macd;
      else
         signal = alpha_signal * macd + (1.0 - alpha_signal) * signal;

      if(i == 0)
        {
         out_macd = macd;
         out_signal = signal;
        }
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
         return true;
      if((ask - bid) / _Point > strategy_max_spread_points)
         return true;
     }

   if(strategy_cash_session_only && _Period < PERIOD_D1)
     {
      const int now_hhmm = Strategy_Hhmm(TimeCurrent());
      if(now_hhmm < strategy_cash_start_hhmm || now_hhmm > strategy_cash_end_hhmm)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1044_VPMACD_LONG";
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double macd_prev = 0.0;
   double signal_prev = 0.0;
   double macd_now = 0.0;
   double signal_now = 0.0;
   if(!Strategy_VPMacdAt(2, macd_prev, signal_prev))
      return false;
   if(!Strategy_VPMacdAt(1, macd_now, signal_now))
      return false;

   if(!(macd_prev <= strategy_lambda * signal_prev && macd_now > strategy_lambda * signal_now))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.tp = 0.0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime closed_bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(closed_bar_time <= 0)
      return false;
   if(closed_bar_time == g_exit_eval_bar)
      return g_exit_signal_cached;

   g_exit_eval_bar = closed_bar_time;
   g_exit_signal_cached = false;

   double macd_prev = 0.0;
   double signal_prev = 0.0;
   double macd_now = 0.0;
   double signal_now = 0.0;
   if(!Strategy_VPMacdAt(2, macd_prev, signal_prev))
      return false;
   if(!Strategy_VPMacdAt(1, macd_now, signal_now))
      return false;

   g_exit_signal_cached = (macd_prev >= signal_prev && macd_now < signal_now);
   return g_exit_signal_cached;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to central V5 news filter.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1044\",\"ea\":\"QM5_1044_vpmacd_us_indices\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
