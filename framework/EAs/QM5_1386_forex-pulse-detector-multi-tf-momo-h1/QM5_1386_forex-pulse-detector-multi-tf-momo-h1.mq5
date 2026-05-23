#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 1386;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int         strategy_ema_fast             = 20;
input int         strategy_ema_pulse            = 50;
input int         strategy_ema_slow             = 200;
input int         strategy_rsi_period           = 14;
input int         strategy_atr_period           = 14;
input int         strategy_macd_fast            = 12;
input int         strategy_macd_slow            = 26;
input int         strategy_macd_signal          = 9;
input int         strategy_fresh_bars           = 8;
input int         strategy_time_stop_bars       = 36;
input double      strategy_atr_sl_mult          = 1.5;
input double      strategy_atr_tp_mult          = 2.5;
input double      strategy_be_trigger_atr       = 1.0;
input double      strategy_be_buffer_atr        = 0.1;
input double      strategy_trail_trigger_atr    = 2.0;
input double      strategy_trail_lock_atr       = 1.0;
input double      strategy_min_atr_avg_mult     = 0.7;
input double      strategy_max_atr_avg_mult     = 3.0;
input double      strategy_max_spread_atr_mult  = 0.4;
input int         strategy_session_start_hour   = 6;
input int         strategy_session_end_hour     = 20;
input int         strategy_friday_cutoff_hour   = 18;
input QM_NewsMode strategy_entry_news_mode      = QM_NEWS_PAUSE;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return true;

   if(!QM_NewsAllowsTrade(_Symbol, broker_now, strategy_entry_news_mode))
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return true;
   if((ask - bid) >= strategy_max_spread_atr_mult * atr)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double atr_now = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   double atr20_sum = 0.0;
   for(int a20 = 1; a20 <= 20; ++a20)
     {
      const double v = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, a20);
      if(v <= 0.0)
         return false;
      atr20_sum += v;
     }
   double atr60_sum = 0.0;
   for(int a60 = 1; a60 <= 60; ++a60)
     {
      const double v = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, a60);
      if(v <= 0.0)
         return false;
      atr60_sum += v;
     }
   if(atr_now < strategy_min_atr_avg_mult * (atr20_sum / 20.0))
      return false;
   if(atr_now > strategy_max_atr_avg_mult * (atr60_sum / 60.0))
      return false;

   const double d1_ema1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_pulse, 1);
   const double d1_ema2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_pulse, 2);
   const double d1_ema3 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_pulse, 3);
   const double d1_rsi1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double d1_close1 = iClose(_Symbol, PERIOD_D1, 1);

   const double h4_ema1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_pulse, 1);
   const double h4_ema2 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_pulse, 2);
   const double h4_ema3 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_pulse, 3);
   const double h4_rsi1 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1);
   const double h4_hist1 = QM_MACD_Main(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1) -
                           QM_MACD_Signal(_Symbol, PERIOD_H4, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double h4_close1 = iClose(_Symbol, PERIOD_H4, 1);

   const double h1_ema20 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double h1_ema50_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pulse, 1);
   const double h1_ema50_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pulse, 2);
   const double h1_ema50_3 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_pulse, 3);
   const double h1_ema200 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1);
   const double h1_rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double h1_hist1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1) -
                           QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double h1_close1 = iClose(_Symbol, PERIOD_H1, 1);

   const bool d1_up = (d1_ema1 > d1_ema2 && d1_ema2 > d1_ema3 && d1_rsi1 > 50.0 && d1_close1 > d1_ema1);
   const bool h4_up = (h4_ema1 > h4_ema2 && h4_ema2 > h4_ema3 && h4_rsi1 > 50.0 && h4_hist1 > 0.0 && h4_close1 > h4_ema1);
   const bool h1_up = (h1_ema50_1 > h1_ema50_2 && h1_ema50_2 > h1_ema50_3 && h1_rsi1 > 50.0 && h1_hist1 > 0.0 && h1_close1 > h1_ema50_1);
   const bool stack_up = (h1_ema20 > h1_ema50_1 && h1_ema50_1 > h1_ema200 && h1_close1 > h1_ema20);

   bool fresh_up = false;
   bool fresh_down = false;
   for(int f = 1; f <= strategy_fresh_bars; ++f)
     {
      const double hist_i = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, f) -
                            QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, f);
      const double hist_prev = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, f + 1) -
                               QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, f + 1);
      if(hist_i > 0.0 && hist_prev <= 0.0)
         fresh_up = true;
      if(hist_i < 0.0 && hist_prev >= 0.0)
         fresh_down = true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(d1_up && h4_up && h1_up && stack_up && fresh_up && ask > 0.0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - strategy_atr_sl_mult * atr_now, _Digits);
      req.tp = NormalizeDouble(ask + strategy_atr_tp_mult * atr_now, _Digits);
      req.reason = "FPD_3TF_UP_PULSE";
      return true;
     }

   const bool d1_down = (d1_ema1 < d1_ema2 && d1_ema2 < d1_ema3 && d1_rsi1 < 50.0 && d1_close1 < d1_ema1);
   const bool h4_down = (h4_ema1 < h4_ema2 && h4_ema2 < h4_ema3 && h4_rsi1 < 50.0 && h4_hist1 < 0.0 && h4_close1 < h4_ema1);
   const bool h1_down = (h1_ema50_1 < h1_ema50_2 && h1_ema50_2 < h1_ema50_3 && h1_rsi1 < 50.0 && h1_hist1 < 0.0 && h1_close1 < h1_ema50_1);
   const bool stack_down = (h1_ema20 < h1_ema50_1 && h1_ema50_1 < h1_ema200 && h1_close1 < h1_ema20);

   if(d1_down && h4_down && h1_down && stack_down && fresh_down && bid > 0.0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + strategy_atr_sl_mult * atr_now, _Digits);
      req.tp = NormalizeDouble(bid - strategy_atr_tp_mult * atr_now, _Digits);
      req.reason = "FPD_3TF_DOWN_PULSE";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      if(entry <= 0.0 || tp <= 0.0)
         continue;

      const double atr_entry = MathAbs(tp - entry) / strategy_atr_tp_mult;
      if(atr_entry <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY && bid > 0.0)
        {
         const double favorable = bid - entry;
         double desired_sl = current_sl;
         if(favorable >= strategy_trail_trigger_atr * atr_entry)
            desired_sl = entry + strategy_trail_lock_atr * atr_entry;
         else if(favorable >= strategy_be_trigger_atr * atr_entry)
            desired_sl = entry + strategy_be_buffer_atr * atr_entry;

         desired_sl = NormalizeDouble(desired_sl, _Digits);
         if(desired_sl > current_sl && desired_sl < bid)
            QM_TM_MoveSL(ticket, desired_sl, "FPD_ATR_PULSE_TRAIL_BUY");
        }

      if(ptype == POSITION_TYPE_SELL && ask > 0.0)
        {
         const double favorable = entry - ask;
         double desired_sl = current_sl;
         if(favorable >= strategy_trail_trigger_atr * atr_entry)
            desired_sl = entry - strategy_trail_lock_atr * atr_entry;
         else if(favorable >= strategy_be_trigger_atr * atr_entry)
            desired_sl = entry - strategy_be_buffer_atr * atr_entry;

         desired_sl = NormalizeDouble(desired_sl, _Digits);
         if((current_sl <= 0.0 || desired_sl < current_sl) && desired_sl > ask)
            QM_TM_MoveSL(ticket, desired_sl, "FPD_ATR_PULSE_TRAIL_SELL");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double hist1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1) -
                        QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double hist2 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2) -
                        QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const datetime last_closed_bar = iTime(_Symbol, PERIOD_H1, 1);
   const int period_seconds = PeriodSeconds(PERIOD_H1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && hist1 < 0.0 && hist2 >= 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && hist1 > 0.0 && hist2 <= 0.0)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(last_closed_bar > open_time && period_seconds > 0 &&
         ((last_closed_bar - open_time) / period_seconds) >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
