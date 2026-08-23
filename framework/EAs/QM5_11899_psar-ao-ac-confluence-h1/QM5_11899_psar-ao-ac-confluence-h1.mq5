#property strict
#property version   "5.0"
#property description "QM5_11899 PSAR + AO + AC Confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11899
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11899;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf         = PERIOD_H1;
input double strategy_psar_step                 = 0.02;
input double strategy_psar_max                  = 0.2;
input int    strategy_ao_fast_period            = 5;
input int    strategy_ao_slow_period            = 34;
input int    strategy_ac_period                 = 5;
input double strategy_target_rr                 = 1.0;
input double strategy_sl_buffer_pips            = 2.0;
input bool   strategy_alt_exit                  = true;
input int    strategy_time_stop_bars            = 96;

// -----------------------------------------------------------------------------
// Helper routines
// -----------------------------------------------------------------------------

double Strategy_PipSize()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
}

double Strategy_AO(const int shift)
{
   const double fast = QM_SMA(_Symbol, strategy_signal_tf, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, strategy_signal_tf, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   if(fast == 0.0 || slow == 0.0) return 0.0;
   return fast - slow;
}

double Strategy_AC(const int shift)
{
   if(strategy_ac_period <= 0) return 0.0;
   double sum_ao = 0.0;
   for(int i = 0; i < strategy_ac_period; ++i)
   {
      sum_ao += Strategy_AO(shift + i);
   }
   const double sma_ao = sum_ao / (double)strategy_ac_period;
   const double current_ao = Strategy_AO(shift);
   return current_ao - sma_ao;
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

   if(_Period != strategy_signal_tf) return false;

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 1, bar1))
      return false;

   if(bar1.close <= 0.0 || bar1.low <= 0.0 || bar1.high <= 0.0) return false;

   const double psar1 = QM_SAR(_Symbol, strategy_signal_tf, strategy_psar_step, strategy_psar_max, 1);
   const double ao1   = Strategy_AO(1);
   const double ao2   = Strategy_AO(2);
   const double ac1   = Strategy_AC(1);
   const double ac2   = Strategy_AC(2);

   if(psar1 <= 0.0) return false;

   const bool is_psar_long  = (psar1 < bar1.low);
   const bool is_psar_short = (psar1 > bar1.high);

   const bool is_ao_bullish = (ao1 > ao2);
   const bool is_ao_bearish = (ao1 < ao2);

   const bool is_ac_bullish = (ac1 > ac2);
   const bool is_ac_bearish = (ac1 < ac2);

   const bool signal_long  = (is_psar_long && is_ao_bullish && is_ac_bullish);
   const bool signal_short = (is_psar_short && is_ao_bearish && is_ac_bearish);

   if(!signal_long && !signal_short) return false;

   const double pip_size = Strategy_PipSize();
   const double buffer = strategy_sl_buffer_pips * pip_size;

   if(signal_long)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bar1.low - buffer);
      if(sl <= 0.0 || sl >= ask) return false;
      const double risk_dist = ask - sl;
      const double tp = QM_StopRulesNormalizePrice(_Symbol, ask + (risk_dist * strategy_target_rr));
      if(tp <= ask) return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "PSAR_AO_AC_LONG";
      return true;
   }
   else if(signal_short)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bar1.high + buffer);
      if(sl <= bid) return false;
      const double risk_dist = sl - bid;
      const double tp = QM_StopRulesNormalizePrice(_Symbol, bid - (risk_dist * strategy_target_rr));
      if(tp <= 0.0 || tp >= bid) return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "PSAR_AO_AC_SHORT";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int tf_seconds = PeriodSeconds(strategy_signal_tf);
      if(strategy_time_stop_bars > 0 && opened > 0 && tf_seconds > 0)
      {
         if(TimeCurrent() - opened >= strategy_time_stop_bars * tf_seconds)
            return true;
      }

      if(strategy_alt_exit && QM_IsNewBar(_Symbol, strategy_signal_tf))
      {
         const double ao1   = Strategy_AO(1);
         const double ao2   = Strategy_AO(2);
         const double ac1   = Strategy_AC(1);
         const double ac2   = Strategy_AC(2);

         const bool is_ao_bullish = (ao1 > ao2);
         const bool is_ao_bearish = (ao1 < ao2);
         const bool is_ac_bullish = (ac1 > ac2);
         const bool is_ac_bearish = (ac1 < ac2);

         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         if(ptype == POSITION_TYPE_BUY && is_ao_bearish && is_ac_bearish) return true;
         if(ptype == POSITION_TYPE_SELL && is_ao_bullish && is_ac_bullish) return true;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   QM_FrameworkTrackOpenPositionMae();
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf)) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
