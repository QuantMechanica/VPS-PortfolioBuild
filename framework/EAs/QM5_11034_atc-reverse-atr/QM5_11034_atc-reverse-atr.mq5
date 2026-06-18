#property strict
#property version   "5.0"
#property description "QM5_11034 ATC reverse ATR"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11034;
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
input int    strategy_initial_direction       = 1;     // 1=long, -1=short.
input int    strategy_atr_period              = 14;
input double strategy_atr_trail_mult          = 2.0;
input double strategy_hard_sl_atr             = 3.0;
input int    strategy_cooldown_bars           = 0;
input int    strategy_min_atr_percentile      = 0;     // 0=disabled; card variants: 30, 50.
input int    strategy_atr_percentile_lookback = 250;
input int    strategy_median_spread_points    = 20;
input double strategy_max_spread_median_mult  = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Time filter: the card defines no session window, so time does not block.
   // Spread filter: DWX can model zero spread; zero never blocks.
   if(strategy_median_spread_points > 0 && strategy_max_spread_median_mult > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const long max_spread = (long)MathRound((double)strategy_median_spread_points * strategy_max_spread_median_mult);
      if(spread_points > 0 && spread_points > max_spread)
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   int last_closed_direction = 0;
   datetime last_close_time = 0;
   if(HistorySelect(0, TimeCurrent()))
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

         const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
            continue;

         const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
         if(deal_type == DEAL_TYPE_SELL)
            last_closed_direction = 1;
         else if(deal_type == DEAL_TYPE_BUY)
            last_closed_direction = -1;
         else
            continue;

         last_close_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         break;
        }
     }

   if(last_close_time > 0 && strategy_cooldown_bars > 0)
     {
      const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(seconds_per_bar <= 0)
         return false;
      const int bars_since_close = (int)((TimeCurrent() - last_close_time) / seconds_per_bar);
      if(bars_since_close < strategy_cooldown_bars)
         return false;
     }

   if(strategy_min_atr_percentile > 0)
     {
      if(strategy_atr_period <= 0 || strategy_atr_percentile_lookback <= 0)
         return false;

      const double current_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(current_atr <= 0.0)
         return false;

      int samples = 0;
      int below_or_equal = 0;
      for(int shift = 2; shift <= strategy_atr_percentile_lookback + 1; ++shift)
        {
         const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
         if(atr <= 0.0)
            continue;
         ++samples;
         if(atr <= current_atr)
            ++below_or_equal;
        }

      if(samples <= 0)
         return false;

      const double percentile = 100.0 * (double)below_or_equal / (double)samples;
      if(percentile < (double)strategy_min_atr_percentile)
         return false;
     }

   int next_direction = (strategy_initial_direction >= 0) ? 1 : -1;
   if(last_closed_direction != 0)
      next_direction = -last_closed_direction;

   req.type = (next_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || strategy_atr_period <= 0 || strategy_hard_sl_atr <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_hard_sl_atr);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (next_direction > 0) ? "ATC_REVERSE_ATR_LONG" : "ATC_REVERSE_ATR_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_atr_period <= 0 || strategy_atr_trail_mult <= 0.0)
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

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   // Card exits through hard SL, ATR trailing stop, and framework Friday close only.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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
