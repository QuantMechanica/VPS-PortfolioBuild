#property strict
#property version   "5.0"
#property description "QM5_11550 Carter M5 EMA50/100 MACD partial"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11550 carter-t-m5-ema50-100-macd-partial
// Strategy Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11550_carter-t-m5-ema50-100-macd-partial.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11550;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period     = 50;
input int    strategy_ema_slow_period     = 100;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_macd_lookback       = 5;
input int    strategy_breakout_pips       = 10;
input int    strategy_sl_struct_bars      = 5;
input int    strategy_sl_cap_pips         = 30;
input double strategy_partial_rr          = 2.0;
input double strategy_partial_fraction    = 0.5;
input int    strategy_exit_break_pips     = 10;
input bool   strategy_no_friday_entry     = true;
input int    strategy_spread_cap_pips     = 5;

// Return TRUE to BLOCK trading this tick. The card's spread filter is enforced
// here and intentionally fail-opens on zero modeled .DWX spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   const double spread = ask - bid;
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double close1 = QM_EMA(_Symbol, _Period, 1, 1);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 || offset <= 0.0)
      return false;

   const bool long_state = (close1 > ema_fast && close1 > ema_slow && (close1 - ema_fast) >= offset);
   const bool short_state = (close1 < ema_fast && close1 < ema_slow && (ema_fast - close1) >= offset);
   if(!long_state && !short_state)
      return false;

   bool macd_cross = false;
   for(int shift = 1; shift <= strategy_macd_lookback; ++shift)
     {
      const double macd_now = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, shift);
      const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, shift + 1);
      if(long_state && macd_prev < 0.0 && macd_now > 0.0)
        {
         macd_cross = true;
         break;
        }
      if(short_state && macd_prev > 0.0 && macd_now < 0.0)
        {
         macd_cross = true;
         break;
        }
     }
   if(!macd_cross)
      return false;

   const QM_OrderType side = long_state ? QM_BUY : QM_SELL;
   const double entry = long_state ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_struct_bars);
   const double max_risk = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(sl <= 0.0 || max_risk <= 0.0)
      return false;

   double risk = long_state ? (entry - sl) : (sl - entry);
   if(risk <= 0.0)
      return false;
   if(risk > max_risk)
     {
      sl = long_state ? (entry - max_risk) : (entry + max_risk);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
     }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = long_state ? "ema_macd_long" : "ema_macd_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Partial exit uses the current protective SL as the initial 1R reference; once
// SL is at break-even or better, the partial is considered complete.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      if(is_buy && current_sl >= open_price - point * 0.5)
         continue;
      if(!is_buy && current_sl <= open_price + point * 0.5)
         continue;

      const double one_r = MathAbs(open_price - current_sl);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(one_r <= 0.0 || market <= 0.0)
         continue;

      const double favorable = is_buy ? (market - open_price) : (open_price - market);
      if(favorable < one_r * strategy_partial_rr)
         continue;

      const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_fraction);
      if(close_lots > 0.0 && QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "partial_exit_breakeven");
     }
  }

// Return TRUE to close the open position now. This is the EMA(50) break exit for
// the remainder, and also protects a full position if the break happens first.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = QM_EMA(_Symbol, _Period, 1, 1);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_exit_break_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || offset <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 <= ema_fast - offset)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 >= ema_fast + offset)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless of
// framework news mode. This EA has no card-specific news override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
