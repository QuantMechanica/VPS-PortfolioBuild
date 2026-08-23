#property strict
#property version   "5.0"
#property description "QM5_9979 Bandy Index Gap-Fade Mean-Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9979 bandy-index-gap-fade-mr-index
// -----------------------------------------------------------------------------
// Source: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press,
// 2015, ISBN 978-0-9791037-7-1. Card:
// artifacts/cards_approved/QM5_9979_bandy-index-gap-fade-mr-index.md
//
// Entry (evaluated at next D1 open after gap bar closes):
//   gap = open[1] - close[2]
//   Significance: |gap| >= 0.5 * ATR(14)[2]
//   Long entry (fade down-gap):  gap < 0 AND close[1] > open[1] AND close[1] > SMA(200)[1]
//   Short entry (fade up-gap):   gap > 0 AND close[1] < open[1] AND close[1] < SMA(200)[1]
//   Anti-cluster: 2 D1 bars between same-direction entries
// Exit:
//   Gap-fill target (Long: high >= close_prev, Short: low <= close_prev)
//   OR 5 D1 bars time stop.
// Stop:
//   1.5 * ATR(14) catastrophic stop from entry. One position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9979;
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
input double strategy_gap_atr_mult       = 0.5;  // Gap significance multiplier vs ATR(14)
input int    strategy_regime_sma_period  = 200;  // Long-term regime filter SMA period
input int    strategy_atr_period         = 14;   // ATR period for gap threshold and catastrophic stop
input double strategy_atr_stop_mult      = 1.5;  // Catastrophic stop ATR multiplier
input int    strategy_time_stop_days     = 5;    // Maximum holding time in D1 bars
input int    strategy_anti_cluster_bars  = 2;    // Anti-cluster window in D1 bars

datetime g_last_long_entry_bar_time = 0;
datetime g_last_short_entry_bar_time = 0;

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

   if(strategy_gap_atr_mult <= 0.0 || strategy_regime_sma_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates bar1, bar2;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1))
      return false;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 2, bar2))
      return false;

   // Gap between bar 1 open and prior bar 2 close
   const double gap = bar1.open - bar2.close;

   // ATR computed prior to the gap bar (shift 2) to avoid look-ahead bias
   const double atr14 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 2);
   if(atr14 <= 0.0)
      return false;

   // Gap significance check
   if(MathAbs(gap) < strategy_gap_atr_mult * atr14)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(regime_sma <= 0.0)
      return false;

   // Long: down-gap (gap < 0) + bullish close on gap bar (bar1.close > bar1.open) + above regime SMA
   const bool long_signal = (gap < 0.0 && bar1.close > bar1.open && bar1.close > regime_sma);

   // Short: up-gap (gap > 0) + bearish close on gap bar (bar1.close < bar1.open) + below regime SMA
   const bool short_signal = (gap > 0.0 && bar1.close < bar1.open && bar1.close < regime_sma);

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
      req.reason = "BANDY_INDEX_GAP_FADE_LONG";
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
      req.reason = "BANDY_INDEX_GAP_FADE_SHORT";
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
      if(strategy_time_stop_days > 0)
        {
         const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
         if(bars_held >= strategy_time_stop_days)
            return true;
        }

      // Gap-fill target check:
      const int entry_bar_shift = iBarShift(_Symbol, PERIOD_D1, opened, false);
      if(entry_bar_shift >= 0)
        {
         const double gap_origin_close = iClose(_Symbol, PERIOD_D1, entry_bar_shift + 2);
         if(gap_origin_close > 0.0)
           {
            const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            MqlRates bar1;
            if(QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1))
              {
               if(pos_type == POSITION_TYPE_BUY)
                 {
                  // Long exit when high >= close_prev (gap filled)
                  if(bar1.high >= gap_origin_close)
                     return true;
                 }
               else if(pos_type == POSITION_TYPE_SELL)
                 {
                  // Short mirror exit when low <= close_prev (gap filled)
                  if(bar1.low <= gap_origin_close)
                     return true;
                 }
              }
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

