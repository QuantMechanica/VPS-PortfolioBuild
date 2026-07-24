#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh> // basket EA (codex builder wiring, G0_REVIEW_T8)

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
input int    qm_ea_id                   = 20123;
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
input double strategy_sl_pips        = 10.0;
input double strategy_tp_pips        = 10.0;
input double strategy_basket_tp_pips = 10.0;

#define STR069_MEMBER_COUNT 2

string g_str069_symbols[STR069_MEMBER_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX"
  };
bool     g_str069_context_ready = false;
datetime g_str069_last_eval_day = 0;
datetime g_str069_last_data_log_bar = 0;
bool     g_str069_basket_close_latched = false;
datetime g_str069_last_close_attempt_bar = 0;

bool Strategy069_ConfigValid()
  {
   return (MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips > 0.0 &&
           MathIsValidNumber(strategy_tp_pips) &&
           strategy_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_basket_tp_pips) &&
           strategy_basket_tp_pips > 0.0);
  }

// This must be called from OnInit after QM_FrameworkInit. The hook calls it
// again defensively, but OnInit wiring is required so a restored foreign leg
// is already owned before the first kill-switch/Friday-close pass.
bool Strategy069_InitBasketContext()
  {
   if(g_str069_context_ready)
      return true;
   if(_Symbol != g_str069_symbols[0] ||
      _Period != PERIOD_H1)
      return false;

   QM_SymbolGuardInit(g_str069_symbols);
   QM_BasketWarmupHistory(g_str069_symbols,
                          PERIOD_H1,
                          72);
   QM_BasketWarmupHistory(g_str069_symbols,
                          PERIOD_D1,
                          5);

   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      const int magic =
         QM_MagicChecked(qm_ea_id,
                         slot,
                         g_str069_symbols[slot]);
      if(magic <= 0 ||
         !QM_KillSwitchRegisterMagic((long)magic))
         return false;
     }
   g_str069_context_ready = true;
   return true;
  }

void Strategy069_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str069_last_data_log_bar)
      return;
   g_str069_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-069\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

double Strategy069_TradeTick(const string symbol)
  {
   double tick =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy069_AlignPrice(const string symbol,
                              const double raw_price,
                              const int direction)
  {
   const double tick = Strategy069_TradeTick(symbol);
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(symbol, units * tick);
  }

bool Strategy069_StopsLegal(const string symbol,
                            const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double tick = Strategy069_TradeTick(symbol);
   const double bid =
      SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0 || tp <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
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

bool Strategy069_NewsAllowsMember(const string symbol,
                                  const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(symbol,
                             broker_time,
                             qm_news_mode_legacy);
  }

bool Strategy069_FindMemberPosition(const int slot,
                                    ulong &ticket,
                                    ENUM_POSITION_TYPE &position_type,
                                    double &open_price,
                                    double &market_price,
                                    double &pip)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   market_price = 0.0;
   pip = 0.0;
   if(slot < 0 || slot >= STR069_MEMBER_COUNT)
      return false;

   const string symbol = g_str069_symbols[slot];
   const int magic =
      QM_MagicChecked(qm_ea_id, slot, symbol);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      market_price =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(symbol, SYMBOL_BID)
         : SymbolInfoDouble(symbol, SYMBOL_ASK);
      pip =
         QM_StopRulesPipsToPriceDistance(symbol, 1);
      return true;
     }
   return false;
  }

bool Strategy069_HasAnyMemberPosition()
  {
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      ulong ticket = 0;
      ENUM_POSITION_TYPE position_type =
         POSITION_TYPE_BUY;
      double open_price = 0.0;
      double market_price = 0.0;
      double pip = 0.0;
      if(Strategy069_FindMemberPosition(slot,
                                        ticket,
                                        position_type,
                                        open_price,
                                        market_price,
                                        pip))
         return true;
     }
   return false;
  }

bool Strategy069_BuildRequest(const int slot,
                              const int direction,
                              const datetime day_time,
                              QM_BasketOrderRequest &request)
  {
   ZeroMemory(request);
   if(slot < 0 ||
      slot >= STR069_MEMBER_COUNT ||
      direction == 0)
      return false;

   const string symbol = g_str069_symbols[slot];
   const double bid =
      SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double pip =
      QM_StopRulesPipsToPriceDistance(symbol, 1);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0)
      return false;

   const bool is_long = (direction > 0);
   const double entry = is_long ? ask : bid;
   request.symbol = symbol;
   request.type = is_long ? QM_BUY : QM_SELL;
   request.price = 0.0;
   request.sl =
      Strategy069_AlignPrice(
         symbol,
         is_long
         ? entry - strategy_sl_pips * pip
         : entry + strategy_sl_pips * pip,
         is_long ? -1 : 1);
   request.tp =
      Strategy069_AlignPrice(
         symbol,
         is_long
         ? entry + strategy_tp_pips * pip
         : entry - strategy_tp_pips * pip,
         is_long ? 1 : -1);
   request.lots = 0.0;
   request.reason =
      StringFormat(is_long
                   ? "STR069_L_S%d_%I64d"
                   : "STR069_S_S%d_%I64d",
                   slot,
                   (long)day_time);
   request.symbol_slot = slot;
   request.expiration_seconds = 0;
   return Strategy069_StopsLegal(symbol,
                                 request.type,
                                 request.sl,
                                 request.tp);
  }

void Strategy069_AttemptBasketClose()
  {
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_H1,
                  0,
                  forming_bar))
     {
      Strategy069_LogDataMissing("basket_close_clock",
                                 0);
      return;
     }
   if(forming_bar.time ==
      g_str069_last_close_attempt_bar)
      return;
   g_str069_last_close_attempt_bar =
      forming_bar.time;

   int remaining = 0;
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      ulong ticket = 0;
      ENUM_POSITION_TYPE position_type =
         POSITION_TYPE_BUY;
      double open_price = 0.0;
      double market_price = 0.0;
      double pip = 0.0;
      if(!Strategy069_FindMemberPosition(slot,
                                         ticket,
                                         position_type,
                                         open_price,
                                         market_price,
                                         pip))
         continue;

      ++remaining;
      if(QM_TM_ClosePosition(ticket,
                             QM_EXIT_STRATEGY))
        {
         --remaining;
         QM_LogEvent(
            QM_INFO,
            "STRATEGY_EXIT",
            StringFormat(
               "{\"strategy\":\"STR-069\",\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"basket_tp\",\"retry_bar\":%I64d}",
               ticket,
               QM_LoggerEscapeJson(g_str069_symbols[slot]),
               (long)forming_bar.time));
        }
      else
        {
         QM_LogEvent(
            QM_WARN,
            "TM_PARTIAL_RETRY_DEFERRED",
            StringFormat(
               "{\"strategy\":\"STR-069\",\"ticket\":%I64u,\"symbol\":\"%s\",\"stage\":\"basket_close\",\"retry_after_bar\":%I64d}",
               ticket,
               QM_LoggerEscapeJson(g_str069_symbols[slot]),
               (long)forming_bar.time));
        }
     }

   if(remaining == 0 &&
      !Strategy069_HasAnyMemberPosition())
     {
      g_str069_basket_close_latched = false;
      g_str069_last_close_attempt_bar = 0;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      _Symbol != g_str069_symbols[0] ||
      !Strategy069_ConfigValid() ||
      !Strategy069_InitBasketContext())
      return true;

   // Management of a one-leg remainder must never be blocked by an entry
   // warmup check.
   if(Strategy069_HasAnyMemberPosition())
      return false;

   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      const string symbol = g_str069_symbols[slot];
      if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_MODE) ==
         SYMBOL_TRADE_MODE_DISABLED)
         return true;
      if(SeriesInfoInteger(symbol,
                           PERIOD_H1,
                           SERIES_BARS_COUNT) < 3 ||
         SeriesInfoInteger(symbol,
                           PERIOD_D1,
                           SERIES_BARS_COUNT) < 2)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // No order is returned through the host-only skeleton path. Both member
   // orders are prepared first, then placed through QM_BasketOrder below.
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy069_InitBasketContext())
      return false;

   MqlRates host_d1;
   MqlRates host_h1;
   if(!QM_ReadBar(g_str069_symbols[0],
                  PERIOD_D1,
                  0,
                  host_d1) ||
      !QM_ReadBar(g_str069_symbols[0],
                  PERIOD_H1,
                  1,
                  host_h1))
     {
      Strategy069_LogDataMissing("host_daily_cycle",
                                 0);
      return false;
     }

   // The just-closed H1 bar must be the first H1 bar of the broker day.
   if(host_h1.time != host_d1.time ||
      host_d1.time == g_str069_last_eval_day)
      return false;
   g_str069_last_eval_day = host_d1.time;

   if(Strategy069_HasAnyMemberPosition())
      return false;

   int directions[STR069_MEMBER_COUNT] = {0, 0};
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      MqlRates member_d1;
      MqlRates member_h1;
      if(!QM_ReadBar(g_str069_symbols[slot],
                     PERIOD_D1,
                     0,
                     member_d1) ||
         !QM_ReadBar(g_str069_symbols[slot],
                     PERIOD_H1,
                     1,
                     member_h1) ||
         member_d1.time != host_d1.time ||
         member_h1.time != member_d1.time)
        {
         Strategy069_LogDataMissing(
            StringFormat("member_%d_first_hour",
                         slot),
            host_d1.time);
         return false;
        }

      if(member_h1.close > member_d1.open)
         directions[slot] = 1;
      else if(member_h1.close < member_d1.open)
         directions[slot] = -1;
     }

   QM_BasketOrderRequest requests[STR069_MEMBER_COUNT];
   int planned = 0;
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      if(directions[slot] == 0)
         continue;
      if(!Strategy069_BuildRequest(
            slot,
            directions[slot],
            host_d1.time,
            requests[planned]))
        {
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-069\",\"reason\":\"member_stop_geometry\",\"slot\":%d,\"day_time\":%I64d}",
               slot,
               (long)host_d1.time));
         return false;
        }
      ++planned;
     }
   if(planned == 0)
      return false;

   const datetime broker_time = TimeCurrent();
   for(int i = 0; i < planned; ++i)
     {
      if(!Strategy069_NewsAllowsMember(
            requests[i].symbol,
            broker_time))
         return false;

      // QM_BasketOrder predates QM_Entry's Q06 rejection rail. Mirror the
      // central seeded rejection before any leg is opened so a stress drop
      // cannot leave an unintended half-basket.
      if(qm_stress_reject_probability > 0.0 &&
         QM_RandBoolTagged("entry_reject",
                           qm_stress_reject_probability))
        {
         QM_LogEvent(
            QM_WARN,
            "BASKET_ORDER_REJECTED",
            StringFormat(
               "{\"result\":\"QM_BASKET_REJECTED_STRESS\",\"host_symbol\":\"%s\",\"symbol\":\"%s\",\"reason\":\"%s\",\"symbol_slot\":%d}",
               QM_LoggerEscapeJson(_Symbol),
               QM_LoggerEscapeJson(requests[i].symbol),
               QM_LoggerEscapeJson(requests[i].reason),
               requests[i].symbol_slot));
         return false;
        }
     }

   ulong opened_tickets[STR069_MEMBER_COUNT] = {0, 0};
   int opened = 0;
   for(int i = 0; i < planned; ++i)
     {
      ulong ticket = 0;
      if(!QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                20,
                                requests[i],
                                ticket))
         break;
      opened_tickets[opened] = ticket;
      ++opened;
     }

   if(opened != planned)
     {
      int rolled_back = 0;
      for(int i = 0; i < opened; ++i)
        {
         if(opened_tickets[i] > 0 &&
            QM_TM_ClosePosition(opened_tickets[i],
                                QM_EXIT_STRATEGY))
            ++rolled_back;
        }
      QM_LogEvent(
         QM_WARN,
         "BASKET_PARTIAL_ABORT",
         StringFormat(
            "{\"strategy\":\"STR-069\",\"attempted\":%d,\"opened\":%d,\"rolled_back\":%d,\"day_time\":%I64d}",
            planned,
            opened,
            rolled_back,
            (long)host_d1.time));
      return false;
     }

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-069\",\"reason\":\"daily_first_hour_basket\",\"legs\":%d,\"day_time\":%I64d,\"slot0_dir\":%d,\"slot1_dir\":%d}",
         opened,
         (long)host_d1.time,
         directions[0],
         directions[1]));
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!Strategy069_InitBasketContext())
      return;

   if(g_str069_basket_close_latched)
     {
      if(!Strategy069_HasAnyMemberPosition())
        {
         g_str069_basket_close_latched = false;
         g_str069_last_close_attempt_bar = 0;
         return;
        }
      Strategy069_AttemptBasketClose();
      return;
     }

   ulong tickets[STR069_MEMBER_COUNT] = {0, 0};
   ENUM_POSITION_TYPE position_types[STR069_MEMBER_COUNT] =
     {
      POSITION_TYPE_BUY,
      POSITION_TYPE_BUY
     };
   double open_prices[STR069_MEMBER_COUNT] = {0.0, 0.0};
   double market_prices[STR069_MEMBER_COUNT] = {0.0, 0.0};
   double pips[STR069_MEMBER_COUNT] = {0.0, 0.0};
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      if(!Strategy069_FindMemberPosition(
           slot,
           tickets[slot],
           position_types[slot],
           open_prices[slot],
           market_prices[slot],
           pips[slot]) ||
         open_prices[slot] <= 0.0 ||
         market_prices[slot] <= 0.0 ||
         pips[slot] <= 0.0)
         return;
     }

   double combined_pips = 0.0;
   for(int slot = 0; slot < STR069_MEMBER_COUNT; ++slot)
     {
      const double movement =
         (position_types[slot] == POSITION_TYPE_BUY)
         ? market_prices[slot] - open_prices[slot]
         : open_prices[slot] - market_prices[slot];
      combined_pips += movement / pips[slot];
     }
   // Floating quote arithmetic can represent an exact 10-pip sum a few
   // ulps below 10. Treat only a material shortfall as below threshold.
   if(combined_pips + 1e-8 <
      strategy_basket_tp_pips)
      return;

   g_str069_basket_close_latched = true;
   g_str069_last_close_attempt_bar = 0;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-069\",\"reason\":\"basket_tp_trigger\",\"combined_pips\":%.8f,\"target_pips\":%.8f}",
         combined_pips,
         strategy_basket_tp_pips));
   Strategy069_AttemptBasketClose();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Defensive first-tick initialization before the framework Friday-close
   // sweep. The required OnInit call above remains authoritative.
   Strategy069_InitBasketContext();
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

   if(!Strategy069_InitBasketContext())
      return INIT_FAILED; // basket wiring (codex builder contract, G0_REVIEW_T8)

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
