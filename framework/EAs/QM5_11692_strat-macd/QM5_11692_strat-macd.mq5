#property strict
#property version   "5.0"
#property description "QM5_11692 strat-macd — Stratestic MACD Difference Trend (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11692 strat-macd
// -----------------------------------------------------------------------------
// Source: Diogo Matos Chaves / diogomatoschaves, stratestic,
//         stratestic/strategies/moving_average/macd.py
// Card: artifacts/cards_approved/QM5_11692_strat-macd.md (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads at shift 1, H1):
//   macd_diff = MACD line (QM_MACD_Main) - signal line (QM_MACD_Signal),
//               i.e. the ta.trend.MACD `macd_diff` histogram.
//   Card rule : long while macd_diff > 0, short while macd_diff < 0,
//               exit/reverse when macd_diff crosses zero.
//
//   Entry uses the histogram SIGN state:
//     Long  ENTRY : diff_now > 0.
//     Short ENTRY : diff_now < 0.
//   One position per magic; an opposite zero-cross first flattens via
//   Strategy_ExitSignal, then a fresh sign state opens the reverse.
//
//   Stop  : ATR catastrophic stop (source has none) at sl_atr_mult * ATR.
//   Take  : none; the card exits by zero-cross.
//   Exit  : macd_diff crosses zero against the open position.
//
// Symbols (card R3): EURUSD.DWX, XAUUSD.DWX, GER40 -> GDAXI.DWX (ported; GER40
//   is not a DWX matrix name, GDAXI.DWX is the DAX 40 custom index symbol).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11692;
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
input int    strategy_macd_fast         = 12;    // MACD window_fast (Stratestic default)
input int    strategy_macd_slow         = 26;    // MACD window_slow (Stratestic default)
input int    strategy_macd_signal       = 9;     // MACD window_sign (Stratestic default)
input int    strategy_atr_period        = 14;    // ATR period for catastrophic stop / target
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Card has no time/session/spread filter; framework-level news and Friday-close
// gates run outside this hook.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long+short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         1);
   const double macd_signal = QM_MACD_Signal(_Symbol, _Period,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal,
                                             1);
   const double diff_now = macd_main - macd_signal;
   if(diff_now == 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType side = (diff_now > 0.0) ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; zero-cross is the strategy exit
   req.reason = (side == QM_BUY) ? "macd_diff_long" : "macd_diff_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the fixed ATR catastrophic stop. The
// macd_diff zero-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: macd_diff crosses zero against the open position.
//   Long  position closes when diff crosses down through zero.
//   Short position closes when diff crosses up through zero.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine the side of the currently open position for this EA's magic.
   const int magic = QM_FrameworkMagic();
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((int)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         is_long = true;
      else
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double macd_main_now = QM_MACD_Main(_Symbol, _Period,
                                             strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal,
                                             1);
   const double macd_signal_now = QM_MACD_Signal(_Symbol, _Period,
                                                 strategy_macd_fast,
                                                 strategy_macd_slow,
                                                 strategy_macd_signal,
                                                 1);
   const double macd_main_prev = QM_MACD_Main(_Symbol, _Period,
                                              strategy_macd_fast,
                                              strategy_macd_slow,
                                              strategy_macd_signal,
                                              2);
   const double macd_signal_prev = QM_MACD_Signal(_Symbol, _Period,
                                                  strategy_macd_fast,
                                                  strategy_macd_slow,
                                                  strategy_macd_signal,
                                                  2);
   const double diff_now  = macd_main_now - macd_signal_now;
   const double diff_prev = macd_main_prev - macd_signal_prev;

   if(diff_now == 0.0)
      return true;

   const bool crossed_up   = (diff_prev <= 0.0 && diff_now > 0.0);
   const bool crossed_down = (diff_prev >= 0.0 && diff_now < 0.0);

   if(is_long && crossed_down)
      return true;
   if(is_short && crossed_up)
      return true;
   return false;
  }

// Defer to the central news filter.
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
