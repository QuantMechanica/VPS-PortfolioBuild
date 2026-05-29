#property strict
#property version   "5.0"
#property description "QM5_10050 ForexFactory Correlation Triad H1 MA Cross"

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
input int    qm_ea_id                   = 10050;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input string strategy_primary_symbol    = "EURUSD.DWX";
input string strategy_eurchf_symbol     = "EURCHF.DWX";
input string strategy_usdchf_symbol     = "USDCHF.DWX";
input ENUM_TIMEFRAMES strategy_tf       = PERIOD_H1;
input int    strategy_fast_sma_period   = 15;
input int    strategy_slow_sma_period   = 30;
input int    strategy_atr_period        = 10;
input double strategy_atr_tp_mult       = 1.0;
input double strategy_atr_sl_mult       = 3.0;
input double strategy_max_spread_points = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card trades EURUSD only; time and news filters are framework-level.
   if(_Symbol != strategy_primary_symbol)
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > (long)strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool BarExistsAt(const string sym, const ENUM_TIMEFRAMES tf, const datetime bar_time, int &shift)
  {
   shift = iBarShift(sym, tf, bar_time, true);
   return (shift >= 1);
  }

int CrossSignalAt(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(shift < 1 || strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= 0)
      return 0;

   const double fast_now = QM_SMA(sym, tf, strategy_fast_sma_period, shift);
   const double slow_now = QM_SMA(sym, tf, strategy_slow_sma_period, shift);
   const double fast_prev = QM_SMA(sym, tf, strategy_fast_sma_period, shift + 1);
   const double slow_prev = QM_SMA(sym, tf, strategy_slow_sma_period, shift + 1);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return 0;

   if(fast_prev <= slow_prev && fast_now > slow_now)
      return 1;
   if(fast_prev >= slow_prev && fast_now < slow_now)
      return -1;
   return 0;
  }

int TriadSignal()
  {
   const datetime primary_bar_time = iTime(strategy_primary_symbol, strategy_tf, 1);
   if(primary_bar_time <= 0)
      return 0;

   int eurusd_shift = 0;
   int eurchf_shift = 0;
   int usdchf_shift = 0;
   if(!BarExistsAt(strategy_primary_symbol, strategy_tf, primary_bar_time, eurusd_shift))
      return 0;
   if(!BarExistsAt(strategy_eurchf_symbol, strategy_tf, primary_bar_time, eurchf_shift))
      return 0;
   if(!BarExistsAt(strategy_usdchf_symbol, strategy_tf, primary_bar_time, usdchf_shift))
      return 0;

   const int eurusd = CrossSignalAt(strategy_primary_symbol, strategy_tf, eurusd_shift);
   const int eurchf = CrossSignalAt(strategy_eurchf_symbol, strategy_tf, eurchf_shift);
   const int usdchf = CrossSignalAt(strategy_usdchf_symbol, strategy_tf, usdchf_shift);

   if(eurusd > 0 && eurchf > 0 && usdchf < 0)
      return 1;
   if(eurusd < 0 && eurchf < 0 && usdchf > 0)
      return -1;
   return 0;
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int signal = TriadSignal();
   if(signal == 0)
      return false;

   const double atr = QM_ATR(strategy_primary_symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(signal > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - (strategy_atr_sl_mult * atr), _Digits);
      req.tp = NormalizeDouble(ask + (strategy_atr_tp_mult * atr), _Digits);
      req.reason = "FF_CORR_TRIAD_LONG";
      return true;
     }

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(bid + (strategy_atr_sl_mult * atr), _Digits);
   req.tp = NormalizeDouble(bid - (strategy_atr_tp_mult * atr), _Digits);
   req.reason = "FF_CORR_TRIAD_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline compresses optional partial/trailing management into fixed TP/SL.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int current_side = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      current_side = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }

   if(current_side == 0)
      return false;

   const int signal = TriadSignal();
   return (signal != 0 && signal == -current_side);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
