#property strict
#property version   "5.0"
#property description "QM5_33004 Kevin Davey 3-Bar Momentum Expansion"

#include <QM/QM_Common.mqh>

// Mechanical implementation of the OWNER-approved QM5_33004 Strategy Card.
// Signal math is evaluated on closed H1 bars. Raw rate access is bounded to
// the card-authorized 2-5 bar structural setup and occurs only after the
// framework's QM_IsNewBar() gate.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 33004;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_setup_bars             = 3;
input int    strategy_atr_period              = 14;
input double strategy_atr_trail_mult          = 2.50;
input double strategy_reward_r                = 2.50;
input int    strategy_entry_offset_ticks      = 1;
input int    strategy_pending_expiry_bars     = 1;
input int    strategy_max_hold_bars           = 96;
input double strategy_max_spread_atr          = 1.80;
input double strategy_daily_loss_limit_pct    = 2.00;

// Return TRUE to block new entries. The framework independently enforces its
// global kill switch, news controls, and Friday close.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   if(strategy_setup_bars < 2 || strategy_setup_bars > 5 ||
      strategy_atr_period < 1 || strategy_atr_trail_mult <= 0.0 ||
      strategy_reward_r <= 0.0 || strategy_entry_offset_ticks < 1 ||
      strategy_pending_expiry_bars < 1 || strategy_max_hold_bars < 1 ||
      strategy_max_spread_atr <= 0.0 || strategy_daily_loss_limit_pct <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // .DWX tester spreads can legitimately be zero. Only a genuinely positive,
   // over-cap spread blocks entry.
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > strategy_max_spread_atr * atr)
      return true;

   // Card rollover window is stated in GMT/UTC, not broker time.
   MqlDateTime utc_parts;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc_parts);
   if((utc_parts.hour == 23 && utc_parts.min >= 55) ||
      (utc_parts.hour == 0 && utc_parts.min <= 5))
      return true;

   // The central kill-switch maintains the broker-day equity anchor. Balance
   // is used here so this card-specific 2% entry halt responds to realized P&L
   // and does not duplicate the framework's open-equity liquidation rule.
   if(g_qm_ks_day_start_equity > 0.0)
     {
      const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
      const double realized_pct =
         ((balance_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
      if(realized_pct <= -strategy_daily_loss_limit_pct)
         return true;
     }

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   // Entry eligibility must not suppress lifecycle management for an existing trade.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(strategy_setup_bars < 2 || strategy_setup_bars > 5)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   // perf-allowed: one bounded structural OHLCV read behind the framework
   // closed-bar gate; maximum card-authorized window is five bars.
   if(CopyRates(_Symbol, PERIOD_H1, 1, strategy_setup_bars, bars) != strategy_setup_bars) // perf-allowed: bounded 2-5 bar structural setup behind QM_IsNewBar().
      return false;

   bool bullish = true;
   bool bearish = true;
   double setup_low = bars[0].low;
   double setup_high = bars[0].high;
   for(int i = 0; i < strategy_setup_bars; ++i)
     {
      if(bars[i].close <= 0.0 || bars[i].high <= 0.0 || bars[i].low <= 0.0)
         return false;
      setup_low = MathMin(setup_low, bars[i].low);
      setup_high = MathMax(setup_high, bars[i].high);
      if(i + 1 < strategy_setup_bars)
        {
         if(!(bars[i].close > bars[i + 1].close && bars[i].high > bars[i + 1].high))
            bullish = false;
         if(!(bars[i].close < bars[i + 1].close && bars[i].low < bars[i + 1].low))
            bearish = false;
        }
     }

   if(bars[0].tick_volume <= 0 || bars[1].tick_volume <= 0 ||
      bars[0].tick_volume <= bars[1].tick_volume)
      return false;

   const double tick_size_raw = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_size = (tick_size_raw > 0.0) ? tick_size_raw : _Point;
   const double offset = tick_size * strategy_entry_offset_ticks;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int period_seconds = PeriodSeconds(PERIOD_H1);
   if(tick_size <= 0.0 || offset <= 0.0 || ask <= 0.0 || bid <= 0.0 || period_seconds <= 0)
      return false;

   if(bullish)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, bars[0].high + offset);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, setup_low);
      if(entry <= ask || sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY_STOP, entry, sl, strategy_reward_r);
      if(tp <= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "three_bar_momentum_long";
      req.symbol_slot = 0;
      req.expiration_seconds = strategy_pending_expiry_bars * period_seconds;
      return true;
     }

   // The card explicitly specifies a SELL_STOP but gives the bullish setup
   // formula only. Apply the literal directional mirror for the short leg:
   // falling closes + falling lows, with the same rising-volume confirmation.
   if(bearish)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, bars[0].low - offset);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, setup_high);
      if(entry >= bid || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL_STOP, entry, sl, strategy_reward_r);
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "three_bar_momentum_short";
      req.symbol_slot = 0;
      req.expiration_seconds = strategy_pending_expiry_bars * period_seconds;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(PERIOD_H1);
   if(magic <= 0 || period_seconds <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 &&
         (TimeCurrent() - opened_at) >= (long)strategy_max_hold_bars * period_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || tp <= 0.0 || strategy_reward_r <= 0.0)
         continue;

      const double initial_r = MathAbs(tp - open_price) / strategy_reward_r;
      const double market_price = (position_type == POSITION_TYPE_BUY)
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double favorable_move = (position_type == POSITION_TYPE_BUY)
                                    ? market_price - open_price
                                    : open_price - market_price;
      if(initial_r > 0.0 && favorable_move >= initial_r)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   // Time exits are executed in Strategy_ManageOpenPosition so the framework
   // records the specific QM_EXIT_TIME_STOP reason. SL, TP, ATR trail, and
   // Friday-close exits are managed centrally.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Framework wiring below is kept identical to the canonical skeleton.
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
