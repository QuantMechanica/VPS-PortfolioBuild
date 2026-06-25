#property strict
#property version   "5.0"
#property description "QM5_11359 robo-adx-mom — RoboForex ADX + Momentum Trend Scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11359 robo-adx-mom
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy ADX and Momentum".
// Card: artifacts/cards_approved/QM5_11359_robo-adx-mom.md (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; one open position per magic):
//   Entry STATE   : ADX(adx_period) > adx_threshold.
//                   LONG  -> +DI > di_threshold and +DI > -DI.
//                   SHORT -> -DI > di_threshold and -DI > +DI.
//   Momentum     : Momentum(mom_period) > 100+mom_band (LONG) /
//                  < 100-mom_band (SHORT). MT5 iMomentum is ratio*100 around 100.
//   PSAR STATE   : SAR dot below price (LONG) / above price (SHORT), shift 1.
//   EMA STATE    : close > EMA(ema_period) (LONG) / close < EMA (SHORT),
//                  enabled by ema_filter_enabled (baseline ON per card).
//   Stop / Take  : fixed pip distances (sl_pips / tp_pips), scale-correct via
//                  QM_StopRulesPipsToPriceDistance (5-digit / JPY aware).
//   Early exit   : opposite DI becomes dominant OR Momentum crosses back
//                  through 100 against the open position.
//   No-trade     : London + New York broker-time session and spread cap. The
//                  spread guard blocks only genuinely wide spread, not .DWX zero spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11359;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adx_period        = 14;     // ADX / DI period
input double strategy_adx_threshold     = 25.0;   // ADX strength floor (trend on)
input double strategy_di_threshold      = 25.0;   // dominant-DI floor
input int    strategy_mom_period        = 14;     // Momentum period (iMomentum ~100)
input double strategy_mom_band          = 0.0;    // band around 100 (0 = strict >/< 100)
input double strategy_sar_step          = 0.02;   // Parabolic SAR step
input double strategy_sar_max           = 0.2;    // Parabolic SAR maximum
input bool   strategy_ema_filter_enabled = true;  // EMA(55) trend filter (baseline ON)
input int    strategy_ema_period        = 55;     // EMA trend-context period
input int    strategy_sl_pips           = 7;      // stop-loss distance in pips
input int    strategy_tp_pips           = 15;     // take-profit distance in pips
input double strategy_spread_cap_pips   = 1.5;    // skip only if spread wider than this
input int    strategy_session_start_hour_broker = 10; // London start mapped to DXZ broker time
input int    strategy_session_end_hour_broker   = 0;  // NY end mapped to DXZ broker midnight

// Convert a fixed pip count to a scale-correct price distance for this symbol.
double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): framework handles news; this hook
// applies the card's London + New York session and spread cap.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   const int start_h = strategy_session_start_hour_broker;
   const int end_h   = strategy_session_end_hour_broker;
   if(start_h >= 0 && start_h <= 23 && end_h >= 0 && end_h <= 23 && start_h != end_h)
     {
      bool in_session = false;
      if(start_h < end_h)
         in_session = (dt.hour >= start_h && dt.hour < end_h);
      else
         in_session = (dt.hour >= start_h || dt.hour < end_h);
      if(!in_session)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread = ask - bid;
   const double one_pip = PipDistance(1);
   const double cap = one_pip * strategy_spread_cap_pips;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Enter at the next M5 bar open when all card states are true on the closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_adx_period <= 0 || strategy_mom_period <= 0 ||
      strategy_ema_period <= 0 || strategy_sl_pips <= 0 || strategy_tp_pips <= 0)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0 || adx <= strategy_adx_threshold)
      return false;

   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   const double sar = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = QM_SMA(_Symbol, _Period, 1, 1);
   if(sar <= 0.0 || close1 <= 0.0)
      return false;

   double ema = 0.0;
   if(strategy_ema_filter_enabled)
     {
      ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      if(ema <= 0.0)
         return false;
     }

   const bool go_long = (plus_di > strategy_di_threshold) &&
                        (plus_di > minus_di) &&
                        (mom > 100.0 + strategy_mom_band) &&
                        (sar < close1) &&
                        (!strategy_ema_filter_enabled || close1 > ema);

   const bool go_short = (minus_di > strategy_di_threshold) &&
                         (minus_di > plus_di) &&
                         (mom < 100.0 - strategy_mom_band) &&
                         (sar > close1) &&
                         (!strategy_ema_filter_enabled || close1 < ema);

   if(!go_long && !go_short)
      return false;

   const QM_OrderType type = go_long ? QM_BUY : QM_SELL;

   const double entry = (type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, type, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, type, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = type;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "robo_adx_mom_long" : "robo_adx_mom_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: no active trade management beyond the fixed pip stop/target; early exit
// (opposite DI / Momentum reversal) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: opposite DI becomes dominant OR Momentum crosses back
// through 100 against the open position. Closed-bar STATE checks at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the side of the currently open position for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_period, 2);
   if(plus_di <= 0.0 || minus_di <= 0.0 || mom_now <= 0.0 || mom_prev <= 0.0)
      return false;

   if(is_long)
     {
      const bool di_against  = (minus_di > plus_di);
      const bool mom_against = (mom_prev >= 100.0 && mom_now < 100.0);
      return (di_against || mom_against);
     }

   // is_short
   const bool di_against  = (plus_di > minus_di);
   const bool mom_against = (mom_prev <= 100.0 && mom_now > 100.0);
   return (di_against || mom_against);
  }

// News Filter Hook: defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
