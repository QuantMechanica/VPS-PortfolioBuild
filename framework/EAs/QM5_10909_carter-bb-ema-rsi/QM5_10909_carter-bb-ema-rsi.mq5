#property strict
#property version   "5.0"
#property description "QM5_10909 Carter Bollinger-Middle EMA RSI MACD breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10909 carter-bb-ema-rsi
// Strategy Card: artifacts/cards_approved/QM5_10909_carter-bb-ema-rsi.md
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #8, pages 18-19.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10909;
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
input int    InpBBPeriod          = 20;
input double InpBBDeviation       = 3.0;
input int    InpEMAPeriod         = 3;
input int    InpMACDFast          = 6;
input int    InpMACDSlow          = 17;
input int    InpMACDSignal        = 1;
input int    InpRSIPeriod         = 14;
input double InpRSIMidline        = 50.0;
input int    InpSignalWindowBars  = 3;
input int    InpTPFixedPips       = 50;
input int    InpSLBufferPips      = 5;
input int    InpStructLookback    = 10;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Card authorizes only default V5 spread/session/news filters.
   // Duplicate entries are rejected by QM_Entry for this magic+symbol.
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

   if(InpBBPeriod <= 0 || InpEMAPeriod <= 0 || InpMACDFast <= 0 ||
      InpMACDSlow <= 0 || InpMACDSignal <= 0 || InpRSIPeriod <= 0 ||
      InpSignalWindowBars <= 0 || InpTPFixedPips <= 0 ||
      InpSLBufferPips <= 0 || InpStructLookback <= 0)
      return false;

   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   bool ema_cross_up = false;
   bool ema_cross_down = false;
   bool macd_cross_up = false;
   bool macd_cross_down = false;
   bool rsi_cross_up = false;
   bool rsi_cross_down = false;

   for(int shift = 1; shift <= InpSignalWindowBars; ++shift)
     {
      const double ema_now = QM_EMA(sym, tf, InpEMAPeriod, shift);
      const double ema_prev = QM_EMA(sym, tf, InpEMAPeriod, shift + 1);
      const double mid_now = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, shift);
      const double mid_prev = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, shift + 1);
      if(ema_now == 0.0 || ema_prev == 0.0 || mid_now == 0.0 || mid_prev == 0.0)
         return false;

      if(ema_prev <= mid_prev && ema_now > mid_now)
         ema_cross_up = true;
      if(ema_prev >= mid_prev && ema_now < mid_now)
         ema_cross_down = true;

      const double macd_now = QM_MACD_Main(sym, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, shift);
      const double macd_prev = QM_MACD_Main(sym, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, shift + 1);
      if(macd_prev <= 0.0 && macd_now > 0.0)
         macd_cross_up = true;
      if(macd_prev >= 0.0 && macd_now < 0.0)
         macd_cross_down = true;

      const double rsi_now = QM_RSI(sym, tf, InpRSIPeriod, shift);
      const double rsi_prev = QM_RSI(sym, tf, InpRSIPeriod, shift + 1);
      if(rsi_now == 0.0 || rsi_prev == 0.0)
         return false;
      if(rsi_prev <= InpRSIMidline && rsi_now > InpRSIMidline)
         rsi_cross_up = true;
      if(rsi_prev >= InpRSIMidline && rsi_now < InpRSIMidline)
         rsi_cross_down = true;
     }

   const double ema_1 = QM_EMA(sym, tf, InpEMAPeriod, 1);
   const double mid_1 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double macd_1 = QM_MACD_Main(sym, tf, InpMACDFast, InpMACDSlow, InpMACDSignal, 1);
   const double rsi_1 = QM_RSI(sym, tf, InpRSIPeriod, 1);
   const double bb_upper = QM_BB_Upper(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double bb_lower = QM_BB_Lower(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   if(ema_1 == 0.0 || mid_1 == 0.0 || rsi_1 == 0.0 ||
      bb_upper == 0.0 || bb_lower == 0.0)
      return false;

   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(sym, InpSLBufferPips);
   if(buffer <= 0.0)
      return false;

   if(ema_cross_up && macd_cross_up && rsi_cross_up &&
      ema_1 > mid_1 && macd_1 > 0.0 && rsi_1 > InpRSIMidline)
     {
      const double entry = ask;
      double sl_ref = 0.0;
      const double struct_sl = QM_StopStructure(sym, QM_BUY, entry, InpStructLookback);
      if(bb_lower > 0.0 && bb_lower < entry)
         sl_ref = bb_lower;
      if(struct_sl > 0.0 && struct_sl < entry && (sl_ref == 0.0 || struct_sl > sl_ref))
         sl_ref = struct_sl;
      if(sl_ref <= 0.0)
         return false;

      const double fixed_tp = QM_TakeFixedPips(sym, QM_BUY, entry, InpTPFixedPips);
      double tp = fixed_tp;
      if(bb_upper > entry && (tp == 0.0 || bb_upper < tp))
         tp = bb_upper;
      if(tp <= entry)
         return false;

      req.type = QM_BUY;
      req.sl = QM_TM_NormalizePrice(sym, sl_ref - buffer);
      req.tp = QM_TM_NormalizePrice(sym, tp);
      req.reason = "carter_bb_ema_rsi_macd_long";
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   if(ema_cross_down && macd_cross_down && rsi_cross_down &&
      ema_1 < mid_1 && macd_1 < 0.0 && rsi_1 < InpRSIMidline)
     {
      const double entry = bid;
      double sl_ref = 0.0;
      const double struct_sl = QM_StopStructure(sym, QM_SELL, entry, InpStructLookback);
      if(bb_upper > entry)
         sl_ref = bb_upper;
      if(struct_sl > entry && (sl_ref == 0.0 || struct_sl < sl_ref))
         sl_ref = struct_sl;
      if(sl_ref <= 0.0)
         return false;

      const double fixed_tp = QM_TakeFixedPips(sym, QM_SELL, entry, InpTPFixedPips);
      double tp = fixed_tp;
      if(bb_lower < entry && (tp == 0.0 || bb_lower > tp))
         tp = bb_lower;
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.sl = QM_TM_NormalizePrice(sym, sl_ref + buffer);
      req.tp = QM_TM_NormalizePrice(sym, tp);
      req.reason = "carter_bb_ema_rsi_macd_short";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or add-on.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_1 = QM_EMA(sym, tf, InpEMAPeriod, 1);
   const double ema_2 = QM_EMA(sym, tf, InpEMAPeriod, 2);
   const double mid_1 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 1);
   const double mid_2 = QM_BB_Middle(sym, tf, InpBBPeriod, InpBBDeviation, 2);
   if(ema_1 == 0.0 || ema_2 == 0.0 || mid_1 == 0.0 || mid_2 == 0.0)
      return false;

   const bool cross_up = (ema_2 <= mid_2 && ema_1 > mid_1);
   const bool cross_down = (ema_2 >= mid_2 && ema_1 < mid_1);
   if(!cross_up && !cross_down)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
     }

   return false;
  }

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
