#property strict
#property version   "5.0"
#property description "QM5_10069 MQL5 head-and-shoulders reversal"

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
input int    qm_ea_id                   = 10069;
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
input int    strategy_swing_lookback    = 7;
input int    strategy_scan_bars         = 90;
input int    strategy_max_spread_points = 50;
input int    strategy_stop_buffer_points = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_swing_lookback < 2 || strategy_scan_bars < 20)
      return false;

   const int bars_available = Bars(_Symbol, _Period);
   const int scan = MathMin(strategy_scan_bars, bars_available - strategy_swing_lookback - 2);
   if(scan <= strategy_swing_lookback + 8)
      return false;

   int swing_shift[96];
   int swing_kind[96];       // +1 swing high, -1 swing low
   double swing_price[96];
   int swing_count = 0;

   for(int shift = scan; shift >= strategy_swing_lookback + 1 && swing_count < 96; --shift)
     {
      const double high = iHigh(_Symbol, _Period, shift);
      const double low = iLow(_Symbol, _Period, shift);
      if(high <= 0.0 || low <= 0.0)
         continue;

      bool is_high = true;
      bool is_low = true;
      for(int j = 1; j <= strategy_swing_lookback; ++j)
        {
         if(high <= iHigh(_Symbol, _Period, shift - j) || high <= iHigh(_Symbol, _Period, shift + j))
            is_high = false;
         if(low >= iLow(_Symbol, _Period, shift - j) || low >= iLow(_Symbol, _Period, shift + j))
            is_low = false;
        }

      if(!is_high && !is_low)
         continue;

      const int kind = is_high ? 1 : -1;
      const double price = is_high ? high : low;
      if(swing_count > 0 && swing_kind[swing_count - 1] == kind)
        {
         if((kind > 0 && price > swing_price[swing_count - 1]) ||
            (kind < 0 && price < swing_price[swing_count - 1]))
           {
            swing_shift[swing_count - 1] = shift;
            swing_price[swing_count - 1] = price;
           }
         continue;
        }

      swing_shift[swing_count] = shift;
      swing_kind[swing_count] = kind;
      swing_price[swing_count] = price;
      swing_count++;
     }

   if(swing_count < 6)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(close1 <= 0.0 || close2 <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   for(int i = swing_count - 6; i >= 0; --i)
     {
      const int x = i;
      const int a = i + 1;
      const int b = i + 2;
      const int c = i + 3;
      const int d = i + 4;
      const int e = i + 5;

      if(swing_kind[x] == -1 && swing_kind[a] == 1 && swing_kind[b] == -1 &&
         swing_kind[c] == 1 && swing_kind[d] == -1 && swing_kind[e] == 1)
        {
         if(swing_price[c] <= swing_price[a] || swing_price[c] <= swing_price[e])
            continue;
         if(swing_shift[b] == swing_shift[d])
            continue;

         const double neckline = swing_price[b] +
            (swing_price[d] - swing_price[b]) *
            ((double)(swing_shift[b] - 1) / (double)(swing_shift[b] - swing_shift[d]));

         if(close2 < neckline || close1 >= neckline)
            continue;

         const double entry = bid;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_price[e] + strategy_stop_buffer_points * point);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, swing_price[x]);
         if(sl <= entry || tp >= entry)
            continue;
         if((entry - tp) <= (sl - entry))
            continue;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "MQL5_HS_REV_SELL_NECKLINE_BREAK";
         return true;
        }

      if(swing_kind[x] == 1 && swing_kind[a] == -1 && swing_kind[b] == 1 &&
         swing_kind[c] == -1 && swing_kind[d] == 1 && swing_kind[e] == -1)
        {
         if(swing_price[c] >= swing_price[a] || swing_price[c] >= swing_price[e])
            continue;
         if(swing_shift[b] == swing_shift[d])
            continue;

         const double neckline = swing_price[b] +
            (swing_price[d] - swing_price[b]) *
            ((double)(swing_shift[b] - 1) / (double)(swing_shift[b] - swing_shift[d]));

         if(close2 > neckline || close1 <= neckline)
            continue;

         const double entry = ask;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, swing_price[e] - strategy_stop_buffer_points * point);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, swing_price[x]);
         if(sl >= entry || tp <= entry)
            continue;
         if((tp - entry) <= (entry - sl))
            continue;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "MQL5_HS_REV_BUY_NECKLINE_BREAK";
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card exits by SL/TP only; no trailing, break-even, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card has no discretionary close while a position is open.
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
