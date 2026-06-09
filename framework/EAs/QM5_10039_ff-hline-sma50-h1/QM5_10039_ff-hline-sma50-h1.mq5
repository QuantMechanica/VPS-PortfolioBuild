#property strict
#property version   "5.0"
#property description "QM5_10039 ForexFactory Horizontal Line SMA50 H1"

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
input int    qm_ea_id                   = 10039;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period          = 50;
input int    strategy_grid_pips           = 25;
input int    strategy_entry_offset_pips   = 3;
input int    strategy_grid_sma_min_pips   = 10;
input int    strategy_opposite_min_pips   = 5;
input int    strategy_sl_pips             = 30;
input int    strategy_tp_pips             = 50;
input double strategy_be_trigger_pips     = 12.5;
input double strategy_be_buffer_pips      = 1.0;
input int    strategy_pending_bars        = 3;
input int    strategy_time_stop_bars      = 10;
input double strategy_max_spread_sl_frac  = 0.10;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(StringFind(_Symbol, "JPY") >= 0)
      return 0.01;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double pip = Strategy_PipSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double stop_distance = strategy_sl_pips * pip;
   if(stop_distance <= 0.0)
      return false;

   return ((ask - bid) <= stop_distance * strategy_max_spread_sl_frac);
  }

double Strategy_NextGridAbove(const double price, const double grid_step)
  {
   if(price <= 0.0 || grid_step <= 0.0)
      return 0.0;
   double level = MathCeil(price / grid_step) * grid_step;
   if(level <= price)
      level += grid_step;
   return QM_TM_NormalizePrice(_Symbol, level);
  }

double Strategy_NextGridBelow(const double price, const double grid_step)
  {
   if(price <= 0.0 || grid_step <= 0.0)
      return 0.0;
   double level = MathFloor(price / grid_step) * grid_step;
   if(level >= price)
      level -= grid_step;
   return QM_TM_NormalizePrice(_Symbol, level);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_period <= 0 || strategy_grid_pips <= 0 ||
      strategy_entry_offset_pips <= 0 || strategy_sl_pips <= 0 ||
      strategy_tp_pips <= 0 || strategy_pending_bars <= 0)
      return false;

   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: one closed H1 close anchors the card-defined quarter-pip grid; no QM close reader exists.
   const double sma50 = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1);
   if(close1 <= 0.0 || sma50 <= 0.0 || close1 == sma50)
      return false;

   const double grid_step = strategy_grid_pips * pip;
   const double entry_offset = strategy_entry_offset_pips * pip;
   const double min_sma_distance = strategy_grid_sma_min_pips * pip;
   const double min_opposite_distance = strategy_opposite_min_pips * pip;
   if(grid_step <= 0.0 || entry_offset <= 0.0 ||
      min_sma_distance <= 0.0 || min_opposite_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > sma50)
     {
      const double anchor = MathMax(close1, sma50);
      const double level = Strategy_NextGridAbove(anchor, grid_step);
      const double opposite = Strategy_NextGridBelow(close1, grid_step);
      if(level <= 0.0 || opposite <= 0.0)
         return false;
      if(MathAbs(level - sma50) < min_sma_distance)
         return false;
      if(MathAbs(close1 - opposite) < min_opposite_distance)
         return false;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, level + entry_offset);
      if(req.price <= ask)
         return false;
      req.sl = QM_StopFixedPips(_Symbol, req.type, req.price, strategy_sl_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, req.price, strategy_tp_pips);
      req.reason = "QM5_10039_HLINE_SMA50_LONG";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(PERIOD_H1);
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close1 < sma50)
     {
      const double anchor = MathMin(close1, sma50);
      const double level = Strategy_NextGridBelow(anchor, grid_step);
      const double opposite = Strategy_NextGridAbove(close1, grid_step);
      if(level <= 0.0 || opposite <= 0.0)
         return false;
      if(MathAbs(level - sma50) < min_sma_distance)
         return false;
      if(MathAbs(close1 - opposite) < min_opposite_distance)
         return false;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, level - entry_offset);
      if(req.price >= bid)
         return false;
      req.sl = QM_StopFixedPips(_Symbol, req.type, req.price, strategy_sl_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, req.price, strategy_tp_pips);
      req.reason = "QM5_10039_HLINE_SMA50_SHORT";
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(PERIOD_H1);
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_be_trigger_pips <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_be_trigger_pips * pip)
         continue;

      const double target_sl = QM_TM_NormalizePrice(_Symbol,
                            is_buy ? (open_price + strategy_be_buffer_pips * pip)
                                   : (open_price - strategy_be_buffer_pips * pip));
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "QM5_10039_BE_12_5_PIPS");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_H1);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && now - open_time >= hold_seconds)
         return true;
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
