#property strict
#property version   "5.0"
#property description "QM5_1555 Alpha Architect Factor Long/Short 50/200 MA Filter"

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
input int    qm_ea_id                   = 1555;
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
input int    strategy_fast_sma_days      = 50;
input int    strategy_slow_sma_days      = 200;
input int    strategy_momentum_days      = 252;
input int    strategy_min_daily_bars     = 260;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_min_universe       = 9;
input int    strategy_small_universe_rank = 2;
input int    strategy_rebalance_day_max  = 7;
input int    strategy_max_spread_points  = 80;
input string strategy_universe_csv       = "AUDCAD.DWX,AUDCHF.DWX,AUDJPY.DWX,AUDNZD.DWX,AUDUSD.DWX,CADCHF.DWX,CADJPY.DWX,CHFJPY.DWX,EURAUD.DWX,EURCAD.DWX,EURCHF.DWX,EURGBP.DWX,EURJPY.DWX,EURNZD.DWX,EURUSD.DWX,GBPAUD.DWX,GBPCAD.DWX,GBPCHF.DWX,GBPJPY.DWX,GBPNZD.DWX,GBPUSD.DWX,GDAXI.DWX,NDX.DWX,NZDCAD.DWX,NZDCHF.DWX,NZDJPY.DWX,NZDUSD.DWX,SP500.DWX,UK100.DWX,USDCAD.DWX,USDCHF.DWX,USDJPY.DWX,WS30.DWX,XAGUSD.DWX,XAUUSD.DWX,XNGUSD.DWX,XTIUSD.DWX";

int g_last_entry_rebalance_month = 0;
int g_last_exit_rebalance_month = 0;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 100 + dt.mon);
  }

bool InMonthlyRebalanceWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day >= 1 && dt.day <= strategy_rebalance_day_max);
  }

bool SplitUniverse(string &symbols[])
  {
   const int n = StringSplit(strategy_universe_csv, ',', symbols);
   for(int i = 0; i < n; ++i)
      StringTrimLeft(StringTrimRight(symbols[i]));
   return (n > 0);
  }

bool MomentumReturn(const string symbol, double &ret)
  {
   ret = 0.0;
   if(Bars(symbol, PERIOD_D1) < strategy_min_daily_bars)
      return false;

   const double c1 = iClose(symbol, PERIOD_D1, 1);
   const double c0 = iClose(symbol, PERIOD_D1, strategy_momentum_days + 1);
   if(c1 <= 0.0 || c0 <= 0.0)
      return false;

   ret = (c1 / c0) - 1.0;
   return true;
  }

int CurrentMomentumLeg()
  {
   string symbols[];
   if(!SplitUniverse(symbols))
      return 0;

   double current_ret = 0.0;
   if(!MomentumReturn(_Symbol, current_ret))
      return 0;

   int eligible = 0;
   int greater = 0;
   int lesser = 0;

   const int n = ArraySize(symbols);
   for(int i = 0; i < n; ++i)
     {
      double r = 0.0;
      if(!MomentumReturn(symbols[i], r))
         continue;

      ++eligible;
      if(r > current_ret)
         ++greater;
      if(r < current_ret)
         ++lesser;
     }

   if(eligible <= 0)
      return 0;

   const int rank_bucket = (eligible >= strategy_min_universe)
                           ? MathMax(1, eligible / 3)
                           : MathMax(1, strategy_small_universe_rank);

   if(greater < rank_bucket)
      return 1;
   if(lesser < rank_bucket)
      return -1;

   return 0;
  }

bool TrendFilterAllows(const int leg)
  {
   const double sma_fast = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_days, 1);
   const double sma_slow = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_days, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;

   if(leg > 0)
      return (sma_fast > sma_slow);
   if(leg < 0)
      return (sma_fast < sma_slow);

   return false;
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
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

   const datetime now = TimeCurrent();
   if(!InMonthlyRebalanceWindow(now))
      return false;

   const int month_key = MonthKey(now);
   if(month_key == g_last_entry_rebalance_month)
      return false;
   g_last_entry_rebalance_month = month_key;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(SelectOurPosition(existing_type))
      return false;

   const int leg = CurrentMomentumLeg();
   if(leg == 0 || !TrendFilterAllows(leg))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double price = (leg > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || price <= 0.0)
      return false;

   const double stop_dist = atr * strategy_atr_sl_mult;
   if(stop_dist <= 0.0)
      return false;

   req.type = (leg > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = (leg > 0) ? price - stop_dist : price + stop_dist;
   req.tp = 0.0;
   req.reason = (leg > 0) ? "AA_MOM_TOP_SMA50_GT_200" : "AA_MOM_BOTTOM_SMA50_LT_200";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   if(!InMonthlyRebalanceWindow(now))
      return false;

   const int month_key = MonthKey(now);
   if(month_key == g_last_exit_rebalance_month)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectOurPosition(position_type))
     {
      g_last_exit_rebalance_month = month_key;
      return false;
     }

   const int leg = CurrentMomentumLeg();
   const bool keep_long = (position_type == POSITION_TYPE_BUY && leg > 0 && TrendFilterAllows(1));
   const bool keep_short = (position_type == POSITION_TYPE_SELL && leg < 0 && TrendFilterAllows(-1));

   g_last_exit_rebalance_month = month_key;
   if(keep_long || keep_short)
      return false;

   return true;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
