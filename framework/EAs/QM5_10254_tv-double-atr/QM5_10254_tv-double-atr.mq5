#property strict
#property version   "5.0"
#property description "QM5_10254 TradingView Double ATR Reversal"

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
input int    qm_ea_id                   = 10254;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_CURRENT;
input int             strategy_atr_period         = 14;
input double          strategy_atr_stop_mult      = 2.0;
input double          strategy_catastrophic_mult  = 5.0;
input int             strategy_warmup_bars        = 120;

int    g_atr_stop_dir = 0;       // 1 bull mode, -1 bear mode.
double g_atr_stop = 0.0;
double g_latest_atr = 0.0;
bool   g_stop_state_ready = false;

ENUM_TIMEFRAMES Strategy_TF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

double Strategy_Close(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return QM_SMA(_Symbol, tf, 1, shift, PRICE_CLOSE);
  }

bool Strategy_FindOpenPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }

   return false;
  }

int Strategy_AdvanceStopForShift(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double close_price = Strategy_Close(tf, shift);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, shift);
   if(close_price <= 0.0 || atr <= 0.0)
      return 0;

   g_latest_atr = atr;

   if(!g_stop_state_ready)
     {
      const double older_close = Strategy_Close(tf, shift + 1);
      g_atr_stop_dir = (older_close > 0.0 && close_price < older_close) ? -1 : 1;
      g_atr_stop = (g_atr_stop_dir > 0)
                   ? close_price - strategy_atr_stop_mult * atr
                   : close_price + strategy_atr_stop_mult * atr;
      g_stop_state_ready = (g_atr_stop > 0.0);
      return 0;
     }

   int signal = 0;
   if(g_atr_stop_dir > 0)
     {
      const double active_stop = MathMax(g_atr_stop, close_price - strategy_atr_stop_mult * atr);
      if(close_price < active_stop)
        {
         g_atr_stop_dir = -1;
         g_atr_stop = close_price + strategy_atr_stop_mult * atr;
         signal = -1;
        }
      else
         g_atr_stop = active_stop;
     }
   else
     {
      const double active_stop = MathMin(g_atr_stop, close_price + strategy_atr_stop_mult * atr);
      if(close_price > active_stop)
        {
         g_atr_stop_dir = 1;
         g_atr_stop = close_price - strategy_atr_stop_mult * atr;
         signal = 1;
        }
      else
         g_atr_stop = active_stop;
     }

   return signal;
  }

bool Strategy_RefreshStopState(int &signal_dir)
  {
   signal_dir = 0;
   if(strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_catastrophic_mult <= 0.0 ||
      strategy_warmup_bars < strategy_atr_period + 2)
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_TF();
   if(!g_stop_state_ready)
     {
      const int warmup = MathMax(strategy_warmup_bars, strategy_atr_period + 5);
      for(int shift = warmup; shift >= 1; --shift)
        {
         const int s = Strategy_AdvanceStopForShift(tf, shift);
         if(shift == 1)
            signal_dir = s;
        }
      return g_stop_state_ready;
     }

   signal_dir = Strategy_AdvanceStopForShift(tf, 1);
   return g_stop_state_ready;
  }

double Strategy_InitialStop(const QM_OrderType side, const double entry_price)
  {
   if(entry_price <= 0.0 || g_latest_atr <= 0.0 || g_atr_stop <= 0.0)
      return 0.0;

   double stop_price = g_atr_stop;
   if(QM_OrderTypeIsBuy(side))
     {
      const double catastrophic = entry_price - strategy_catastrophic_mult * g_latest_atr;
      if(stop_price <= 0.0 || stop_price >= entry_price)
         stop_price = catastrophic;
      else if(catastrophic > stop_price)
         stop_price = catastrophic;
     }
   else
     {
      const double catastrophic = entry_price + strategy_catastrophic_mult * g_latest_atr;
      if(stop_price <= entry_price)
         stop_price = catastrophic;
      else if(catastrophic < stop_price)
         stop_price = catastrophic;
     }

   return QM_StopRulesNormalizePrice(_Symbol, stop_price);
  }

// No Trade Filter (time, spread, news): the card adds no session or spread
// filter beyond the central V5 kill-switch, news, and Friday-close guards.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: enter or reverse at the next bar open after a confirmed close
// flips through the active ratcheting 2xATR stop.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int signal_dir = 0;
   if(!Strategy_RefreshStopState(signal_dir) || signal_dir == 0)
      return false;

   ENUM_POSITION_TYPE open_type;
   ulong open_ticket = 0;
   if(Strategy_FindOpenPosition(open_type, open_ticket))
     {
      const int open_dir = (open_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(open_dir == signal_dir)
         return false;
      if(!QM_TM_ClosePosition(open_ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   req.type = (signal_dir > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry_price <= 0.0 || point <= 0.0)
      return false;

   req.sl = Strategy_InitialStop(req.type, entry_price);
   req.tp = 0.0;
   req.reason = (signal_dir > 0) ? "DOUBLE_ATR_LONG_FLIP" : "DOUBLE_ATR_SHORT_FLIP";

   const double sl_points = MathAbs(entry_price - req.sl) / point;
   if(req.sl <= 0.0 || sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   return true;
  }

// Trade Management: keep the broker SL ratcheted to the active Double ATR stop
// after the position has opened.
void Strategy_ManageOpenPosition()
  {
   if(!g_stop_state_ready || g_atr_stop <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double new_sl = QM_StopRulesNormalizePrice(_Symbol, g_atr_stop);

      if(type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(new_sl > 0.0 && bid > new_sl &&
            (current_sl <= 0.0 || new_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "double_atr_ratchet");
        }
      else if(type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(new_sl > 0.0 && ask < new_sl &&
            (current_sl <= 0.0 || new_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, new_sl, "double_atr_ratchet");
        }
     }
  }

// Trade Close: opposite stop flips are closed and reversed inside Trade Entry
// at the framework-gated next bar open.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no card-specific override; central V5 news filtering
// remains callable for P8 News Impact phase.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10254\",\"ea\":\"tv-double-atr\"}");
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
