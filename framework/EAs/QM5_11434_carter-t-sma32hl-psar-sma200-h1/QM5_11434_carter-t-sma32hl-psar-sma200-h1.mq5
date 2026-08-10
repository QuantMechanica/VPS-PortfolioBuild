#property strict
#property version   "5.0"
#property description "QM5_11434 Carter-T SMA32(High/Low) Channel + PSAR + SMA100/200"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11434
// Source: Thomas Carter, "20 Multi-Timeframe Trading Systems", Strategy #6.
// Card: cards_approved/QM5_11434_carter-t-sma32hl-psar-sma200-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11434;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_sma_channel_period  = 32;
input int    strategy_sma_trend1_period   = 100;
input int    strategy_sma_trend2_period   = 200;
input double strategy_psar_step           = 0.02;
input double strategy_psar_max            = 0.2;
input int    strategy_atr_period          = 14;
input double strategy_atr_tp_mult         = 2.0;
input double strategy_atr_sl_mult         = 1.5;
input int    strategy_sl_lookback_bars    = 5;
input double strategy_sl_cap_pips         = 80.0;
input int    strategy_max_spread_pips     = 20;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Four-way confluence check, shared by entry (fresh signal) and exit
// (opposite-signal reverse), both evaluated on the same closed bar[1].
void ComputeChannelPsarSignal(bool &long_setup, bool &short_setup)
{
   long_setup = false;
   short_setup = false;

   double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed
   double open_1  = iOpen(_Symbol, _Period, 1);  // perf-allowed
   double low_1   = iLow(_Symbol, _Period, 1);   // perf-allowed
   double high_1  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   double sma_high_1 = QM_SMA(_Symbol, _Period, strategy_sma_channel_period, 1, PRICE_HIGH);
   double sma_low_1  = QM_SMA(_Symbol, _Period, strategy_sma_channel_period, 1, PRICE_LOW);
   double sma_t1_1   = QM_SMA(_Symbol, _Period, strategy_sma_trend1_period, 1, PRICE_CLOSE);
   double sma_t2_1   = QM_SMA(_Symbol, _Period, strategy_sma_trend2_period, 1, PRICE_CLOSE);
   double psar_1     = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(close_1 <= 0.0 || open_1 <= 0.0 || low_1 <= 0.0 || high_1 <= 0.0 ||
      sma_high_1 <= 0.0 || sma_low_1 <= 0.0 || sma_t1_1 <= 0.0 || sma_t2_1 <= 0.0 || psar_1 <= 0.0)
      return;

   long_setup = (close_1 > sma_high_1) && (close_1 > open_1) &&
                (close_1 > sma_t1_1) && (close_1 > sma_t2_1) && (psar_1 < low_1);
   short_setup = (close_1 < sma_low_1) && (close_1 < open_1) &&
                 (close_1 < sma_t1_1) && (close_1 < sma_t2_1) && (psar_1 > high_1);
}

// Return TRUE to BLOCK trading this tick. Always allows management of an
// already-open position (spread cap applies to fresh entries only).
bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic)
            return false;
      }
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
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

   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   bool long_setup, short_setup;
   ComputeChannelPsarSignal(long_setup, short_setup);
   if(!long_setup && !short_setup)
      return false;

   QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   double entry_price = QM_EntryMarketPrice(side);
   if(entry_price <= 0.0)
      return false;

   // Tightest of {5-bar structure extreme, ATR(14)x1.5}, further capped at 80 pips.
   double structure_sl = QM_StopStructure(_Symbol, side, entry_price, strategy_sl_lookback_bars);
   double atr_sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   double capped_sl = QM_StopFixedPips(_Symbol, side, entry_price, (int)MathRound(strategy_sl_cap_pips));
   if(structure_sl <= 0.0 || atr_sl <= 0.0 || capped_sl <= 0.0)
      return false;

   double sl_price = structure_sl;
   double best_dist = MathAbs(entry_price - structure_sl);
   double atr_dist = MathAbs(entry_price - atr_sl);
   double cap_dist = MathAbs(entry_price - capped_sl);
   if(atr_dist < best_dist) { sl_price = atr_sl; best_dist = atr_dist; }
   if(cap_dist < best_dist) { sl_price = capped_sl; best_dist = cap_dist; }

   double tp_price = QM_TakeATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(tp_price <= 0.0)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = long_setup ? "CARTER_SMA32_PSAR_SMA200_LONG" : "CARTER_SMA32_PSAR_SMA200_SHORT";
   return true;
}

void Strategy_ManageOpenPosition() {}

// Card: "exit and reverse when opposite entry fires." Closing here and letting
// Strategy_EntrySignal fire in the same OnTick pass (framework wiring runs
// exit then entry unconditionally) implements the reverse.
bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      found = true;
      break;
   }
   if(!found)
      return false;

   bool long_setup, short_setup;
   ComputeChannelPsarSignal(long_setup, short_setup);

   if(position_type == POSITION_TYPE_BUY && short_setup)
      return true;
   if(position_type == POSITION_TYPE_SELL && long_setup)
      return true;

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

   if(!QM_IsNewBar()) return;
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
