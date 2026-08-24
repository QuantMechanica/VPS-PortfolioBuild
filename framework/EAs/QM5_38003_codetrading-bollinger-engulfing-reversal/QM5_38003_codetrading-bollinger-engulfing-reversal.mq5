#property strict
#property version   "5.0"
#property description "CodeTrading Bollinger Engulfing Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38003;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
// The card's InpRiskPercent is represented by this governed framework input.
// Backtests keep it at zero; a future OWNER-approved live setfile supplies 0.50.
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpBBPeriod  = 20;
input double InpBBDev     = 2.0;
input int    InpRSIPeriod = 14;
input double InpDailyLossHaltPct       = 2.0;
input double InpDailyDrawdownStopPct   = 2.5;
input double InpTotalDrawdownStopPct   = 5.0;

const double CARD_LONG_RSI_MAX             = 35.0;
const double CARD_SHORT_RSI_MIN            = 65.0;
const double CARD_SPREAD_ATR_MULT           = 1.8;
const int    CARD_ATR_PERIOD                = 14;
const int    CARD_SL_BUFFER_PIPS            = 2;
const double CARD_REWARD_RISK               = 2.0;
const double CARD_MIDDLE_CLOSE_FRACTION     = 0.5;
const int    CARD_MAX_OPEN_POSITIONS        = 1;
const int    CARD_MAX_SLIPPAGE_TICKS        = 3;

double g_strategy_initial_equity = 0.0;
double g_cached_atr              = 0.0;
double g_cached_middle_band      = 0.0;
double g_cached_upper_band       = 0.0;
double g_cached_lower_band       = 0.0;
double g_cached_rsi              = 0.0;
MqlRates g_cached_bar_1;
MqlRates g_cached_bar_2;
ulong g_partial_close_ticket     = 0;

bool Strategy_RolloverBlackout()
  {
   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return true;
   const int minute_of_day = utc.hour * 60 + utc.min;
   return minute_of_day >= 1435 || minute_of_day <= 5;
  }

bool Strategy_EntryCircuitBreaker()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;

   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity *
                 (1.0 - InpDailyLossHaltPct / 100.0))
      return true;

   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity *
                    (1.0 - InpTotalDrawdownStopPct / 100.0);
  }

bool Strategy_EquityExitRequired()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;

   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity *
                (1.0 - InpDailyDrawdownStopPct / 100.0))
      return true;

   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity *
                    (1.0 - InpTotalDrawdownStopPct / 100.0);
  }

bool Strategy_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   // .DWX Model-4 tests legitimately model a zero spread; only positive,
   // genuinely wide spreads are blocked.
   return g_cached_atr > 0.0 && ask > bid &&
          (ask - bid) > CARD_SPREAD_ATR_MULT * g_cached_atr;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0; // relative host slot; framework binds qm_magic_slot_offset
   req.expiration_seconds = 0;
  }

bool Strategy_RefreshClosedBarCache()
  {
   if(InpBBPeriod < 2 || InpBBDev <= 0.0 || InpRSIPeriod < 2)
      return false;

   MqlRates bar_1;
   MqlRates bar_2;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, bar_1) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 2, bar_2))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, CARD_ATR_PERIOD, 1);
   const double middle = QM_BB_Middle(_Symbol, PERIOD_H1, InpBBPeriod, InpBBDev, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, InpBBPeriod, InpBBDev, 1);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, InpBBPeriod, InpBBDev, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, InpRSIPeriod, 1, PRICE_CLOSE);
   if(atr <= 0.0 || middle <= 0.0 || upper <= 0.0 || lower <= 0.0 ||
      !MathIsValidNumber(rsi) || rsi < 0.0 || rsi > 100.0)
      return false;

   g_cached_bar_1 = bar_1;
   g_cached_bar_2 = bar_2;
   g_cached_atr = atr;
   g_cached_middle_band = middle;
   g_cached_upper_band = upper;
   g_cached_lower_band = lower;
   g_cached_rsi = rsi;
   return true;
  }

bool Strategy_ConfigureSlippage()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0 || CARD_MAX_SLIPPAGE_TICKS <= 0)
      return false;

   const int deviation_points =
      (int)MathCeil((CARD_MAX_SLIPPAGE_TICKS * tick_size) / point);
   if(deviation_points <= 0)
      return false;

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   return true;
  }

// Entry-only admission checks live in Strategy_EntrySignal so no no-trade
// return can make management or the hard equity exits unreachable.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(!Strategy_RefreshClosedBarCache() || !Strategy_ConfigureSlippage())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= CARD_MAX_OPEN_POSITIONS ||
      Strategy_RolloverBlackout() || Strategy_EntryCircuitBreaker() ||
      Strategy_WideSpread())
      return false;

   const bool bullish_engulfing =
      g_cached_bar_1.close > g_cached_bar_2.open &&
      g_cached_bar_1.open < g_cached_bar_2.close &&
      g_cached_bar_2.close < g_cached_bar_2.open;
   const bool bearish_engulfing =
      g_cached_bar_1.close < g_cached_bar_2.open &&
      g_cached_bar_1.open > g_cached_bar_2.close &&
      g_cached_bar_2.close > g_cached_bar_2.open;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_buffer =
      QM_StopRulesPipsToPriceDistance(_Symbol, CARD_SL_BUFFER_PIPS);
   if(ask <= 0.0 || bid <= 0.0 || sl_buffer <= 0.0)
      return false;

   if(bullish_engulfing &&
      g_cached_bar_1.low <= g_cached_lower_band &&
      g_cached_rsi <= CARD_LONG_RSI_MAX)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol,
                                           g_cached_bar_1.low - sl_buffer);
      if(req.sl <= 0.0 || req.sl >= req.price)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl,
                         CARD_REWARD_RISK);
      req.reason = "codetrading_bb_bullish_engulfing";
      return req.tp > req.price;
     }

   if(bearish_engulfing &&
      g_cached_bar_1.high >= g_cached_upper_band &&
      g_cached_rsi >= CARD_SHORT_RSI_MIN)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol,
                                           g_cached_bar_1.high + sl_buffer);
      if(req.sl <= req.price)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl,
                         CARD_REWARD_RISK);
      req.reason = "codetrading_bb_bearish_engulfing";
      return req.tp > 0.0 && req.tp < req.price;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_cached_middle_band <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         ticket == g_partial_close_ticket)
         continue;

      const ENUM_POSITION_TYPE side =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double market_price =
         (side == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool middle_reached =
         (side == POSITION_TYPE_BUY && market_price >= g_cached_middle_band) ||
         (side == POSITION_TYPE_SELL && market_price <= g_cached_middle_band);
      if(!middle_reached)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double close_lots =
         QM_TM_NormalizeVolume(_Symbol, volume * CARD_MIDDLE_CLOSE_FRACTION);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(close_lots <= 0.0 || min_lot <= 0.0 ||
         volume - close_lots < min_lot)
         continue;

      if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         g_partial_close_ticket = ticket;
     }

   // The card's lifecycle diagram names BE/trailing states but supplies no
   // numeric triggers. They remain inactive; inventing thresholds would alter
   // the approved mechanism.
  }

bool Strategy_ExitSignal()
  {
   return Strategy_EquityExitRequired();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — kept in canonical skeleton order.
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

   g_strategy_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_38003\"}");
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                        qm_news_mode_legacy);
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
