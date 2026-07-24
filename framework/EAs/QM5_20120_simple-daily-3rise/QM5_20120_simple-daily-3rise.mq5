#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

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
input int    qm_ea_id                   = 20120;
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
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
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
input double strategy_sl_buffer_pips = 2.0;
input double strategy_sl_max_pips    = 90.0;
input double strategy_p1_tp_pips     = 30.0;
input double strategy_p2_tp_pips     = 100.0;

datetime g_str058_last_entry_bar = 0;
datetime g_str058_last_partial_attempt_bar = 0;
datetime g_str058_last_be_attempt_bar = 0;
datetime g_str058_last_data_log_bar = 0;
ulong    g_str058_campaign_ticket = 0;
double   g_str058_initial_volume = 0.0;
bool     g_str058_partial_done = false;
bool     g_str058_breakeven_done = false;

bool Strategy058_ConfigValid()
  {
   return (MathIsValidNumber(strategy_sl_buffer_pips) &&
           strategy_sl_buffer_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_max_pips) &&
           strategy_sl_max_pips > 0.0 &&
           MathIsValidNumber(strategy_p1_tp_pips) &&
           strategy_p1_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_p2_tp_pips) &&
           strategy_p2_tp_pips > strategy_p1_tp_pips);
  }

bool Strategy058_CurrentBar(datetime &bar_time)
  {
   bar_time = 0;
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, forming_bar))
      return false;
   bar_time = forming_bar.time;
   return (bar_time > 0);
  }

void Strategy058_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str058_last_data_log_bar)
      return;
   g_str058_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-058\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy058_HasOwnPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &volume,
                                datetime &position_time,
                                ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   volume = 0.0;
   position_time = 0;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy058_CampaignOpenedSince(const datetime since_time)
  {
   if(since_time <= 0 ||
      !HistorySelect(since_time, TimeCurrent()))
      return false;
   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,
                                                DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN ||
         entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

double Strategy058_ReplayInitialVolume(const ulong position_id,
                                       const datetime position_time)
  {
   if(position_id == 0)
      return 0.0;
   const datetime history_from =
      (position_time > 86400)
      ? position_time - 86400
      : 0;
   if(!HistorySelect(history_from, TimeCurrent()))
      return 0.0;

   const int magic = QM_FrameworkMagic();
   double opened_volume = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (ulong)HistoryDealGetInteger(deal,
                                      DEAL_POSITION_ID) !=
            position_id ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,
                                                DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN ||
         entry == DEAL_ENTRY_INOUT)
         opened_volume +=
            HistoryDealGetDouble(deal, DEAL_VOLUME);
     }
   return opened_volume;
  }

double Strategy058_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy058_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy058_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool Strategy058_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy058_TradeTick();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0 || tp <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(side == QM_BUY)
      return (sl < bid && tp > ask &&
              bid - sl + tick * 0.1 >= minimum &&
              tp - ask + tick * 0.1 >= minimum);
   if(side == QM_SELL)
      return (sl > ask && tp < bid &&
              sl - ask + tick * 0.1 >= minimum &&
              bid - tp + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy058_StopLegal(const ENUM_POSITION_TYPE position_type,
                           const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy058_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy058_StopAtBreakeven(
   const ENUM_POSITION_TYPE position_type,
   const double open_price,
   const double current_sl)
  {
   const double tick = Strategy058_TradeTick();
   if(open_price <= 0.0 || current_sl <= 0.0 || tick <= 0.0)
      return false;
   if(position_type == POSITION_TYPE_BUY)
      return (current_sl >= open_price - tick * 0.5);
   return (current_sl <= open_price + tick * 0.5);
  }

void Strategy058_SyncCampaign(
   const ulong ticket,
   const ENUM_POSITION_TYPE position_type,
   const double open_price,
   const double current_volume,
   const double current_sl,
   const datetime position_time,
   const ulong position_id)
  {
   if(ticket != g_str058_campaign_ticket)
     {
      g_str058_campaign_ticket = ticket;
      g_str058_initial_volume =
         Strategy058_ReplayInitialVolume(position_id,
                                         position_time);
      if(g_str058_initial_volume <= 0.0)
         g_str058_initial_volume = current_volume;
      const bool volume_reduced =
         (g_str058_initial_volume > 0.0 &&
          current_volume <
             0.995 * g_str058_initial_volume);
      const bool stop_at_be =
         Strategy058_StopAtBreakeven(position_type,
                                     open_price,
                                     current_sl);
      g_str058_partial_done =
         (volume_reduced || stop_at_be);
      g_str058_breakeven_done = stop_at_be;
      g_str058_last_partial_attempt_bar = 0;
      g_str058_last_be_attempt_bar = 0;
     }
   else
     {
      if(g_str058_initial_volume > 0.0 &&
         current_volume <
            0.995 * g_str058_initial_volume)
         g_str058_partial_done = true;
      if(Strategy058_StopAtBreakeven(position_type,
                                     open_price,
                                     current_sl))
         g_str058_breakeven_done = true;
     }
  }

void Strategy058_ResetCampaign()
  {
   g_str058_campaign_ticket = 0;
   g_str058_initial_volume = 0.0;
   g_str058_partial_done = false;
   g_str058_breakeven_done = false;
   g_str058_last_partial_attempt_bar = 0;
   g_str058_last_be_attempt_bar = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1 ||
      !Strategy058_ConfigValid())
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_D1,
                        SERIES_BARS_COUNT);
   return (bars_available < 6);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy058_CurrentBar(forming_time))
     {
      Strategy058_LogDataMissing("forming_d1_bar", 0);
      return false;
     }
   if(forming_time == g_str058_last_entry_bar)
      return false;
   g_str058_last_entry_bar = forming_time;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(Strategy058_HasOwnPosition(ticket,
                                 position_type,
                                 open_price,
                                 current_sl,
                                 current_volume,
                                 position_time,
                                 position_id) ||
      Strategy058_CampaignOpenedSince(forming_time))
      return false;

   MqlRates bar1;
   MqlRates bar2;
   MqlRates bar3;
   MqlRates bar4;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 2, bar2) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 3, bar3) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 4, bar4))
     {
      Strategy058_LogDataMissing("relative_d1_bars",
                                 forming_time);
      return false;
     }

   const bool long_signal =
      (bar1.open > bar2.open &&
       bar1.close > bar2.close &&
       bar2.open > bar3.open &&
       bar2.close > bar3.close &&
       bar3.open > bar4.open &&
       bar3.close > bar4.close);
   const bool short_signal =
      (bar1.open < bar2.open &&
       bar1.close < bar2.close &&
       bar2.open < bar3.open &&
       bar2.close < bar3.close &&
       bar3.open < bar4.open &&
       bar3.close < bar4.close);
   if(!long_signal && !short_signal)
      return false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0)
     {
      Strategy058_LogDataMissing("market_or_pip_metadata",
                                 forming_time);
      return false;
     }

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   const double structure_stop =
      long_signal
      ? bar1.low - strategy_sl_buffer_pips * pip
      : bar1.high + strategy_sl_buffer_pips * pip;
   const double structure_distance =
      long_signal
      ? entry - structure_stop
      : structure_stop - entry;
   const double maximum_distance =
      strategy_sl_max_pips * pip;
   if(structure_distance <= 0.0 ||
      maximum_distance <= 0.0)
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-058\",\"reason\":\"gap_through_structure_stop\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"structure_stop\":%.8f}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)forming_time,
            entry,
            structure_stop));
      return false;
     }

   const double stop_distance =
      MathMin(structure_distance, maximum_distance);
   const double raw_sl =
      long_signal
      ? entry - stop_distance
      : entry + stop_distance;
   const double raw_tp =
      long_signal
      ? entry + strategy_p2_tp_pips * pip
      : entry - strategy_p2_tp_pips * pip;
   req.sl =
      Strategy058_AlignPrice(raw_sl,
                             long_signal ? -1 : 1);
   req.tp =
      Strategy058_AlignPrice(raw_tp,
                             long_signal ? 1 : -1);
   if(!Strategy058_StopsLegal(req.type,
                              req.sl,
                              req.tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-058\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)forming_time,
            entry,
            req.sl,
            req.tp));
      return false;
     }

   req.price = 0.0;
   req.reason =
      StringFormat(long_signal
                   ? "STR058_L_%I64d"
                   : "STR058_S_%I64d",
                   (long)forming_time);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-058\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"structure_stop\":%.8f,\"stop_distance\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         QM_LoggerEscapeJson(
            long_signal ? "LONG" : "SHORT"),
         (long)forming_time,
         entry,
         structure_stop,
         stop_distance,
         req.sl,
         req.tp));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(!Strategy058_HasOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_volume,
                                  position_time,
                                  position_id))
     {
      Strategy058_ResetCampaign();
      return;
     }

   Strategy058_SyncCampaign(ticket,
                            position_type,
                            open_price,
                            current_volume,
                            current_sl,
                            position_time,
                            position_id);
   datetime forming_time = 0;
   if(!Strategy058_CurrentBar(forming_time))
     {
      Strategy058_LogDataMissing("manage_d1_bar", 0);
      return;
     }

   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(!g_str058_partial_done && pip > 0.0)
     {
      const double market =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool at_p1 =
         (market > 0.0) &&
         (position_type == POSITION_TYPE_BUY
          ? market >=
             open_price + strategy_p1_tp_pips * pip
          : market <=
             open_price - strategy_p1_tp_pips * pip);
      if(at_p1 &&
         forming_time !=
            g_str058_last_partial_attempt_bar)
        {
         g_str058_last_partial_attempt_bar =
            forming_time;
         const double requested =
            g_str058_initial_volume * 0.5;
         const double close_volume =
            QM_TM_NormalizeVolume(_Symbol, requested);
         const double min_volume =
            SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(close_volume <= 0.0 ||
            close_volume >= current_volume ||
            current_volume - close_volume + 1e-10 <
               min_volume)
           {
            QM_LogEvent(
               QM_WARN,
               "SETUP_CONFIG_INVALID",
               StringFormat(
                  "{\"strategy\":\"STR-058\",\"reason\":\"half_volume\",\"ticket\":%I64u,\"initial_volume\":%.8f,\"current_volume\":%.8f,\"requested_close\":%.8f}",
                  ticket,
                  g_str058_initial_volume,
                  current_volume,
                  requested));
           }
         else if(QM_TM_PartialClose(ticket,
                                    close_volume,
                                    QM_EXIT_PARTIAL))
           {
            g_str058_partial_done = true;
            QM_LogEvent(
               QM_INFO,
               "STRATEGY_EXIT",
               StringFormat(
                  "{\"strategy\":\"STR-058\",\"ticket\":%I64u,\"reason\":\"half_at_30p\",\"closed_volume\":%.8f,\"initial_volume\":%.8f}",
                  ticket,
                  close_volume,
                  g_str058_initial_volume));
           }
         else
           {
            QM_LogEvent(
               QM_WARN,
               "TM_PARTIAL_RETRY_DEFERRED",
               StringFormat(
                  "{\"strategy\":\"STR-058\",\"ticket\":%I64u,\"stage\":\"half_close\",\"retry_after_bar\":%I64d}",
                  ticket,
                  (long)forming_time));
           }
        }
     }

   if(!g_str058_partial_done ||
      g_str058_breakeven_done ||
      forming_time == g_str058_last_be_attempt_bar)
      return;
   g_str058_last_be_attempt_bar = forming_time;
   const double be =
      Strategy058_AlignPrice(
         open_price,
         position_type == POSITION_TYPE_BUY ? -1 : 1);
   if(be > 0.0 &&
      Strategy058_StopLegal(position_type, be) &&
      QM_TM_MoveSL(ticket, be, "STR058_HALF_BE"))
     {
      g_str058_breakeven_done = true;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-058\",\"ticket\":%I64u,\"reason\":\"breakeven_armed\",\"sl\":%.8f}",
            ticket,
            be));
     }
   else
     {
      QM_LogEvent(
         QM_WARN,
         "TM_PARTIAL_RETRY_DEFERRED",
         StringFormat(
            "{\"strategy\":\"STR-058\",\"ticket\":%I64u,\"stage\":\"breakeven_move\",\"retry_after_bar\":%I64d}",
            ticket,
            (long)forming_time));
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

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
