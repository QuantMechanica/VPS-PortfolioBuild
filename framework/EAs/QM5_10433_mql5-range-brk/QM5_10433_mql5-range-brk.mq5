#property strict
#property version   "5.0"
#property description "QM5_10433 MQL5 Easy Range Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10433;
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
input int    strategy_range_start_hour      = 8;
input int    strategy_range_end_hour        = 9;
input int    strategy_session_close_hour    = 22;
input int    strategy_atr_period            = 14;
input double strategy_min_range_atr_mult    = 0.25;
input double strategy_max_range_atr_mult    = 3.0;
input double strategy_max_spread_range_frac = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved Strategy Card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): central framework handles news/Friday.
// Strategy time and spread checks stay in entry so exits remain live.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: daily 08:00-09:00 broker-time M1 range, then M5 close breakout.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M5)
      return false;
   if(strategy_atr_period <= 0 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_max_range_atr_mult <= 0.0 ||
      strategy_max_range_atr_mult < strategy_min_range_atr_mult ||
      strategy_max_spread_range_frac <= 0.0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour < strategy_range_end_hour || now_dt.hour >= strategy_session_close_hour)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlDateTime day_dt = now_dt;
   day_dt.hour = 0;
   day_dt.min = 0;
   day_dt.sec = 0;
   const datetime day_start = StructToTime(day_dt);
   if(HistorySelect(day_start, TimeCurrent()))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         const ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            return false;
        }
     }

   MqlDateTime range_start_dt = day_dt;
   range_start_dt.hour = MathMax(0, MathMin(23, strategy_range_start_hour));
   const datetime range_start = StructToTime(range_start_dt);

   MqlDateTime range_end_dt = day_dt;
   range_end_dt.hour = MathMax(0, MathMin(23, strategy_range_end_hour));
   const datetime range_end = StructToTime(range_end_dt);
   if(range_end <= range_start || TimeCurrent() <= range_end)
      return false;

   MqlRates range_bars[];
   ArraySetAsSeries(range_bars, false);
   const int copied = CopyRates(_Symbol, PERIOD_M1, range_start, range_end - 1, range_bars);
   if(copied <= 0)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(range_bars[i].high <= 0.0 || range_bars[i].low <= 0.0 || range_bars[i].high <= range_bars[i].low)
         continue;
      if(range_high <= 0.0 || range_bars[i].high > range_high)
         range_high = range_bars[i].high;
      if(range_low <= 0.0 || range_bars[i].low < range_low)
         range_low = range_bars[i].low;
     }
   if(range_high <= range_low || range_low <= 0.0)
      return false;

   const double range_width = range_high - range_low;
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if(range_width < strategy_min_range_atr_mult * atr ||
      range_width > strategy_max_range_atr_mult * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > strategy_max_spread_range_frac * range_width)
      return false;

   const double close_last = iClose(_Symbol, PERIOD_M5, 1);
   if(close_last <= 0.0)
      return false;

   if(close_last > range_high)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_TM_NormalizePrice(_Symbol, range_low);
      req.tp = QM_TM_NormalizePrice(_Symbol, ask + range_width);
      req.reason = "QM5_10433_RANGE_BREAKOUT_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(close_last < range_low)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_TM_NormalizePrice(_Symbol, range_high);
      req.tp = QM_TM_NormalizePrice(_Symbol, bid - range_width);
      req.reason = "QM5_10433_RANGE_BREAKOUT_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Trade Management: the card specifies fixed SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close any remaining position at configured session close.
bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_close_hour)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// News Filter Hook: central FW1 news filter handles configured blackout rules.
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
