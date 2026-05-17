#property strict
#property version   "5.0"
#property description "QM5_1119 FPS Tom's MA RSI H1"

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
input int    qm_ea_id                   = 1119;
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
input int    strategy_fast_ma_period    = 5;
input int    strategy_slow_ma_period    = 12;
input int    strategy_rsi_period        = 21;
input double strategy_rsi_midline       = 50.0;
input int    strategy_swing_lookback    = 10;
input double strategy_rr_take_profit    = 2.0;
input int    strategy_max_spread_points = 20;
input bool   strategy_session_filter_on = false;
input int    strategy_session_start_h   = 0;
input int    strategy_session_end_h     = 24;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): news is handled by Strategy_NewsFilterHook
// plus QM_NewsAllowsTrade in framework wiring; this hook adds spread/session gates.
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   if(strategy_session_filter_on)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_h));
      const int end_h = MathMax(0, MathMin(24, strategy_session_end_h));
      if(start_h != end_h)
        {
         if(start_h < end_h && (dt.hour < start_h || dt.hour >= end_h))
            return true;
         if(start_h > end_h && (dt.hour < start_h && dt.hour >= end_h))
            return true;
        }
     }

   return false;
  }

// Trade Entry: D1 EMA(5)-vs-SMA(12) bias plus H1 EMA/SMA closed-bar cross and RSI(21).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fast_ma_period <= 0 || strategy_slow_ma_period <= 0 ||
      strategy_rsi_period <= 0 || strategy_swing_lookback <= 0 ||
      strategy_rr_take_profit <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   int bias = 0;
   const double d1_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double d1_slow = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_ma_period, 1, PRICE_CLOSE);
   if(d1_fast > d1_slow && d1_slow > 0.0)
      bias = 1;
   else if(d1_fast < d1_slow && d1_fast > 0.0)
      bias = -1;

   int cross = 0;
   const double h1_fast_now = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double h1_slow_now = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double h1_fast_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ma_period, 2, PRICE_CLOSE);
   const double h1_slow_prev = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_ma_period, 2, PRICE_CLOSE);
   if(h1_fast_prev <= h1_slow_prev && h1_fast_now > h1_slow_now &&
      h1_fast_prev > 0.0 && h1_slow_prev > 0.0)
      cross = 1;
   else if(h1_fast_prev >= h1_slow_prev && h1_fast_now < h1_slow_now &&
           h1_fast_now > 0.0 && h1_slow_now > 0.0)
      cross = -1;

   if(bias == 0 || cross == 0 || bias != cross)
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(cross > 0 && rsi > strategy_rsi_midline)
     {
      req.type = QM_BUY;
      req.sl = QM_StopStructure(_Symbol, req.type, ask, strategy_swing_lookback);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_take_profit);
      req.reason = "FPS_MA_RSI_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(cross < 0 && rsi < strategy_rsi_midline)
     {
      req.type = QM_SELL;
      req.sl = QM_StopStructure(_Symbol, req.type, bid, strategy_swing_lookback);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_take_profit);
      req.reason = "FPS_MA_RSI_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Trade Management: card specifies no trailing, break-even, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: opposite H1 MA cross or D1 bias flip.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   bool have_position = false;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   int bias = 0;
   const double d1_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double d1_slow = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_ma_period, 1, PRICE_CLOSE);
   if(d1_fast > d1_slow && d1_slow > 0.0)
      bias = 1;
   else if(d1_fast < d1_slow && d1_fast > 0.0)
      bias = -1;

   int cross = 0;
   const double h1_fast_now = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double h1_slow_now = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double h1_fast_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ma_period, 2, PRICE_CLOSE);
   const double h1_slow_prev = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_ma_period, 2, PRICE_CLOSE);
   if(h1_fast_prev <= h1_slow_prev && h1_fast_now > h1_slow_now &&
      h1_fast_prev > 0.0 && h1_slow_prev > 0.0)
      cross = 1;
   else if(h1_fast_prev >= h1_slow_prev && h1_fast_now < h1_slow_now &&
           h1_fast_now > 0.0 && h1_slow_now > 0.0)
      cross = -1;

   if(ptype == POSITION_TYPE_BUY)
      return (cross < 0 || bias < 0);
   if(ptype == POSITION_TYPE_SELL)
      return (cross > 0 || bias > 0);

   return false;
  }

// News Filter Hook: P8-callable hook; default P2 behavior is no custom override.
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
