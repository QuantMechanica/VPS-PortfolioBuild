#property strict
#property version   "5.0"
#property description "QM5_1567 DeMark TD-Reverse-Sequential H4"

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
input int    qm_ea_id                   = 1567;
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
input int    strategy_setup_bars         = 9;
input int    strategy_countdown_bars     = 13;
input int    strategy_countdown_timeout  = 24;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_buffer      = 0.5;
input double strategy_sl_atr_cap         = 3.0;
input double strategy_tp_atr_mult        = 1.5;
input double strategy_spread_atr_mult    = 0.4;
input int    strategy_regime_sma_period  = 200;
input int    strategy_time_stop_h4_bars  = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

datetime g_last_signal_bar_time = 0;

bool SetupChain(const bool is_buy, const int setup_end_shift)
  {
   for(int k = 0; k < strategy_setup_bars; ++k)
     {
      const int shift = setup_end_shift + k;
      const double c = iClose(_Symbol, PERIOD_H4, shift);
      const double c4 = iClose(_Symbol, PERIOD_H4, shift + 4);
      if(c <= 0.0 || c4 <= 0.0)
         return false;
      if(is_buy)
        {
         if(c <= c4)
            return false;
        }
      else
        {
         if(c >= c4)
            return false;
        }
     }
   return true;
  }

bool CountdownTrigger(const bool is_buy, const int setup_end_shift, double &bar13_extreme)
  {
   int count = 0;
   double close_bar8 = 0.0;
   bar13_extreme = 0.0;

   for(int shift = setup_end_shift - 1; shift >= 1; --shift)
     {
      bool qualifies = false;
      if(is_buy)
        {
         const double low_now = iLow(_Symbol, PERIOD_H4, shift);
         const double low_ref = iLow(_Symbol, PERIOD_H4, shift + 2);
         if(low_now <= 0.0 || low_ref <= 0.0)
            return false;
         qualifies = (low_now < low_ref);
        }
      else
        {
         const double high_now = iHigh(_Symbol, PERIOD_H4, shift);
         const double high_ref = iHigh(_Symbol, PERIOD_H4, shift + 2);
         if(high_now <= 0.0 || high_ref <= 0.0)
            return false;
         qualifies = (high_now > high_ref);
        }

      if(!qualifies)
         continue;

      count++;
      if(count == 8)
         close_bar8 = iClose(_Symbol, PERIOD_H4, shift);

      if(count == strategy_countdown_bars)
        {
         if(shift != 1 || close_bar8 <= 0.0)
            return false;
         if(is_buy)
           {
            bar13_extreme = iLow(_Symbol, PERIOD_H4, 1);
            return (bar13_extreme > 0.0 && bar13_extreme < close_bar8);
           }
         bar13_extreme = iHigh(_Symbol, PERIOD_H4, 1);
         return (bar13_extreme > 0.0 && bar13_extreme > close_bar8);
        }
     }

   return false;
  }

bool FindReverseSequentialSignal(bool &is_buy, double &bar13_extreme)
  {
   const int max_setup_end_shift = strategy_countdown_timeout + 1;
   for(int setup_end_shift = 2; setup_end_shift <= max_setup_end_shift; ++setup_end_shift)
     {
      if(SetupChain(true, setup_end_shift) &&
         CountdownTrigger(true, setup_end_shift, bar13_extreme))
        {
         is_buy = true;
         return true;
        }

      if(SetupChain(false, setup_end_shift) &&
         CountdownTrigger(false, setup_end_shift, bar13_extreme))
        {
         is_buy = false;
         return true;
        }
     }
   return false;
  }

bool HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Return TRUE to BLOCK trading this tick (No Trade Filter: time, spread, news).
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) > strategy_spread_atr_mult * atr)
      return true;
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
   req.reason = "td_reverse_sequential";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOpenPositionForMagic())
      return false;

   const datetime signal_bar_time = iTime(_Symbol, PERIOD_H4, 1);
   if(signal_bar_time <= 0 || signal_bar_time == g_last_signal_bar_time)
      return false;

   bool is_buy = true;
   double bar13_extreme = 0.0;
   if(!FindReverseSequentialSignal(is_buy, bar13_extreme))
      return false;

   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;
   if(is_buy && d1_close <= d1_sma)
      return false;
   if(!is_buy && d1_close >= d1_sma)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double entry = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || entry <= 0.0 || point <= 0.0)
      return false;

   const double raw_sl = is_buy ? (bar13_extreme - strategy_sl_atr_buffer * atr)
                                : (bar13_extreme + strategy_sl_atr_buffer * atr);
   const double sl_dist = MathAbs(entry - raw_sl);
   if(sl_dist <= 0.0 || sl_dist > strategy_sl_atr_cap * atr)
      return false;

   req.type = is_buy ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(raw_sl, _Digits);
   req.tp = NormalizeDouble(is_buy ? (entry + strategy_tp_atr_mult * atr)
                                   : (entry - strategy_tp_atr_mult * atr), _Digits);
   req.reason = is_buy ? "td_reverse_sequential_buy" : "td_reverse_sequential_sell";

   g_last_signal_bar_time = signal_bar_time;
   // Lot sizing is delegated to QM_TM_OpenPosition via QM_LotsForRisk().
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Fixed SL/TP only; the card explicitly forbids trailing.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_h4_bars * PeriodSeconds(PERIOD_H4);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
                        qm_friday_close_hour_broker))
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
