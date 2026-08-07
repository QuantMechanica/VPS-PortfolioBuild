#property strict
#property version   "5.0"
#property description "QM5_11416 Ichimoku Tenkan/Kijun cross with cloud filter (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11416_ichimoku-tenkan-kijun-cross-cloud-h4
// -----------------------------------------------------------------------------
// Approved card: D:\QM\strategy_farm\artifacts\cards_approved\
//   QM5_11416_ichimoku-tenkan-kijun-cross-cloud-h4.md
// Source ID: d45db07a-2928-5ff6-9251-d54170212549
//
// Strategy-specific code is confined to the five Strategy_* hooks and the
// Strategy input group. Framework lifecycle, risk, magic, news, Friday-close,
// MAE sampling, entry dispatch, and Model-4 tester wiring remain canonical.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11416;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // live setfiles set 0.5
input double RISK_FIXED                 = 1000.0;  // tester default
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_tenkan_period      = 9;
input int    strategy_kijun_period       = 26;
input int    strategy_senkou_period      = 52;
input int    strategy_sl_cap_pips        = 60;
input int    strategy_spread_cap_pips    = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — mechanical transcription of the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
// H4 cadence is fixed by the generated setfiles. The central framework news
// gate runs after management/exit and blocks only entry. This hook enforces the
// card's 20-pip spread cap and fails open on the tester's zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_tenkan_period < 1 ||
      strategy_kijun_period <= strategy_tenkan_period ||
      strategy_senkou_period <= strategy_kijun_period ||
      strategy_sl_cap_pips <= 0 ||
      strategy_spread_cap_pips <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry
// The caller guarantees one evaluation per new bar. The last closed H4 bar is
// shift 1, so the prior cross state is shift 2. Senkou buffers are displaced
// forward by Kijun bars; the cloud plotted against closed bar 1 is therefore
// read at Kijun+1. Chikou is the closed price compared with the bar Kijun bars
// behind it, also shift Kijun+1.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H4;
   const int cloud_shift = strategy_kijun_period + 1;

   const double tenkan_1 = QM_Ichimoku_TenkanSen(_Symbol, tf,
                                                  strategy_tenkan_period,
                                                  strategy_kijun_period,
                                                  strategy_senkou_period, 1);
   const double kijun_1 = QM_Ichimoku_KijunSen(_Symbol, tf,
                                                strategy_tenkan_period,
                                                strategy_kijun_period,
                                                strategy_senkou_period, 1);
   const double tenkan_2 = QM_Ichimoku_TenkanSen(_Symbol, tf,
                                                  strategy_tenkan_period,
                                                  strategy_kijun_period,
                                                  strategy_senkou_period, 2);
   const double kijun_2 = QM_Ichimoku_KijunSen(_Symbol, tf,
                                                strategy_tenkan_period,
                                                strategy_kijun_period,
                                                strategy_senkou_period, 2);
   const double span_a_1 = QM_Ichimoku_SenkouSpanA(_Symbol, tf,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_period,
                                                    cloud_shift);
   const double span_b_1 = QM_Ichimoku_SenkouSpanB(_Symbol, tf,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_period,
                                                    cloud_shift);
   const double span_a_2 = QM_Ichimoku_SenkouSpanA(_Symbol, tf,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_period,
                                                    cloud_shift + 1);
   const double span_b_2 = QM_Ichimoku_SenkouSpanB(_Symbol, tf,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_period,
                                                    cloud_shift + 1);

   const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar Chikou value inside the framework new-bar gate
   const double historical_high = iHigh(_Symbol, tf, cloud_shift); // perf-allowed: bespoke Chikou-vs-historical-bar rule inside the framework new-bar gate
   const double historical_low = iLow(_Symbol, tf, cloud_shift); // perf-allowed: bespoke Chikou-vs-historical-bar rule inside the framework new-bar gate

   if(tenkan_1 <= 0.0 || kijun_1 <= 0.0 ||
      tenkan_2 <= 0.0 || kijun_2 <= 0.0 ||
      span_a_1 <= 0.0 || span_b_1 <= 0.0 ||
      span_a_2 <= 0.0 || span_b_2 <= 0.0 ||
      close_1 <= 0.0 || historical_high <= 0.0 || historical_low <= 0.0)
      return false;

   // Literal reading of the card's unquantified range filter: block only when
   // every Ichimoku line is exactly horizontal across the last two closed bars.
   const bool all_lines_flat = (tenkan_1 == tenkan_2 &&
                                kijun_1 == kijun_2 &&
                                span_a_1 == span_a_2 &&
                                span_b_1 == span_b_2);
   if(all_lines_flat)
      return false;

   const double cloud_top = MathMax(span_a_1, span_b_1);
   const double cloud_bottom = MathMin(span_a_1, span_b_1);
   const bool long_signal = (tenkan_2 < kijun_2 &&
                             tenkan_1 > kijun_1 &&
                             close_1 > cloud_top &&
                             close_1 > historical_high);
   const bool short_signal = (tenkan_2 > kijun_2 &&
                              tenkan_1 < kijun_1 &&
                              close_1 < cloud_bottom &&
                              close_1 < historical_low);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = SymbolInfoDouble(_Symbol,
                                                long_signal ? SYMBOL_ASK : SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double cap_stop = QM_StopFixedPips(_Symbol,
                                             side,
                                             entry_price,
                                             strategy_sl_cap_pips);
   if(cap_stop <= 0.0)
      return false;

   // Baseline choice from the card's two alternatives: Kijun stop, with the
   // 60-pip P2 cap taking precedence whenever Kijun is farther away or is on
   // the wrong side of the market.
   double stop_price = cap_stop;
   if(long_signal && kijun_1 < entry_price)
      stop_price = MathMax(kijun_1, cap_stop);
   if(short_signal && kijun_1 > entry_price)
      stop_price = MathMin(kijun_1, cap_stop);
   stop_price = QM_StopRulesNormalizePrice(_Symbol, stop_price);

   if((long_signal && stop_price >= entry_price) ||
      (short_signal && stop_price <= entry_price))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = long_signal ? "ichimoku_tk_cloud_chikou_long"
                            : "ichimoku_tk_cloud_chikou_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management
// The card specifies no break-even, trailing, partial-close, or scale-in rule.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
// Chikou is the current price plotted Kijun bars back. Exit as soon as it is
// inside that historical H4 bar's range. Protective Kijun/capped stops and the
// framework Friday close remain server/framework exits, not discretionary ones.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         have_long = true;
      if(position_type == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(!have_long && !have_short)
      return false;

   const double historical_high = iHigh(_Symbol, PERIOD_H4, strategy_kijun_period); // perf-allowed: O(1) bespoke Chikou exit range
   const double historical_low = iLow(_Symbol, PERIOD_H4, strategy_kijun_period); // perf-allowed: O(1) bespoke Chikou exit range
   if(historical_high <= 0.0 || historical_low <= 0.0)
      return false;

   const double chikou_price = SymbolInfoDouble(_Symbol,
                                                 have_long ? SYMBOL_BID : SYMBOL_ASK);
   if(chikou_price <= 0.0)
      return false;

   return (chikou_price <= historical_high && chikou_price >= historical_low);
  }

// News Filter Hook
// No strategy-specific override; the callable framework hook remains available
// for P8 and the central news gate blocks entries only.
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
   // Q08 evidence lifecycle: this must precede every early return.
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

   // Management and discretionary exits deliberately run before the entry-only
   // news blackout gate.
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
