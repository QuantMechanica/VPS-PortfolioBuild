#property strict
#property version   "5.0"
#property description "QM5_11734 tc-m5-s18-ema20-macd-cross"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11734 tc-m5-s18-ema20-macd-cross
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\
//       QM5_11734_tc-m5-s18-ema20-macd-cross.md
// Strategy: EMA(20) price cross with MACD(12,26,9) cross confirmation.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11734;
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
input int    strategy_ema_period          = 20;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_macd_cross_lookback = 5;
input int    strategy_entry_buffer_pips   = 10;
input int    strategy_sl_from_ema_pips    = 20;
input int    strategy_trail_from_ema_pips = 15;
input double strategy_partial_rr          = 2.0;
input double strategy_partial_fraction    = 0.50;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No card-level session or spread filter. Time/news are handled by framework
// wiring; Strategy_NewsFilterHook defers to the central news filter.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
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
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return false;
     }

   const int price_prev = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 2);
   const int price_now  = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 1);
   const bool price_cross_up = (price_prev < 0 && price_now > 0);
   const bool price_cross_dn = (price_prev > 0 && price_now < 0);
   if(!price_cross_up && !price_cross_dn)
      return false;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema_now <= 0.0)
      return false;

   const double macd_main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_prev = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                               strategy_macd_slow, strategy_macd_signal, 2);

   bool macd_cross_up = false;
   bool macd_cross_dn = false;
   const int lookback = MathMax(1, strategy_macd_cross_lookback);
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double main_now = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, shift);
      const double sig_now = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, shift);
      const double main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, shift + 1);
      const double sig_prev = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                             strategy_macd_slow, strategy_macd_signal, shift + 1);
      if(main_now > sig_now && main_prev <= sig_prev)
         macd_cross_up = true;
      if(main_now < sig_now && main_prev >= sig_prev)
         macd_cross_dn = true;
     }

   const double entry_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   const double stop_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_from_ema_pips);
   if(entry_buffer <= 0.0 || stop_buffer <= 0.0)
      return false;

   if(price_cross_up && macd_main_prev < 0.0 && macd_sig_prev < 0.0 && macd_cross_up)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_now + entry_buffer);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || ask <= 0.0 || entry <= ask)
         return false;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ema_now - stop_buffer);
      req.tp = 0.0;
      req.reason = "ema20_macd_cross_buy_stop";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(price_cross_dn && macd_main_prev > 0.0 && macd_sig_prev > 0.0 && macd_cross_dn)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, ema_now - entry_buffer);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || bid <= 0.0 || entry >= bid)
         return false;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ema_now + stop_buffer);
      req.tp = 0.0;
      req.reason = "ema20_macd_cross_sell_stop";
      return (req.sl > req.price);
     }

   return false;
  }

// Partial exit at 2R, then trail the remaining position at EMA20 +/- 15 pips.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double trail_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_from_ema_pips);
   if(ema_now <= 0.0 || trail_buffer <= 0.0)
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || cur_sl <= 0.0 || volume <= 0.0 || market_price <= 0.0)
         continue;

      const string partial_key = StringFormat("QM5_11734_partial_%I64u", ticket);
      bool partial_done = GlobalVariableCheck(partial_key);
      const double risk_distance = MathAbs(open_price - cur_sl);
      const double profit_distance = is_buy ? (market_price - open_price)
                                            : (open_price - market_price);

      if(!partial_done && risk_distance > 0.0 &&
         profit_distance >= strategy_partial_rr * risk_distance)
        {
         const double requested = volume * strategy_partial_fraction;
         const double close_lots = QM_TM_NormalizeVolume(_Symbol, requested);
         if(close_lots > 0.0 && close_lots < volume)
           {
            if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
              {
               GlobalVariableSet(partial_key, 1.0);
               partial_done = true;
              }
           }
         else
           {
            GlobalVariableSet(partial_key, 1.0);
            partial_done = true;
           }
        }

      if(!partial_done)
         continue;

      if(is_buy)
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, ema_now - trail_buffer);
         if(trail_sl > 0.0 && trail_sl < market_price &&
            (cur_sl <= 0.0 || trail_sl > cur_sl))
            QM_TM_MoveSL(ticket, trail_sl, "ema20_partial_remainder_trail_long");
        }
      else
        {
         const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, ema_now + trail_buffer);
         if(trail_sl > 0.0 && trail_sl > market_price &&
            (cur_sl <= 0.0 || trail_sl < cur_sl))
            QM_TM_MoveSL(ticket, trail_sl, "ema20_partial_remainder_trail_short");
        }
     }
  }

// Close on opposite price/EMA20 cross. SL/trailing and Friday close are handled
// elsewhere by the framework and trade-management hook.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int price_prev = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 2);
   const int price_now = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_period, 0.0, 1);
   const bool cross_up = (price_prev < 0 && price_now > 0);
   const bool cross_dn = (price_prev > 0 && price_now < 0);
   if(!cross_up && !cross_dn)
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && cross_dn)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cross_up)
         return true;
     }

   return false;
  }

// Defer to the central framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
