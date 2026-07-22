#property strict
#property version   "5.0"
#property description "QM5_20037 LBMA PM gold-auction breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_LbmaGoldPmCalendar.mqh>

// Strategy Card: QM5_20037_lbma-pm-brk, G0 APPROVED 2026-07-22.
// Auction eligibility comes only from the hash-bound official ICE IBA planned
// PM schedule.  Price bars never substitute for auction-calendar membership.

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20037;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; framework news gate fails closed if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_variant_id        = "LBMA_PM_BRK_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_pre_bar_hour_london = 14;
input int    strategy_pre_bar_minute_london = 55;
input int    strategy_confirmation1_hour_london = 15;
input int    strategy_confirmation1_minute_london = 0;
input int    strategy_confirmation2_hour_london = 15;
input int    strategy_confirmation2_minute_london = 5;
input int    strategy_exit_hour_london = 15;
input int    strategy_exit_minute_london = 15;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_last_attempt_date_key = 0;
datetime g_active_exit_broker = 0;
bool     g_lbma_calendar_ready = false;
int      g_last_calendar_log_date_key = 0;
string   g_last_calendar_log_detail = "";

bool Strategy_ResolveAuctionTimes(const int date_key,
                                  datetime &pre_bar_utc,
                                  datetime &confirmation1_utc,
                                  datetime &confirmation2_utc,
                                  datetime &exit_utc)
  {
   pre_bar_utc = 0;
   confirmation1_utc = 0;
   confirmation2_utc = 0;
   exit_utc = 0;
   if(!QM_LbmaGoldPmLondonLocalToUTC(date_key,
                                     strategy_pre_bar_hour_london,
                                     strategy_pre_bar_minute_london,
                                     pre_bar_utc) ||
      !QM_LbmaGoldPmLondonLocalToUTC(date_key,
                                     strategy_confirmation1_hour_london,
                                     strategy_confirmation1_minute_london,
                                     confirmation1_utc) ||
      !QM_LbmaGoldPmLondonLocalToUTC(date_key,
                                     strategy_confirmation2_hour_london,
                                     strategy_confirmation2_minute_london,
                                     confirmation2_utc) ||
      !QM_LbmaGoldPmLondonLocalToUTC(date_key,
                                     strategy_exit_hour_london,
                                     strategy_exit_minute_london,
                                     exit_utc))
      return false;
   return (pre_bar_utc > 0 &&
           confirmation1_utc - pre_bar_utc == 5 * 60 &&
           confirmation2_utc - confirmation1_utc == 5 * 60 &&
           exit_utc - confirmation2_utc == 10 * 60);
  }

bool Strategy_FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_AttemptAlreadyMade(const int date_key,
                                 const datetime pre_bar_utc)
  {
   if(g_last_attempt_date_key == date_key)
      return true;
   const datetime from_broker = QM_UTCToBroker(pre_bar_utc - 60 * 60);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
      return true;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_utc = QM_BrokerToUTC((datetime)HistoryDealGetInteger(deal, DEAL_TIME));
      if(QM_LbmaGoldPmLondonDateKeyFromUTC(deal_utc) == date_key)
         return true;
     }
   return false;
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

int Strategy_ConfirmationOutcome(const bool armed_long,
                                 const double close_price,
                                 const double pre_high,
                                 const double pre_low)
  {
   if(close_price <= 0.0 || pre_high <= pre_low)
      return 0;
   if(armed_long)
     {
      if(close_price < pre_low)
         return -1;
      if(close_price > pre_high)
         return 1;
      return 0;
     }
   if(close_price > pre_high)
      return -1;
   if(close_price < pre_low)
      return 1;
   return 0;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 ||
      point <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   if(stop_distance <= 0.0)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

bool Strategy_InputsValid()
  {
   return (strategy_variant_id == "LBMA_PM_BRK_BASELINE" &&
           strategy_signal_tf == PERIOD_M5 &&
           strategy_pre_bar_hour_london == 14 &&
           strategy_pre_bar_minute_london == 55 &&
           strategy_confirmation1_hour_london == 15 &&
           strategy_confirmation1_minute_london == 0 &&
           strategy_confirmation2_hour_london == 15 &&
           strategy_confirmation2_minute_london == 5 &&
           strategy_exit_hour_london == 15 &&
           strategy_exit_minute_london == 15);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

void Strategy_LogEntryRejected(const string detail,
                               const datetime candidate_utc)
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"LBMA_PM_BRK\",\"detail\":\"%s\",\"candidate_utc\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            (long)candidate_utc));
  }

void Strategy_LogCalendarStateOnce(const int date_key,
                                   const string detail,
                                   const QM_LbmaGoldPmScheduleStatus schedule_status,
                                   const QM_LbmaGoldPmActualStatus actual_status,
                                   const datetime candidate_utc,
                                   const datetime auction_utc,
                                   const bool eligible)
  {
   if(g_last_calendar_log_date_key == date_key &&
      g_last_calendar_log_detail == detail)
      return;
   g_last_calendar_log_date_key = date_key;
   g_last_calendar_log_detail = detail;
   QM_LogEvent(eligible ? QM_INFO : QM_WARN,
               eligible ? "AUCTION_DATE_ADMITTED" : "ENTRY_REJECTED",
               StringFormat("{\"result\":\"%s\",\"symbol\":\"%s\",\"reason\":\"LBMA_PM_CALENDAR\",\"detail\":\"%s\",\"date_key\":%d,\"schedule_status\":\"%s\",\"actual_status_evidence\":\"%s\",\"candidate_utc\":%I64d,\"auction_utc\":%I64d,\"calendar_status\":\"%s\",\"runtime_sha256\":\"%s\",\"provenance_sha256\":\"%s\",\"manifest_sha256\":\"%s\"}",
                            eligible ? "SCHEDULE_ELIGIBLE" : "STRATEGY_HOOK_REJECTED",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            QM_LoggerEscapeJson(QM_LbmaGoldPmScheduleStatusName(schedule_status)),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmActualStatusName(actual_status)),
                            (long)candidate_utc,
                            (long)auction_utc,
                            QM_LBMA_GOLD_PM_CALENDAR_STATUS,
                            QM_LoggerEscapeJson(QM_LbmaGoldPmRuntimeActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmProvenanceActualSha256()),
                            QM_LBMA_GOLD_PM_MANIFEST_SHA256));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   if(_Symbol != "XAUUSD.DWX" || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return true;
   if(!g_lbma_calendar_ready)
      return true;
   return Strategy_WideSpread();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Symbol != "XAUUSD.DWX" || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return false;

   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar))
      return false;
   const datetime current_utc = QM_BrokerToUTC(current_bar.time);
   const int date_key = QM_LbmaGoldPmLondonDateKeyFromUTC(current_utc);
   datetime pre_bar_utc = 0;
   datetime confirmation1_utc = 0;
   datetime confirmation2_utc = 0;
   datetime exit_utc = 0;
   if(date_key == 0 ||
      !Strategy_ResolveAuctionTimes(date_key,
                                    pre_bar_utc,
                                    confirmation1_utc,
                                    confirmation2_utc,
                                    exit_utc))
      return false;

   const bool first_entry = (current_utc == confirmation2_utc);
   const bool second_entry = (current_utc == confirmation2_utc + 5 * 60);
   if(!first_entry && !second_entry)
      return false;

   const QM_LbmaGoldPmScheduleStatus schedule_status =
      QM_LbmaGoldPmCalendarClassify(date_key);
   const QM_LbmaGoldPmActualStatus actual_status =
      QM_LbmaGoldPmActualStatusForDate(date_key);
   datetime scheduled_auction_utc = 0;
   if(schedule_status != QM_LBMA_GOLD_PM_SCHEDULED)
     {
      string detail = "SCHEDULE_PACKAGE_DATE_LOOKUP_INVALID";
      if(schedule_status == QM_LBMA_GOLD_PM_OUT_OF_COVERAGE)
         detail = "SCHEDULE_DATE_OUT_OF_VERIFIED_COVERAGE";
      else if(schedule_status == QM_LBMA_GOLD_PM_NO_AUCTION_HOLIDAY)
         detail = "OFFICIAL_PM_NO_AUCTION_HOLIDAY";
      else if(schedule_status == QM_LBMA_GOLD_PM_NO_AUCTION_WEEKEND)
         detail = "OFFICIAL_PM_NO_AUCTION_WEEKEND";
      Strategy_LogCalendarStateOnce(date_key,
                                    detail,
                                    schedule_status,
                                    actual_status,
                                    current_utc,
                                    0,
                                    false);
      return false;
     }
   if(!QM_LbmaGoldPmAuctionStartUTC(date_key, scheduled_auction_utc) ||
      scheduled_auction_utc != confirmation1_utc)
     {
      Strategy_LogCalendarStateOnce(date_key,
                                    "PINNED_AUCTION_CLOCK_MISMATCH",
                                    schedule_status,
                                    actual_status,
                                    current_utc,
                                    scheduled_auction_utc,
                                    false);
      return false;
     }
   if(actual_status == QM_LBMA_GOLD_PM_ACTUAL_CANCELLED_OR_NO_PUBLICATION)
     {
      Strategy_LogCalendarStateOnce(date_key,
                                    "OFFICIAL_CANCELLATION_OR_NO_PUBLICATION",
                                    schedule_status,
                                    actual_status,
                                    current_utc,
                                    scheduled_auction_utc,
                                    false);
      return false;
     }
   Strategy_LogCalendarStateOnce(date_key,
                                 "PROVENANCE_LOCKED_SCHEDULED_PM_AUCTION",
                                 schedule_status,
                                 actual_status,
                                 current_utc,
                                 scheduled_auction_utc,
                                 true);

   MqlRates pre_bar;
   MqlRates confirmation1;
   MqlRates confirmation2;
   const int pre_shift = first_entry ? 2 : 3;
   const int confirmation1_shift = first_entry ? 1 : 2;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, pre_shift, pre_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, confirmation1_shift, confirmation1) ||
      QM_BrokerToUTC(pre_bar.time) != pre_bar_utc ||
      QM_BrokerToUTC(confirmation1.time) != confirmation1_utc)
     {
      Strategy_LogEntryRejected("AUCTION_BARS_INVALID", current_utc);
      return false;
     }
   if(second_entry &&
      (!QM_ReadBar(_Symbol, strategy_signal_tf, 1, confirmation2) ||
       QM_BrokerToUTC(confirmation2.time) != confirmation2_utc))
     {
      Strategy_LogEntryRejected("SECOND_CONFIRMATION_BAR_INVALID", current_utc);
      return false;
     }

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0 || pre_bar.high <= pre_bar.low)
     {
      Strategy_LogEntryRejected("AUCTION_PRICE_GEOMETRY_INVALID", current_utc);
      return false;
     }
   const long pre_open_ticks = (long)MathRound(pre_bar.open / tick_size);
   const long pre_close_ticks = (long)MathRound(pre_bar.close / tick_size);
   const long pre_high_ticks = (long)MathRound(pre_bar.high / tick_size);
   const long pre_low_ticks = (long)MathRound(pre_bar.low / tick_size);
   if(pre_high_ticks <= pre_low_ticks || pre_close_ticks == pre_open_ticks)
     {
      Strategy_LogEntryRejected("PRE_AUCTION_DOJI_OR_ZERO_RANGE", current_utc);
      return false;
     }

   const bool armed_long = (pre_close_ticks > pre_open_ticks);
   const double pre_high = Strategy_TickNormalizedPrice((double)pre_high_ticks * tick_size);
   const double pre_low = Strategy_TickNormalizedPrice((double)pre_low_ticks * tick_size);
   const double confirmation1_close = Strategy_TickNormalizedPrice(confirmation1.close);
   const int first_outcome = Strategy_ConfirmationOutcome(armed_long,
                                                           confirmation1_close,
                                                           pre_high,
                                                           pre_low);
   if(first_entry && first_outcome != 1)
     {
      Strategy_LogEntryRejected("FIRST_CONFIRMATION_NOT_QUALIFIED", current_utc);
      return false;
     }
   if(second_entry && first_outcome != 0)
     {
      Strategy_LogEntryRejected("FIRST_CONFIRMATION_RESOLVED_DATE", current_utc);
      return false;
     }
   if(second_entry)
     {
      const double confirmation2_close = Strategy_TickNormalizedPrice(confirmation2.close);
      if(Strategy_ConfirmationOutcome(armed_long, confirmation2_close, pre_high, pre_low) != 1)
        {
         Strategy_LogEntryRejected("SECOND_CONFIRMATION_NOT_QUALIFIED", current_utc);
         return false;
        }
     }

   if(Strategy_AttemptAlreadyMade(date_key, pre_bar_utc))
     {
      Strategy_LogEntryRejected("ATTEMPT_ALREADY_MADE", current_utc);
      return false;
     }
   g_last_attempt_date_key = date_key;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      Strategy_LogEntryRejected("MARKET_QUOTE_INVALID", current_utc);
      return false;
     }
   const double entry_price = armed_long ? ask : bid;
   const double stop_price = armed_long ? pre_low : pre_high;
   if(stop_price <= 0.0 ||
      (armed_long && entry_price <= stop_price) ||
      (!armed_long && entry_price >= stop_price) ||
      !Strategy_TradeGeometryAndVolumeAllow(entry_price, stop_price))
     {
      Strategy_LogEntryRejected("TRADE_GEOMETRY_OR_VOLUME_REJECTED", current_utc);
      return false;
     }

   req.type = armed_long ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = armed_long ? "LBMA_PM_BRK_LONG" : "LBMA_PM_BRK_SHORT";
   g_active_exit_broker = QM_UTCToBroker(exit_utc);
   if(g_active_exit_broker <= 0)
     {
      Strategy_LogEntryRejected("EXIT_CLOCK_INVALID", current_utc);
      return false;
     }
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"candidate_utc\":%I64d,\"entry\":%.8f,\"stop\":%.8f,\"exit_broker\":%I64d,\"schedule_status\":\"SCHEDULED_PM_AUCTION\",\"actual_status_evidence\":\"%s\",\"runtime_sha256\":\"%s\"}",
                            QM_LoggerEscapeJson(_Symbol),
                            armed_long ? "BUY" : "SELL",
                            (long)current_utc,
                            entry_price,
                            stop_price,
                            (long)g_active_exit_broker,
                            QM_LoggerEscapeJson(QM_LbmaGoldPmActualStatusName(actual_status)),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmRuntimeActualSha256())));
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const datetime open_utc = QM_BrokerToUTC(open_time);
      const int date_key = QM_LbmaGoldPmLondonDateKeyFromUTC(open_utc);
      datetime exit_utc = 0;
      if(QM_LbmaGoldPmLondonLocalToUTC(date_key,
                                       strategy_exit_hour_london,
                                       strategy_exit_minute_london,
                                       exit_utc))
         g_active_exit_broker = QM_UTCToBroker(exit_utc);
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The card keeps the framework's default news pause; this hook adds none.
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

   g_lbma_calendar_ready = QM_LbmaGoldPmCalendarLoad();
   QM_LogEvent(g_lbma_calendar_ready ? QM_INFO : QM_WARN,
               "LBMA_PM_CALENDAR_INIT",
               StringFormat("{\"ready\":%s,\"calendar_status\":\"%s\",\"verified_start\":%d,\"verified_end\":%d,\"runtime_file\":\"%s\",\"runtime_expected_sha256\":\"%s\",\"runtime_actual_sha256\":\"%s\",\"provenance_actual_sha256\":\"%s\",\"sources_actual_sha256\":\"%s\",\"transitions_actual_sha256\":\"%s\",\"gaps_actual_sha256\":\"%s\",\"manifest_actual_sha256\":\"%s\",\"error\":\"%s\"}",
                            g_lbma_calendar_ready ? "true" : "false",
                            QM_LBMA_GOLD_PM_CALENDAR_STATUS,
                            QM_LBMA_GOLD_PM_COVERAGE_START,
                            QM_LBMA_GOLD_PM_COVERAGE_END,
                            QM_LBMA_GOLD_PM_RUNTIME_FILE,
                            QM_LBMA_GOLD_PM_RUNTIME_SHA256,
                            QM_LoggerEscapeJson(QM_LbmaGoldPmRuntimeActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmProvenanceActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmSourcesActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmTransitionsActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmGapsActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmManifestActualSha256()),
                            QM_LoggerEscapeJson(QM_LbmaGoldPmCalendarLastError())));
   if(!g_lbma_calendar_ready)
      QM_LogEvent(QM_WARN,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"component\":\"lbma_gold_pm_schedule_package\",\"entry_gate\":\"FAIL_CLOSED\",\"detail\":\"%s\"}",
                               QM_LoggerEscapeJson(QM_LbmaGoldPmCalendarLastError())));
   else
      QM_LogEvent(QM_WARN,
                  "CALENDAR_EVIDENCE_GAP",
                  StringFormat("{\"component\":\"lbma_gold_pm_actual_occurrence\",\"detail\":\"%s\",\"technical_schedule_eligibility\":\"SCHEDULED_PM_AUCTION_ROWS_ADMITTED\",\"q02_promotion_status\":\"BLOCKED_PENDING_RECONCILIATION\"}",
                               QM_LBMA_GOLD_PM_ACTUAL_STATUS_POLICY));

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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
