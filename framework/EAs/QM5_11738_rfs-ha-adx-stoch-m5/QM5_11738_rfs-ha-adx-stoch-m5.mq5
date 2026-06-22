#property strict
#property version   "5.0"
#property description "QM5_11738 rfs-ha-adx-stoch-m5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11738 rfs-ha-adx-stoch-m5
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11738_rfs-ha-adx-stoch-m5.md
// Source: Robo-forex Strategy Compilation, "Heiken Ashi + ADX + Stochastic".
//
// Entry is evaluated once per closed M5 bar by the framework QM_IsNewBar gate:
//   Long  = two bullish Heiken Ashi closed bars, ADX(14)>22 and rising,
//           +DI>-DI, and Stoch(5,3,3) K rising.
//   Short = two bearish Heiken Ashi closed bars, ADX(14)>22 and rising,
//           -DI>+DI, and Stoch(5,3,3) K falling.
// SL/TP are fixed pips from the card factory defaults: SL 7 pips, TP 12 pips.
//
// Heiken Ashi is bespoke structural candle math with no QM_* reader. It uses a
// bounded closed-bar CopyRates window only inside Strategy_EntrySignal, which is
// called after the framework new-bar gate, so it is not on the per-tick path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11738;
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
input int    strategy_ha_seed_bars      = 80;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 22.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_sl_pips           = 7;
input int    strategy_tp_pips           = 12;
input int    strategy_max_spread_pips   = 0;

bool ComputeHeikenAshi(const int shift,
                       double &ha_open,
                       double &ha_high,
                       double &ha_low,
                       double &ha_close)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int seed = (strategy_ha_seed_bars < 20) ? 20 : strategy_ha_seed_bars;
   const int count = seed + shift + 1;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, count, rates); // perf-allowed: bounded Heiken Ashi OHLC window, called only from the framework QM_IsNewBar-gated entry hook.
   if(copied < count)
      return false;

   const int oldest = count - 1;
   double raw_open = rates[oldest].open;
   double raw_high = rates[oldest].high;
   double raw_low = rates[oldest].low;
   double raw_close = rates[oldest].close;
   if(raw_open <= 0.0 || raw_high <= 0.0 || raw_low <= 0.0 || raw_close <= 0.0)
      return false;

   double prev_ha_open = (raw_open + raw_close) * 0.5;
   double prev_ha_close = (raw_open + raw_high + raw_low + raw_close) * 0.25;

   double current_ha_open = prev_ha_open;
   double current_ha_close = prev_ha_close;
   double current_ha_high = MathMax(raw_high, MathMax(current_ha_open, current_ha_close));
   double current_ha_low = MathMin(raw_low, MathMin(current_ha_open, current_ha_close));

   for(int i = oldest - 1; i >= shift; --i)
     {
      raw_open = rates[i].open;
      raw_high = rates[i].high;
      raw_low = rates[i].low;
      raw_close = rates[i].close;
      if(raw_open <= 0.0 || raw_high <= 0.0 || raw_low <= 0.0 || raw_close <= 0.0)
         return false;

      current_ha_close = (raw_open + raw_high + raw_low + raw_close) * 0.25;
      current_ha_open = (prev_ha_open + prev_ha_close) * 0.5;
      current_ha_high = MathMax(raw_high, MathMax(current_ha_open, current_ha_close));
      current_ha_low = MathMin(raw_low, MathMin(current_ha_open, current_ha_close));

      prev_ha_open = current_ha_open;
      prev_ha_close = current_ha_close;
     }

   ha_open = current_ha_open;
   ha_high = current_ha_high;
   ha_low = current_ha_low;
   ha_close = current_ha_close;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(strategy_adx_period <= 0 ||
      strategy_stoch_k <= 0 ||
      strategy_stoch_d <= 0 ||
      strategy_stoch_slowing <= 0 ||
      strategy_sl_pips <= 0 ||
      strategy_tp_pips <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   double ha_open_1 = 0.0;
   double ha_high_1 = 0.0;
   double ha_low_1 = 0.0;
   double ha_close_1 = 0.0;
   double ha_open_2 = 0.0;
   double ha_high_2 = 0.0;
   double ha_low_2 = 0.0;
   double ha_close_2 = 0.0;
   if(!ComputeHeikenAshi(1, ha_open_1, ha_high_1, ha_low_1, ha_close_1))
      return false;
   if(!ComputeHeikenAshi(2, ha_open_2, ha_high_2, ha_low_2, ha_close_2))
      return false;

   const double adx_1 = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   const double adx_2 = QM_ADX(_Symbol, tf, strategy_adx_period, 2);
   const double plus_di = QM_ADX_PlusDI(_Symbol, tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, tf, strategy_adx_period, 1);
   const double stoch_1 = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_2 = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(adx_1 <= 0.0 || adx_2 <= 0.0 || plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   const bool ha_bullish = (ha_close_1 > ha_open_1 && ha_close_2 > ha_open_2);
   const bool ha_bearish = (ha_close_1 < ha_open_1 && ha_close_2 < ha_open_2);
   const bool adx_strong_rising = (adx_1 > strategy_adx_threshold && adx_1 > adx_2);
   const bool stoch_rising = (stoch_1 > stoch_2);
   const bool stoch_falling = (stoch_1 < stoch_2);

   if(ha_bullish && adx_strong_rising && plus_di > minus_di && stoch_rising)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_sl_pips);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      req.reason = "HA_ADX_STOCH_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ha_bearish && adx_strong_rising && minus_di > plus_di && stoch_falling)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_sl_pips);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      req.reason = "HA_ADX_STOCH_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, break-even, partial, or scale-in.
  }

bool Strategy_ExitSignal()
  {
   // Card exits through fixed SL/TP; framework Friday close remains active.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11738_rfs-ha-adx-stoch-m5\"}");
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
