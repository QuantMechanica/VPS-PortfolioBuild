#property strict
#property version   "5.0"
#property description "QM5_11478 Williams Smash Day Reversal D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11478;
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
input double strategy_close_half_threshold = 0.50;
input double strategy_entry_offset_pips    = 1.0;
input double strategy_tp_range_mult        = 1.50;
input int    strategy_time_stop_bars       = 3;
input double strategy_max_sl_pips          = 80.0;
input double strategy_spread_cap_pips      = 25.0;
input bool   strategy_use_atr_filter       = false;
input int    strategy_atr_period           = 14;
input double strategy_atr_range_mult       = 1.20;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(StringFind(_Symbol, "JPY") >= 0)
      return 0.01;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurPendingStop()
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

bool Strategy_IsFridayNow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

// No Trade Filter: D1 timeframe and spread cap. News and Friday close are
// handled by the framework; no-Friday-entry is applied inside Trade Entry.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_spread_cap_pips <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   return ((ask - bid) / pip > strategy_spread_cap_pips);
  }

// Trade Entry: Williams Smash Day reversal. A bullish-looking D1 bar that
// closes in its lower half places a next-bar sell stop below its low; the
// mirrored bearish-looking bar places a buy stop above its high.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_close_half_threshold <= 0.0 || strategy_close_half_threshold >= 1.0 ||
      strategy_entry_offset_pips <= 0.0 ||
      strategy_tp_range_mult <= 0.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_max_sl_pips <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_range_mult <= 0.0)
      return false;

   if(Strategy_IsFridayNow() || Strategy_HasOurPosition() || Strategy_HasOurPendingStop())
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, 3, rates); // perf-allowed: fixed three-bar D1 OHLC structure, called only from the framework new-bar gate.
   if(copied < 3)
      return false;

   const MqlRates smash = rates[1];
   const MqlRates prior = rates[2];
   const double range = smash.high - smash.low;
   if(smash.high <= 0.0 || smash.low <= 0.0 || smash.close <= 0.0 ||
      prior.high <= 0.0 || prior.low <= 0.0 || prior.close <= 0.0 ||
      range <= 0.0)
      return false;

   if(strategy_use_atr_filter)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr <= 0.0 || range <= atr * strategy_atr_range_mult)
         return false;
     }

   const double offset = strategy_entry_offset_pips * pip;
   const double max_sl_distance = strategy_max_sl_pips * pip;
   int expiry = PeriodSeconds(PERIOD_D1);
   if(expiry <= 0)
      expiry = 86400;

   const bool bearish_smash = (smash.high > prior.high &&
                               smash.low > prior.low &&
                               smash.close > prior.close &&
                               (smash.close - smash.low) < strategy_close_half_threshold * range);
   if(bearish_smash)
     {
      const double entry = smash.low - offset;
      double sl = smash.high + offset;
      if(sl - entry > max_sl_distance)
         sl = entry + max_sl_distance;
      const double tp = entry - strategy_tp_range_mult * range;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "QM5_11478_BEARISH_SMASH_SELL_STOP";
      req.expiration_seconds = expiry;
      return (req.price > 0.0 && req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
     }

   const bool bullish_smash = (smash.high < prior.high &&
                               smash.low < prior.low &&
                               smash.close < prior.close &&
                               (smash.high - smash.close) < strategy_close_half_threshold * range);
   if(bullish_smash)
     {
      const double entry = smash.high + offset;
      double sl = smash.low - offset;
      if(entry - sl > max_sl_distance)
         sl = entry - max_sl_distance;
      const double tp = entry + strategy_tp_range_mult * range;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "QM5_11478_BULLISH_SMASH_BUY_STOP";
      req.expiration_seconds = expiry;
      return (req.price > 0.0 && req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
     }

   return false;
  }

// Trade Management: pending stops are valid for one D1 bar; broker expiration
// handles normal cleanup and this removes stale orders defensively.
void Strategy_ManageOpenPosition()
  {
   int expiry = PeriodSeconds(PERIOD_D1);
   if(expiry <= 0)
      expiry = 86400;

   const datetime now = TimeCurrent();
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
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry)
         QM_TM_RemovePendingOrder(ticket, "QM5_11478_PENDING_ONE_BAR_EXPIRED");
     }
  }

// Trade Close: close after three D1 bars if SL/TP has not already resolved
// the position. Framework Friday close remains active.
bool Strategy_ExitSignal()
  {
   int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_D1);
   if(hold_seconds <= 0)
      hold_seconds = strategy_time_stop_bars * 86400;

   const datetime now = TimeCurrent();
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
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

// News Filter Hook: no strategy-specific news override beyond framework news.
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
