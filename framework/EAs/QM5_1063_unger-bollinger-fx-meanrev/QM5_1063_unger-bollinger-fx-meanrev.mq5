#property strict
#property version   "5.0"
#property description "QM5_1063 Unger Bollinger FX mean reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1063;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_adx_period         = 14;
input int    strategy_adx_median_bars    = 100;
input double strategy_adx_gate           = 20.0;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 1.5;
input int    strategy_max_hold_bars      = 12;
input int    strategy_spread_median_days = 20;

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= 21)
      return true;
   if(dt.day_of_week == 6)
      return true;
   if(dt.day_of_week == 0 && dt.hour < 22)
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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return false;

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

   const int spread_bars = strategy_spread_median_days * 24;
   if(spread_bars <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, spread_bars, rates); // perf-allowed: EntrySignal is called only after QM_IsNewBar().
   if(copied <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int spread_count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[spread_count] = (double)rates[i].spread;
      ++spread_count;
     }
   if(spread_count <= 0)
      return false;
   ArrayResize(spreads, spread_count);
   ArraySort(spreads);

   const int spread_mid = spread_count / 2;
   const double median_spread = ((spread_count % 2) == 1)
      ? spreads[spread_mid]
      : (spreads[spread_mid - 1] + spreads[spread_mid]) * 0.5;
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread > (2.0 * median_spread))
      return false;

   double adx_values[];
   ArrayResize(adx_values, strategy_adx_median_bars);
   int adx_count = 0;
   for(int shift = 1; shift <= strategy_adx_median_bars; ++shift)
     {
      const double v = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, shift);
      if(v <= 0.0)
         continue;
      adx_values[adx_count] = v;
      ++adx_count;
     }
   if(adx_count <= 0)
      return false;
   ArrayResize(adx_values, adx_count);
   ArraySort(adx_values);

   const int adx_mid = adx_count / 2;
   const double median_adx = ((adx_count % 2) == 1)
      ? adx_values[adx_mid]
      : (adx_values[adx_mid - 1] + adx_values[adx_mid]) * 0.5;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   if(close1 <= 0.0 || upper <= 0.0 || lower <= 0.0 || adx <= 0.0 || median_adx <= 0.0)
      return false;

   const double regime_gate = MathMin(strategy_adx_gate, median_adx);
   if(adx >= regime_gate)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return false;

   if(close1 > upper)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_sl_atr_mult);
      req.reason = "UNGER_BB_FADE_SHORT";
      return (entry > 0.0 && req.sl > 0.0);
     }

   if(close1 < lower)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_sl_atr_mult);
      req.reason = "UNGER_BB_FADE_LONG";
      return (entry > 0.0 && req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no break-even, trailing, partial close, or pyramiding rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return false;

   static datetime last_checked_bar = 0;
   const datetime bar_t = iTime(_Symbol, PERIOD_H1, 1);
   if(bar_t <= 0 || bar_t == last_checked_bar)
      return false;
   last_checked_bar = bar_t;

   const int magic = QM_FrameworkMagic();
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
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const double close1 = iClose(_Symbol, PERIOD_H1, 1);
      const double middle1 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
      if(close1 <= 0.0 || middle1 <= 0.0)
         return false;

      if(ptype == POSITION_TYPE_BUY && close1 >= middle1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 <= middle1)
         return true;

      if(opened_at > 0 && strategy_max_hold_bars > 0)
        {
         if((bar_t - opened_at) >= (strategy_max_hold_bars * 3600))
            return true;
        }
     }

   return false;
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
