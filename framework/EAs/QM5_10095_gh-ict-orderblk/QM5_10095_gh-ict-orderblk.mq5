#property strict
#property version   "5.0"
#property description "QM5_10095 GitHub ICT Weekly Open Order Block"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10095;
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
input int    strategy_order_block_threshold_pct = 10;
input int    strategy_lookback                  = 24;
input int    strategy_fast_sma                  = 5;
input int    strategy_slow_sma                  = 30;
input int    strategy_daily_body_days           = 5;
input double strategy_h1_range_to_d1_body_max   = 0.80;
input double strategy_tp_body_threshold         = 10.0;
input double strategy_tp_rr_low_body            = 3.0;
input double strategy_tp_rr_high_body           = 4.0;
input int    strategy_weekly_open_lookback_bars = 240;

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_order_block_threshold_pct <= 0 ||
      strategy_lookback < 1 ||
      strategy_fast_sma < 1 ||
      strategy_slow_sma < 1 ||
      strategy_daily_body_days < 1 ||
      strategy_h1_range_to_d1_body_max <= 0.0 ||
      strategy_tp_rr_low_body <= 0.0 ||
      strategy_tp_rr_high_body <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime today;
   TimeToStruct(broker_now, today);
   today.hour = 0;
   today.min = 0;
   today.sec = 0;
   const datetime day_start = StructToTime(today);
   const int today_key = today.year * 10000 + today.mon * 100 + today.day;
   static int s_signal_day_key = 0;
   if(s_signal_day_key == today_key)
      return false;

   if(HistorySelect(day_start, broker_now))
     {
      const int deals_total = HistoryDealsTotal();
      for(int i = 0; i < deals_total; ++i)
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

   int h1_bars_needed = strategy_weekly_open_lookback_bars;
   if(h1_bars_needed < strategy_lookback + 3)
      h1_bars_needed = strategy_lookback + 3;
   if(h1_bars_needed < strategy_slow_sma + strategy_lookback + 2)
      h1_bars_needed = strategy_slow_sma + strategy_lookback + 2;

   MqlRates h1[];
   ArraySetAsSeries(h1, true);
   const int h1_copied = CopyRates(_Symbol, PERIOD_H1, 1, h1_bars_needed, h1); // perf-allowed: closed-bar Strategy_EntrySignal order-block OHLC
   if(h1_copied < strategy_lookback + 2)
      return false;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int d1_copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_daily_body_days, d1); // perf-allowed: closed-bar Strategy_EntrySignal D1 body filter
   if(d1_copied < strategy_daily_body_days)
      return false;

   double avg_daily_body = 0.0;
   for(int d = 0; d < strategy_daily_body_days; ++d)
      avg_daily_body += MathAbs(d1[d].close - d1[d].open);
   avg_daily_body /= strategy_daily_body_days;
   if(avg_daily_body <= 0.0)
      return false;

   const double prev_open = h1[0].open;
   const double prev_high = h1[0].high;
   const double prev_low = h1[0].low;
   const double prev_close = h1[0].close;
   if(prev_open <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || prev_close <= 0.0 || prev_high <= prev_low)
      return false;

   const double h1_range = prev_high - prev_low;
   if(h1_range > avg_daily_body * strategy_h1_range_to_d1_body_max)
      return false;

   MqlDateTime anchor_dt;
   TimeToStruct(h1[0].time, anchor_dt);
   if(anchor_dt.day_of_week == 0)
      return false;
   const int days_since_monday = anchor_dt.day_of_week - 1;
   anchor_dt.hour = 0;
   anchor_dt.min = 0;
   anchor_dt.sec = 0;
   const datetime week_start = StructToTime(anchor_dt) - (datetime)(days_since_monday * 86400);

   double weekly_open = 0.0;
   for(int w = h1_copied - 1; w >= 0; --w)
     {
      if(h1[w].time < week_start)
         continue;
      weekly_open = h1[w].open;
      break;
     }
   if(weekly_open <= 0.0)
      return false;

   const double candle_body_pct = 100.0 * MathAbs(prev_close - prev_open) / h1_range;
   if(candle_body_pct <= (double)strategy_order_block_threshold_pct)
      return false;

   double min_shifted_close = DBL_MAX;
   double max_shifted_close = -DBL_MAX;
   for(int b = 1; b <= strategy_lookback; ++b)
     {
      if(h1[b].close <= 0.0)
         return false;
      if(h1[b].close < min_shifted_close)
         min_shifted_close = h1[b].close;
      if(h1[b].close > max_shifted_close)
         max_shifted_close = h1[b].close;
     }

   bool fast_above_slow = true;
   bool fast_below_slow = true;
   for(int shift = 1; shift <= strategy_lookback; ++shift)
     {
      const double fast = QM_SMA(_Symbol, PERIOD_H1, strategy_fast_sma, shift);
      const double slow = QM_SMA(_Symbol, PERIOD_H1, strategy_slow_sma, shift);
      if(fast <= 0.0 || slow <= 0.0)
         return false;
      if(fast <= slow)
         fast_above_slow = false;
      if(fast >= slow)
         fast_below_slow = false;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double rr = (avg_daily_body >= strategy_tp_body_threshold) ? strategy_tp_rr_high_body : strategy_tp_rr_low_body;

   if(bid > weekly_open &&
      prev_close < prev_open &&
      min_shifted_close >= prev_close &&
      bid >= prev_open &&
      fast_above_slow)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, prev_low);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "ICT_WEEKLY_OPEN_OB_BUY";
      s_signal_day_key = today_key;
      return true;
     }

   if(ask < weekly_open &&
      prev_close > prev_open &&
      max_shifted_close <= prev_close &&
      ask <= prev_open &&
      fast_below_slow)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, prev_high);
      if(req.sl <= 0.0 || req.sl <= bid)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "ICT_WEEKLY_OPEN_OB_SELL";
      s_signal_day_key = today_key;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= point)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved < 2.0 * risk_distance)
         continue;

      const double target_sl = QM_StopRulesNormalizePrice(_Symbol, is_buy ? (open_price + risk_distance)
                                                                          : (open_price - risk_distance));
      if(target_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "ICT_OB_MOVE_SL_AFTER_2R");
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10095_gh-ict-orderblk\"}");
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
