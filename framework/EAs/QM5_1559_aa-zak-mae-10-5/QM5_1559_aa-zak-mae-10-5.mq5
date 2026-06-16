#property strict
#property version   "5.0"
#property description "QM5_1559 Alpha Architect Zakamulin SMA(10) 5% Envelope Timing"
// rework v2 2026-06-16 — MN1-native logic untestable in MT5 tester (DWX MN1 => 0 bars/0 ticks => QM_SMA(MN1)=0 => 0 trades, false Q02 MIN_TRADES FAIL). Rebuilt D1-native: SMA(10) monthly closes ~= 210-day D1 SMA, evaluated on the first D1 bar of each new calendar month. Mechanics (5% envelope long-only entry/exit, ATR(20,D1)x3 SL, monthly rebalance) preserved.

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
input int    qm_ea_id                    = 1559;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
// D1-native proxy of the monthly SMA(10) envelope. The MT5 tester yields 0 bars on
// PERIOD_MN1 for DWX symbols, so the monthly SMA is approximated from D1 closes:
// 10 months x 21 trading days ~= 210 D1 bars. The envelope is evaluated once per
// calendar month, on the first D1 bar of the new month (the prior month just closed).
input int    strategy_sma_d1_bars        = 210;   // 10-month SMA proxy on D1 closes
input double strategy_envelope_pct       = 5.0;
input int    strategy_min_d1_bars        = 231;   // 210 SMA window + ~1 month warmup
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_max_spread_points  = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// True on the first completed D1 bar of a new calendar month, i.e. when the prior
// calendar month has just finished. This is the D1-native stand-in for "evaluate on
// the final completed monthly bar" / "rebalance monthly".
bool Strategy_IsNewMonthD1Bar()
  {
   const datetime closed_bar  = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_d1_bars <= 0 || strategy_envelope_pct <= 0.0 ||
      strategy_min_d1_bars < strategy_sma_d1_bars + 1 ||
      strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   // Rebalance monthly: only act on the first completed D1 bar of a new month.
   if(!Strategy_IsNewMonthD1Bar())
      return false;

   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1_bars, 1, PRICE_CLOSE);
   if(close_d1 <= 0.0 || sma_d1 <= 0.0)
      return false;

   const double upper_envelope = sma_d1 * (1.0 + strategy_envelope_pct / 100.0);
   if(close_d1 <= upper_envelope)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.reason = "D1_CLOSE_ABOVE_SMA210_PLUS_5PCT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      break;
     }

   if(!have_position)
      return false;
   if(strategy_sma_d1_bars <= 0 || strategy_envelope_pct <= 0.0)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   // Rebalance monthly: only evaluate the exit on the first D1 bar of a new month.
   if(!Strategy_IsNewMonthD1Bar())
      return false;

   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_d1_bars, 1, PRICE_CLOSE);
   if(close_d1 <= 0.0 || sma_d1 <= 0.0)
      return false;

   const double lower_envelope = sma_d1 * (1.0 - strategy_envelope_pct / 100.0);
   return (close_d1 < lower_envelope);
  }

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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1559_aa_zak_mae_10_5\"}");
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
