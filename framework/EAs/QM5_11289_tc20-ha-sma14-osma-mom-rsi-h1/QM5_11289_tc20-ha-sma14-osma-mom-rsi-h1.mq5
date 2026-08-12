#property strict
#property version   "5.0"
#property description "QM5_11289 TC20 Heiken Ashi SMA OsMA Momentum RSI H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11289
// -----------------------------------------------------------------------------
// Mechanised from Thomas Carter, "20 Forex Trading Strategies (1 Hour Time
// Frame)", Strategy #4. Per the binding .DWX invariant, OsMA supplies the one
// fresh crossover trigger; Heiken-Ashi/SMA, Momentum and RSI are aligned states
// on the same closed H1 bar. Stops use the card's P2 ATR(14) x 1.5 default and
// take-profit is fixed at 2R. An opposite OsMA zero-cross exits early.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11289;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;    // Live setfile: 0.5; tester leaves this zero.
input double RISK_FIXED                 = 1000.0; // Backtest default per HR4.
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period          = 14;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_momentum_period     = 10;
input int    strategy_rsi_period          = 5;
input int    strategy_ha_warmup_bars      = 50;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_tp_rr               = 2.0;
input int    strategy_spread_cap_pips     = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — mechanical translation of the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: block missing quotes or a genuinely wide spread. A zero
// modelled spread remains tradeable on .DWX symbols.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;
   return false;
  }

// Trade Entry: OsMA zero-cross is the sole event trigger. The remaining card
// conditions are directional states on the last closed H1 bar, as required by
// the .DWX no-simultaneous-cross invariant.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H1 ||
      strategy_sma_period < 1 ||
      strategy_macd_fast < 1 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 ||
      strategy_momentum_period < 1 ||
      strategy_rsi_period < 2 ||
      strategy_ha_warmup_bars < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_tp_rr <= 0.0)
      return false;

   // Bespoke structural logic: reconstruct the last closed Heiken-Ashi candle
   // once behind the framework QM_IsNewBar gate. CopyRates is bounded and is
   // never reached on the per-tick path.
   MqlRates rates[];
   const int bars_needed = strategy_ha_warmup_bars;
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_needed, rates); // perf-allowed: bounded closed-bar Heiken-Ashi reconstruction.
   if(copied != bars_needed)
      return false;

   double ha_open = 0.0;
   double ha_close = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].open <= 0.0 || rates[i].high <= 0.0 ||
         rates[i].low <= 0.0 || rates[i].close <= 0.0)
         return false;

      const double next_ha_close = (rates[i].open + rates[i].high +
                                    rates[i].low + rates[i].close) * 0.25;
      const double next_ha_open = (i == 0)
                                  ? (rates[i].open + rates[i].close) * 0.5
                                  : (ha_open + ha_close) * 0.5;
      ha_open = next_ha_open;
      ha_close = next_ha_close;
     }

   const double macd_main_prev = QM_MACD_Main(_Symbol, PERIOD_H1,
                                               strategy_macd_fast,
                                               strategy_macd_slow,
                                               strategy_macd_signal,
                                               2,
                                               PRICE_CLOSE);
   const double macd_signal_prev = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                                   strategy_macd_fast,
                                                   strategy_macd_slow,
                                                   strategy_macd_signal,
                                                   2,
                                                   PRICE_CLOSE);
   const double macd_main_now = QM_MACD_Main(_Symbol, PERIOD_H1,
                                              strategy_macd_fast,
                                              strategy_macd_slow,
                                              strategy_macd_signal,
                                              1,
                                              PRICE_CLOSE);
   const double macd_signal_now = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                                  strategy_macd_fast,
                                                  strategy_macd_slow,
                                                  strategy_macd_signal,
                                                  1,
                                                  PRICE_CLOSE);
   const double osma_prev = macd_main_prev - macd_signal_prev;
   const double osma_now = macd_main_now - macd_signal_now;
   const bool trigger_long = (osma_prev < 0.0 && osma_now >= 0.0);
   const bool trigger_short = (osma_prev > 0.0 && osma_now <= 0.0);
   if(!trigger_long && !trigger_short)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_H1,
                                  strategy_sma_period, 1, PRICE_CLOSE);
   const double momentum_now = QM_Momentum(_Symbol, PERIOD_H1,
                                            strategy_momentum_period, 1,
                                            PRICE_CLOSE);
   const double rsi_now = QM_RSI(_Symbol, PERIOD_H1,
                                  strategy_rsi_period, 1, PRICE_CLOSE);
   if(sma_now <= 0.0 || momentum_now <= 0.0 || rsi_now <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(trigger_long &&
      ha_close > ha_open &&
      ha_close > sma_now &&
      momentum_now > 100.0 &&
      rsi_now > 50.0)
     {
      const double sl = QM_StopATR(_Symbol, QM_BUY, ask,
                                    strategy_atr_period,
                                    strategy_atr_sl_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl,
                                   strategy_tp_rr);
      if(sl <= 0.0 || sl >= ask || tp <= ask)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC20_HA_SMA_OSMA_MOM_RSI_LONG";
      return true;
     }

   if(trigger_short &&
      ha_close < ha_open &&
      ha_close < sma_now &&
      momentum_now < 100.0 &&
      rsi_now < 50.0)
     {
      const double sl = QM_StopATR(_Symbol, QM_SELL, bid,
                                    strategy_atr_period,
                                    strategy_atr_sl_mult);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl,
                                   strategy_tp_rr);
      if(sl <= bid || tp <= 0.0 || tp >= bid)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC20_HA_SMA_OSMA_MOM_RSI_SHORT";
      return true;
     }

   return false;
  }

// Trade Management: the card defines no break-even, trailing, scale-in or
// partial-close behaviour. Server-side SL/TP and framework safeguards remain.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: exit early when OsMA crosses zero against the open direction.
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_H1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool found_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
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
      found_position = true;
      break;
     }
   if(!found_position)
      return false;

   const double osma_prev =
      QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast,
                   strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE) -
      QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast,
                     strategy_macd_slow, strategy_macd_signal, 2, PRICE_CLOSE);
   const double osma_now =
      QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast,
                   strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE) -
      QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast,
                     strategy_macd_slow, strategy_macd_signal, 1, PRICE_CLOSE);

   if(position_type == POSITION_TYPE_BUY &&
      osma_prev > 0.0 && osma_now <= 0.0)
      return true;
   if(position_type == POSITION_TYPE_SELL &&
      osma_prev < 0.0 && osma_now >= 0.0)
      return true;
   return false;
  }

// News Filter Hook: no card-specific override. The central two-axis framework
// news filter remains authoritative and fail-closed when configured.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring.
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

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
