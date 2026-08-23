#property strict
#property version   "5.0"
#property description "QM5_9972 Bandy Heikin-Ashi Color-Flip Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9972 bandy-heikin-ashi-color-flip-trend
// -----------------------------------------------------------------------------
// Source: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press,
// 2015, ISBN 978-0-9791037-7-1. Card:
// artifacts/cards_approved/QM5_9972_bandy-heikin-ashi-color-flip-trend.md
//
// Entry (evaluated at next D1 open after bar 1 closes):
//   Compute recursive Heikin-Ashi OHLC.
//   Long entry:  HA red-to-green flip (ha_green[1] AND ha_red[2]) AND close[1] > SMA(200)[1]
//   Short entry: HA green-to-red flip (ha_red[1] AND ha_green[2]) AND close[1] < SMA(200)[1]
//   Razor body filter: |ha_close[1] - ha_open[1]| >= 0.1 * ATR(14)[1]
//   Anti-cluster: 3 D1 bars between same-direction entries
// Exit:
//   Opposite-color HA flip (Long exits on red bar, Short exits on green bar)
//   OR 30 D1 bars time stop.
// Stop:
//   2.5 * ATR(14) catastrophic stop from entry. One position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9972;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_regime_sma_period   = 200;  // Long-term regime filter SMA period
input int    strategy_atr_period          = 14;   // ATR period for stop and body filter
input double strategy_atr_stop_mult       = 2.5;  // Catastrophic stop ATR multiplier
input int    strategy_time_stop_bars      = 30;   // Maximum holding time in D1 bars
input int    strategy_anti_cluster_bars   = 3;    // Anti-cluster window in D1 bars
input double strategy_razor_body_atr_mult = 0.1;  // Razor-thin HA body threshold vs ATR(14)
input int    strategy_ha_seed_bars        = 50;   // Lookback bars to seed HA recurrence

datetime g_last_long_entry_bar_time = 0;
datetime g_last_short_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Strategy helper: compute HA synthetic OHLC for bar 1 and bar 2
// -----------------------------------------------------------------------------

bool Strategy_HeikinAshi2Bars(double &ha_open1, double &ha_close1, double &ha_open2, double &ha_close2)
  {
   ha_open1 = 0.0; ha_close1 = 0.0;
   ha_open2 = 0.0; ha_close2 = 0.0;
   if(strategy_ha_seed_bars < 2)
      return false;

   const int start_shift = 2 + strategy_ha_seed_bars;
   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;

   for(int shift = start_shift; shift >= 1; --shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, shift, bar))
         return false;

      const double cur_ha_close = (bar.open + bar.high + bar.low + bar.close) / 4.0;
      const double cur_ha_open = (shift == start_shift)
                                 ? ((bar.open + bar.close) / 2.0)
                                 : ((prev_ha_open + prev_ha_close) / 2.0);

      if(shift == 2)
        {
         ha_open2 = cur_ha_open;
         ha_close2 = cur_ha_close;
        }
      else if(shift == 1)
        {
         ha_open1 = cur_ha_open;
         ha_close1 = cur_ha_close;
        }

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

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

   if(strategy_regime_sma_period <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 || strategy_ha_seed_bars <= 0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double ha_open1 = 0.0, ha_close1 = 0.0;
   double ha_open2 = 0.0, ha_close2 = 0.0;
   if(!Strategy_HeikinAshi2Bars(ha_open1, ha_close1, ha_open2, ha_close2))
      return false;

   const bool ha_green1 = (ha_close1 > ha_open1);
   const bool ha_red1   = (ha_close1 < ha_open1);
   const bool ha_green2 = (ha_close2 > ha_open2);
   const bool ha_red2   = (ha_close2 < ha_open2);

   const double atr14 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr14 <= 0.0)
      return false;

   // Skip razor-thin HA body flip
   if(MathAbs(ha_close1 - ha_open1) < strategy_razor_body_atr_mult * atr14)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(regime_sma <= 0.0)
      return false;

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1))
      return false;

   // Long: red-to-green flip AND raw close above 200 SMA
   const bool long_signal = (ha_green1 && ha_red2 && bar1.close > regime_sma);

   // Short: green-to-red flip AND raw close below 200 SMA
   const bool short_signal = (ha_red1 && ha_green2 && bar1.close < regime_sma);

   if(long_signal && !short_signal)
     {
      if(g_last_long_entry_bar_time > 0)
        {
         const int bars_since = iBarShift(_Symbol, PERIOD_D1, g_last_long_entry_bar_time, false);
         if(bars_since >= 0 && bars_since < strategy_anti_cluster_bars)
            return false;
        }

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "BANDY_HA_FLIP_LONG";
      g_last_long_entry_bar_time = bar1.time;
      return true;
     }

   if(short_signal && !long_signal)
     {
      if(g_last_short_entry_bar_time > 0)
        {
         const int bars_since = iBarShift(_Symbol, PERIOD_D1, g_last_short_entry_bar_time, false);
         if(bars_since >= 0 && bars_since < strategy_anti_cluster_bars)
            return false;
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_stop_mult);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "BANDY_HA_FLIP_SHORT";
      g_last_short_entry_bar_time = bar1.time;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);

      // Time stop check (evaluated on every tick)
      if(strategy_time_stop_bars > 0)
        {
         const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }

      // Opposite HA color flip exit on completed bar 1
      double ha_open1 = 0.0, ha_close1 = 0.0;
      double ha_open2 = 0.0, ha_close2 = 0.0;
      if(Strategy_HeikinAshi2Bars(ha_open1, ha_close1, ha_open2, ha_close2))
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY)
           {
            // Long exit on red HA bar
            if(ha_close1 < ha_open1)
               return true;
           }
         else if(pos_type == POSITION_TYPE_SELL)
           {
            // Short exit on green HA bar
            if(ha_close1 > ha_open1)
               return true;
           }
        }
     }

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

