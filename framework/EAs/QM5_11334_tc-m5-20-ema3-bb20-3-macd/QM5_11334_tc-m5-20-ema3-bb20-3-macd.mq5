#property strict
#property version   "5.0"
#property description "QM5_11334 Carter M5 EMA3/BB20/MACD scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11334;
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
input int    strategy_ema_period          = 3;
input int    strategy_bb_period           = 20;
input double strategy_bb_dev              = 3.0;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_macd_lookback       = 3;
input int    strategy_sl_pips             = 12;
input int    strategy_tp_pips             = 12;
input int    strategy_max_spread_pips     = 8;

// Return TRUE to block trading this tick. Framework gates time, news, kill
// switch, and Friday close; this hook adds the card's spread cap.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(max_spread <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > max_spread)
      return true;

   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period < 1 ||
      strategy_bb_period < 2 ||
      strategy_bb_dev <= 0.0 ||
      strategy_macd_fast < 1 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 ||
      strategy_macd_lookback < 0 ||
      strategy_sl_pips < 1 ||
      strategy_tp_pips < 1)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0 || mid_now <= 0.0 || mid_prev <= 0.0)
      return false;

   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   bool macd_long_ok = (macd_now < 0.0 && macd_now > macd_prev);
   bool macd_short_ok = (macd_now > 0.0 && macd_now < macd_prev);
   const int macd_cross_bars = (strategy_macd_lookback > 0 ? strategy_macd_lookback : 1);
   for(int shift = 1; shift <= macd_cross_bars; ++shift)
     {
      const double m_now = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
      if(m_prev <= 0.0 && m_now > 0.0)
         macd_long_ok = true;
      if(m_prev >= 0.0 && m_now < 0.0)
         macd_short_ok = true;
     }

   const bool long_cross = (ema_prev <= mid_prev && ema_now > mid_now);
   const bool short_cross = (ema_prev >= mid_prev && ema_now < mid_now);

   if(long_cross && macd_long_ok)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ema3_bbmid_up_macd_zero";
      return true;
     }

   if(short_cross && macd_short_ok)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ema3_bbmid_down_macd_zero";
      return true;
     }

   return false;
  }

// Trade Management. Card specifies fixed SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. Card exits via the protective stop and fixed target.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook. Defer to the framework news filter.
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
