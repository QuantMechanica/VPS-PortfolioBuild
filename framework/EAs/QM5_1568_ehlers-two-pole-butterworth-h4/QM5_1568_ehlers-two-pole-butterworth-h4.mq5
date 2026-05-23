#property strict
#property version   "5.0"
#property description "QM5_1568 Ehlers Two-Pole Butterworth H4"

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
input int    qm_ea_id                   = 1568;
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
input int    strategy_filter_period     = 15;
input int    strategy_warmup_h4_bars    = 100;
input int    strategy_regime_sma_period = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_max_spread_atr    = 0.4;
input int    strategy_time_stop_h4_bars = 30;

double   g_bw_f0 = 0.0;
double   g_bw_f1 = 0.0;
double   g_bw_f2 = 0.0;
bool     g_bw_ready = false;
datetime g_bw_last_closed_bar = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int H4BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift > 0) ? shift : 0;
  }

bool AdvanceButterworthState()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1);
   if(closed_bar <= 0)
      return false;
   if(g_bw_ready && g_bw_last_closed_bar == closed_bar)
      return true;

   const int period = MathMax(2, strategy_filter_period);
   const int count = MathMax(strategy_warmup_h4_bars, period * 8) + 6;
   if(Bars(_Symbol, PERIOD_H4) < count + 2)
      return false;

   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_H4, 1, count, close) != count) // perf-allowed: cached once per closed H4 bar by g_bw_last_closed_bar.
      return false;

   double filt[];
   ArrayResize(filt, count);
   ArraySetAsSeries(filt, true);

   const double pi = 3.14159265358979323846;
   const double a = MathExp(-1.414 * pi / (double)period);
   const double b = 2.0 * a * MathCos(1.414 * 180.0 / (double)period * pi / 180.0);
   const double c2 = b;
   const double c3 = -a * a;
   const double c1 = 1.0 - c2 - c3;

   filt[count - 1] = close[count - 1];
   filt[count - 2] = close[count - 2];
   for(int i = count - 3; i >= 0; --i)
      filt[i] = c1 * (close[i] + 2.0 * close[i + 1] + close[i + 2]) / 4.0
                + c2 * filt[i + 1]
                + c3 * filt[i + 2];

   g_bw_f0 = filt[0];
   g_bw_f1 = filt[1];
   g_bw_f2 = filt[2];
   g_bw_ready = (g_bw_f0 > 0.0 && g_bw_f1 > 0.0 && g_bw_f2 > 0.0);
   g_bw_last_closed_bar = closed_bar;
   return g_bw_ready;
  }

bool ComputeButterworth(double &f0, double &f1, double &f2)
  {
   f0 = 0.0;
   f1 = 0.0;
   f2 = 0.0;

   if(!AdvanceButterworthState())
      return false;

   f0 = g_bw_f0;
   f1 = g_bw_f1;
   f2 = g_bw_f2;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   // No time-session restriction in the card. Spread is checked in EntrySignal
   // so open-position exits are not blocked by a wide spread.
   return false;
  }

bool SpreadAllowsEntry()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_atr * atr)
      return false;

   return true;
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

   if(_Period != PERIOD_H4)
      return false;
   if(!SpreadAllowsEntry())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(GetOurPosition(ticket, ptype, open_time))
      return false;

   double f0, f1, f2;
   if(!ComputeButterworth(f0, f1, f2))
      return false;

   const bool slope_up_now = (f0 > f1);
   const bool slope_up_prev = (f1 > f2);
   const bool slope_down_now = (f0 < f1);
   const bool slope_down_prev = (f1 < f2);

   const double close_h4 = iClose(_Symbol, PERIOD_H4, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(close_h4 <= 0.0 || close_d1 <= 0.0 || sma_d1 <= 0.0)
      return false;

   if(slope_up_now && !slope_up_prev && close_d1 > sma_d1 && close_h4 > f0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "BUTTERWORTH_SLOPE_UP";
      return (req.sl > 0.0);
     }

   if(slope_down_now && !slope_down_prev && close_d1 < sma_d1 && close_h4 < f0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "BUTTERWORTH_SLOPE_DOWN";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!GetOurPosition(ticket, ptype, open_time))
      return false;

   if(H4BarsHeld(open_time) >= strategy_time_stop_h4_bars)
      return true;

   double f0, f1, f2;
   if(!ComputeButterworth(f0, f1, f2))
      return false;

   const bool slope_up_now = (f0 > f1);
   const bool slope_up_prev = (f1 > f2);
   const bool slope_down_now = (f0 < f1);
   const bool slope_down_prev = (f1 < f2);

   if(ptype == POSITION_TYPE_BUY && slope_down_now && !slope_down_prev)
      return true;
   if(ptype == POSITION_TYPE_SELL && slope_up_now && !slope_up_prev)
      return true;

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
   if(_Period != PERIOD_H4 && MQLInfoInteger(MQL_TESTER) == 0)
      Print("QM5_1568 expects H4 chart period.");

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1568\",\"strategy\":\"ehlers_two_pole_butterworth_h4\"}");
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
