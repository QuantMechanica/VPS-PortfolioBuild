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
input int    qm_ea_id                   = 20101;
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
input int strategy_ema_period = 100;
input int strategy_session_start_gmt = 6;
input int strategy_session_hours = 9;

int g_str002_h_ema = INVALID_HANDLE;
datetime g_str002_last_entry_bar = 0;
datetime g_str002_last_trail_bar = 0;
datetime g_str002_last_partial_attempt_bar = 0;
datetime g_str002_last_data_log_bar = 0;
ulong g_str002_campaign_ticket = 0;
double g_str002_initial_volume = 0.0;
double g_str002_initial_sl = 0.0;
bool g_str002_partial_done = false;

bool Strategy002_EnsureHandle()
  {
   if(g_str002_h_ema == INVALID_HANDLE)
      g_str002_h_ema = QM_IndMA(_Symbol,
                                PERIOD_H1,
                                strategy_ema_period,
                                MODE_EMA,
                                PRICE_CLOSE);
   return (g_str002_h_ema != INVALID_HANDLE);
  }

bool Strategy002_CurrentBarTime(datetime &bar_time)
  {
   bar_time = 0;
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 0, forming_bar))
      return false;
   bar_time = forming_bar.time;
   return (bar_time > 0);
  }

void Strategy002_LogDataMissing(const string component)
  {
   datetime bar_time = 0;
   Strategy002_CurrentBarTime(bar_time);
   if(bar_time > 0 && bar_time == g_str002_last_data_log_bar)
      return;
   g_str002_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-002\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

double Strategy002_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy002_NormalizeStop(const ENUM_POSITION_TYPE position_type,
                                 const double raw_price)
  {
   const double tick = Strategy002_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   const double aligned =
      (position_type == POSITION_TYPE_BUY)
      ? MathFloor(scaled + 1e-9) * tick
      : MathCeil(scaled - 1e-9) * tick;
   return QM_TM_NormalizePrice(_Symbol, aligned);
  }

bool Strategy002_StopLegal(const ENUM_POSITION_TYPE position_type,
                           const double candidate)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(point, (double)stops_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && candidate < bid &&
              bid - candidate + point * 0.1 >= minimum);
     }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 && candidate > ask &&
           candidate - ask + point * 0.1 >= minimum);
  }

bool Strategy002_LoadHA(double &ha_open[],
                        double &ha_high[],
                        double &ha_low[],
                        double &ha_close[])
  {
   const int bars_needed = 150;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Caller reaches this fixed window only after an owned H1 bar gate.
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_needed, rates); // perf-allowed: bounded 150-bar HA recursion
   if(copied < bars_needed)
      return false;

   if(ArrayResize(ha_open, copied) != copied ||
      ArrayResize(ha_high, copied) != copied ||
      ArrayResize(ha_low, copied) != copied ||
      ArrayResize(ha_close, copied) != copied)
      return false;
   ArraySetAsSeries(ha_open, true);
   ArraySetAsSeries(ha_high, true);
   ArraySetAsSeries(ha_low, true);
   ArraySetAsSeries(ha_close, true);

   double prior_ha_open = 0.0;
   double prior_ha_close = 0.0;
   for(int i = copied - 1; i >= 0; --i)
     {
      const double raw_open = rates[i].open;
      const double raw_high = rates[i].high;
      const double raw_low = rates[i].low;
      const double raw_close = rates[i].close;
      if(raw_open <= 0.0 || raw_high <= 0.0 || raw_low <= 0.0 ||
         raw_close <= 0.0 || raw_high < raw_low)
         return false;

      const double next_ha_close =
         (raw_open + raw_high + raw_low + raw_close) * 0.25;
      const double next_ha_open =
         (i == copied - 1)
         ? (raw_open + raw_close) * 0.5
         : (prior_ha_open + prior_ha_close) * 0.5;
      ha_open[i] = next_ha_open;
      ha_close[i] = next_ha_close;
      ha_high[i] =
         MathMax(raw_high, MathMax(next_ha_open, next_ha_close));
      ha_low[i] =
         MathMin(raw_low, MathMin(next_ha_open, next_ha_close));
      prior_ha_open = next_ha_open;
      prior_ha_close = next_ha_close;
     }
   return true;
  }

int Strategy002_HAColor(const double &ha_open[],
                        const double &ha_close[],
                        const int closed_shift)
  {
   const int index = closed_shift - 1;
   if(index < 0 || index >= ArraySize(ha_open) ||
      index >= ArraySize(ha_close))
      return 0;
   if(ha_close[index] > ha_open[index])
      return 1;
   if(ha_close[index] < ha_open[index])
      return -1;
   return 0;
  }

bool Strategy002_HasOwnPosition(ulong &ticket,
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
      if(candidate == 0 || !PositionSelectByTicket(candidate))
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
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

double Strategy002_ReplayInitialVolume(const ulong position_id,
                                       const datetime position_time)
  {
   if(position_id == 0)
      return 0.0;
   const datetime history_from =
      (position_time > 86400) ? position_time - 86400 : 0;
   if(!HistorySelect(history_from, TimeCurrent()))
      return 0.0;

   const int magic = QM_FrameworkMagic();
   double opened_volume = 0.0;
   const int deal_count = HistoryDealsTotal();
   for(int i = 0; i < deal_count; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
         opened_volume += HistoryDealGetDouble(deal, DEAL_VOLUME);
     }
   return opened_volume;
  }

void Strategy002_SyncCampaign(const ulong ticket,
                              const double current_volume,
                              const double current_sl,
                              const datetime position_time,
                              const ulong position_id)
  {
   if(ticket != g_str002_campaign_ticket)
     {
      g_str002_campaign_ticket = ticket;
      g_str002_initial_volume =
         Strategy002_ReplayInitialVolume(position_id, position_time);
      if(g_str002_initial_volume <= 0.0)
         g_str002_initial_volume = current_volume;
      g_str002_initial_sl = current_sl;
      g_str002_partial_done =
         (g_str002_initial_volume > 0.0 &&
          current_volume < 0.995 * g_str002_initial_volume);
      g_str002_last_partial_attempt_bar = 0;
      g_str002_last_trail_bar = 0;
     }
   else if(g_str002_initial_volume > 0.0 &&
           current_volume < 0.995 * g_str002_initial_volume)
      g_str002_partial_done = true;
  }

void Strategy002_ResetCampaign()
  {
   g_str002_campaign_ticket = 0;
   g_str002_initial_volume = 0.0;
   g_str002_initial_sl = 0.0;
   g_str002_partial_done = false;
   g_str002_last_partial_attempt_bar = 0;
   g_str002_last_trail_bar = 0;
  }

bool Strategy002_SessionAllows(const datetime broker_bar_open)
  {
   const datetime utc_bar_open = QM_BrokerToUTC(broker_bar_open);
   if(utc_bar_open <= 0)
      return false;
   MqlDateTime utc_parts;
   TimeToStruct(utc_bar_open, utc_parts);
   const int seconds =
      utc_parts.hour * 3600 + utc_parts.min * 60 + utc_parts.sec;
   const int start = strategy_session_start_gmt * 3600;
   const int length = strategy_session_hours * 3600;
   if(length >= 86400)
      return true;
   const int end = start + length;
   if(end <= 86400)
      return (seconds >= start && seconds < end);
   return (seconds >= start || seconds < end - 86400);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      strategy_ema_period <= 1 ||
      strategy_session_start_gmt < 0 ||
      strategy_session_start_gmt >= 24 ||
      strategy_session_hours < 1 ||
      strategy_session_hours > 24)
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const int indicator_needed = strategy_ema_period + 5;
   const int warmup_needed =
      (indicator_needed > 150) ? indicator_needed : 150;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_H1, SERIES_BARS_COUNT);
   if(bars_available < warmup_needed)
      return true;
   if(!Strategy002_EnsureHandle())
      return true;
   return (BarsCalculated(g_str002_h_ema) < indicator_needed);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy002_CurrentBarTime(forming_time))
     {
      Strategy002_LogDataMissing("forming_bar");
      return false;
     }
   if(forming_time == g_str002_last_entry_bar)
      return false;
   g_str002_last_entry_bar = forming_time;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(Strategy002_HasOwnPosition(ticket,
                                 position_type,
                                 open_price,
                                 current_sl,
                                 volume,
                                 position_time,
                                 position_id))
      return false;

   if(!Strategy002_EnsureHandle())
     {
      Strategy002_LogDataMissing("ema_handle");
      return false;
     }
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, signal_bar))
     {
      Strategy002_LogDataMissing("signal_bar");
      return false;
     }
   if(!Strategy002_SessionAllows(signal_bar.time))
      return false;

   double ha_open[];
   double ha_high[];
   double ha_low[];
   double ha_close[];
   if(!Strategy002_LoadHA(ha_open, ha_high, ha_low, ha_close))
     {
      Strategy002_LogDataMissing("heiken_ashi");
      return false;
     }
   const double ema1 =
      QM_IndicatorReadBuffer(g_str002_h_ema, 0, 1);
   if(ema1 <= 0.0)
     {
      Strategy002_LogDataMissing("ema_buffer");
      return false;
     }

   const int color1 = Strategy002_HAColor(ha_open, ha_close, 1);
   const int color2 = Strategy002_HAColor(ha_open, ha_close, 2);
   const bool long_signal =
      (color2 == -1 && color1 == 1 && signal_bar.close > ema1);
   const bool short_signal =
      (color2 == 1 && color1 == -1 && signal_bar.close < ema1);
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const ENUM_POSITION_TYPE requested_position_type =
      long_signal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double tick = Strategy002_TradeTick();
   if(entry <= 0.0 || tick <= 0.0)
     {
      Strategy002_LogDataMissing("market_price_or_tick");
      return false;
     }
   const double raw_sl =
      long_signal ? ha_low[0] - tick : ha_high[0] + tick;
   const double sl =
      Strategy002_NormalizeStop(requested_position_type, raw_sl);
   if(sl <= 0.0 ||
      (long_signal && sl >= entry) ||
      (short_signal && sl <= entry) ||
      !Strategy002_StopLegal(requested_position_type, sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-002\",\"reason\":\"initial_sl\",\"dir\":\"%s\",\"entry\":%.8f,\"sl\":%.8f}",
            long_signal ? "LONG" : "SHORT",
            entry,
            sl));
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      long_signal ? "STR002_SIMP_LONG" : "STR002_SIMP_SHORT";
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-002\",\"dir\":\"%s\",\"close\":%.8f,\"ema\":%.8f,\"ha_low\":%.8f,\"ha_high\":%.8f,\"sl\":%.8f}",
         long_signal ? "LONG" : "SHORT",
         signal_bar.close,
         ema1,
         ha_low[0],
         ha_high[0],
         sl));
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
   if(!Strategy002_HasOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_volume,
                                  position_time,
                                  position_id))
     {
      Strategy002_ResetCampaign();
      return;
     }
   Strategy002_SyncCampaign(ticket,
                            current_volume,
                            current_sl,
                            position_time,
                            position_id);

   datetime forming_time = 0;
   if(!Strategy002_CurrentBarTime(forming_time))
     {
      Strategy002_LogDataMissing("manage_bar");
      return;
     }

   if(!g_str002_partial_done &&
      open_price > 0.0 &&
      g_str002_initial_sl > 0.0)
     {
      const double initial_r =
         MathAbs(open_price - g_str002_initial_sl);
      const double market =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool at_one_r =
         (initial_r > 0.0 && market > 0.0) &&
         (position_type == POSITION_TYPE_BUY
          ? market >= open_price + initial_r
          : market <= open_price - initial_r);
      if(at_one_r &&
         forming_time != g_str002_last_partial_attempt_bar)
        {
         g_str002_last_partial_attempt_bar = forming_time;
         const double requested =
            g_str002_initial_volume * (2.0 / 3.0);
         const double close_volume =
            QM_TM_NormalizeVolume(_Symbol, requested);
         const double min_volume =
            SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(close_volume <= 0.0 ||
            close_volume >= current_volume ||
            current_volume - close_volume + 1e-10 < min_volume)
           {
            QM_LogEvent(
               QM_WARN,
               "SETUP_CONFIG_INVALID",
               StringFormat(
                  "{\"strategy\":\"STR-002\",\"reason\":\"partial_volume\",\"ticket\":%I64u,\"initial_volume\":%.8f,\"current_volume\":%.8f,\"requested_close\":%.8f}",
                  ticket,
                  g_str002_initial_volume,
                  current_volume,
                  requested));
           }
         else if(QM_TM_PartialClose(ticket,
                                    close_volume,
                                    QM_EXIT_PARTIAL))
           {
            g_str002_partial_done = true;
            QM_LogEvent(
               QM_INFO,
               "STRATEGY_EXIT",
               StringFormat(
                  "{\"strategy\":\"STR-002\",\"ticket\":%I64u,\"reason\":\"tranche_ab_1r\",\"closed_volume\":%.8f,\"initial_volume\":%.8f}",
                  ticket,
                  close_volume,
                  g_str002_initial_volume));
           }
         else
           {
            QM_LogEvent(
               QM_WARN,
               "TM_PARTIAL_RETRY_DEFERRED",
               StringFormat(
                  "{\"strategy\":\"STR-002\",\"ticket\":%I64u,\"retry_after_bar\":%I64d}",
                  ticket,
                  (long)forming_time));
           }
        }
     }

   if(!g_str002_partial_done ||
      forming_time == g_str002_last_trail_bar)
      return;
   g_str002_last_trail_bar = forming_time;

   double ha_open[];
   double ha_high[];
   double ha_low[];
   double ha_close[];
   if(!Strategy002_LoadHA(ha_open, ha_high, ha_low, ha_close))
     {
      Strategy002_LogDataMissing("heiken_ashi_trail");
      return;
     }
   if(!PositionSelectByTicket(ticket))
      return;
   current_sl = PositionGetDouble(POSITION_SL);
   const double tick = Strategy002_TradeTick();
   const double raw_candidate =
      (position_type == POSITION_TYPE_BUY)
      ? ha_low[0] - tick
      : ha_high[0] + tick;
   const double candidate =
      Strategy002_NormalizeStop(position_type, raw_candidate);
   if(candidate <= 0.0 || tick <= 0.0)
      return;
   const bool improves =
      (current_sl <= 0.0) ||
      (position_type == POSITION_TYPE_BUY
       ? candidate > current_sl + tick * 0.5
       : candidate < current_sl - tick * 0.5);
   if(!improves)
      return;
   if(!Strategy002_StopLegal(position_type, candidate))
     {
      QM_LogEvent(
         QM_INFO,
         "TM_MODIFY_SKIPPED",
         StringFormat(
            "{\"strategy\":\"STR-002\",\"ticket\":%I64u,\"reason\":\"ha_trail_stops_level\",\"candidate\":%.8f}",
            ticket,
            candidate));
      return;
     }
   QM_TM_MoveSL(ticket, candidate, "STR002_HA_RUNNER_RATCHET");
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
