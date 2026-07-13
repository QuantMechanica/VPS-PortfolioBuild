#ifndef QM_RISKSIZER_MQH
#define QM_RISKSIZER_MQH

// V5 Framework Step 05:
// Pure risk sizing math with MT5 symbol snapshot helpers.

enum QM_RiskMode
  {
   QM_RISK_MODE_UNSET   = 0,
   QM_RISK_MODE_PERCENT = 1,
   QM_RISK_MODE_FIXED   = 2
  };

struct QM_SymbolRiskSnapshot
  {
   double tick_value;
   double tick_size;
   double point;
   double volume_min;
   double volume_max;
   double volume_step;
   double contract_size;
   double margin_initial;
  };

QM_RiskMode g_qm_risk_mode                  = QM_RISK_MODE_UNSET;
double      g_qm_risk_percent               = 0.0;
double      g_qm_risk_fixed                 = 0.0;
double      g_qm_risk_portfolio_weight      = 1.0;
double      g_qm_risk_per_trade_cap_money   = 0.0;

bool QM_RiskSizerConfigure(const QM_RiskMode mode,
                           const double risk_percent,
                           const double risk_fixed,
                           const double portfolio_weight,
                           const double per_trade_cap_money = 0.0)
  {
   g_qm_risk_mode = mode;
   g_qm_risk_percent = risk_percent;
   g_qm_risk_fixed = risk_fixed;
   g_qm_risk_portfolio_weight = portfolio_weight;
   g_qm_risk_per_trade_cap_money = per_trade_cap_money;

   if(g_qm_risk_mode != QM_RISK_MODE_PERCENT && g_qm_risk_mode != QM_RISK_MODE_FIXED)
      return false;
   if(g_qm_risk_portfolio_weight <= 0.0 || g_qm_risk_portfolio_weight > 1.0)
      return false;
   if(g_qm_risk_mode == QM_RISK_MODE_PERCENT && g_qm_risk_percent <= 0.0)
      return false;
   if(g_qm_risk_mode == QM_RISK_MODE_FIXED && g_qm_risk_fixed <= 0.0)
      return false;
   return true;
  }

double QM_RiskSizerRiskMoney(const double equity)
  {
   if(equity <= 0.0)
      return 0.0;

   double base_risk = 0.0;
   if(g_qm_risk_mode == QM_RISK_MODE_PERCENT)
      base_risk = equity * (g_qm_risk_percent / 100.0);
   else if(g_qm_risk_mode == QM_RISK_MODE_FIXED)
      base_risk = g_qm_risk_fixed;
   else
      return 0.0;

   double weighted_risk = base_risk * g_qm_risk_portfolio_weight;
   if(weighted_risk <= 0.0)
      return 0.0;

   if(g_qm_risk_per_trade_cap_money > 0.0 && weighted_risk > g_qm_risk_per_trade_cap_money)
      weighted_risk = g_qm_risk_per_trade_cap_money;
   return weighted_risk;
  }

// Phase 1 master-EA support: resolve one strategy's explicit percentage without
// mutating the process-wide risk configuration. Portfolio weighting and the
// per-trade money cap remain the same framework safety rails as on the legacy
// global path.
double QM_RiskSizerRiskMoney(const double equity,
                             const double explicit_risk_percent)
  {
   if(equity <= 0.0 || explicit_risk_percent <= 0.0)
      return 0.0;

   const double base_risk = equity * (explicit_risk_percent / 100.0);
   double weighted_risk = base_risk * g_qm_risk_portfolio_weight;
   if(weighted_risk <= 0.0)
      return 0.0;

   if(g_qm_risk_per_trade_cap_money > 0.0 && weighted_risk > g_qm_risk_per_trade_cap_money)
      weighted_risk = g_qm_risk_per_trade_cap_money;
   return weighted_risk;
  }

double QM_RiskSizerQuantizeLots(const double raw_lots,
                                const double volume_min,
                                const double volume_max,
                                const double volume_step)
  {
   if(raw_lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
      return 0.0;

   double capped = raw_lots;
   if(capped > volume_max)
      capped = volume_max;

   // Floor to broker volume step to avoid accidental risk overshoot.
   double steps = MathFloor((capped + 1e-12) / volume_step);
   double quantized = steps * volume_step;
   quantized = NormalizeDouble(quantized, 8);

   if(quantized < volume_min)
      return 0.0;
   if(quantized > volume_max)
      quantized = volume_max;
   return quantized;
  }

string QM_RiskSizerUpper(const string value)
  {
   string out = value;
   StringToUpper(out);
   return out;
  }

string QM_RiskSizerBaseSymbol(const string symbol)
  {
   const string trimmed = QM_RiskSizerUpper(symbol);
   const int dot = StringFind(trimmed, ".");
   if(dot > 0)
      return StringSubstr(trimmed, 0, dot);
   return trimmed;
  }

string QM_RiskSizerSymbolSuffix(const string symbol)
  {
   const int dot = StringFind(symbol, ".");
   if(dot >= 0)
      return QM_RiskSizerUpper(StringSubstr(symbol, dot));
   return "";
  }

bool QM_RiskSizerIsFiatCode(const string code)
  {
   const string c = QM_RiskSizerUpper(code);
   return (c == "USD" || c == "EUR" || c == "GBP" || c == "JPY" ||
           c == "AUD" || c == "NZD" || c == "CAD" || c == "CHF");
  }

bool QM_RiskSizerReadMidPrice(const string symbol, double &price)
  {
   price = 0.0;
   if(StringLen(symbol) <= 0)
      return false;

   bool is_custom = false;
   if(!SymbolExist(symbol, is_custom))
      return false;

   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
      SymbolSelect(symbol, true);

   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
     {
      price = (bid + ask) * 0.5;
      return true;
     }
   if(ask > 0.0)
     {
      price = ask;
      return true;
     }
   if(bid > 0.0)
     {
      price = bid;
      return true;
     }

   const double last = SymbolInfoDouble(symbol, SYMBOL_LAST);
   if(last > 0.0)
     {
      price = last;
      return true;
     }
   return false;
  }

bool QM_RiskSizerCurrencyToAccountRate(const string currency,
                                       const string account_currency,
                                       const string suffix,
                                       double &rate)
  {
   rate = 0.0;
   const string ccy = QM_RiskSizerUpper(currency);
   const string acct = QM_RiskSizerUpper(account_currency);
   if(ccy == acct)
     {
      rate = 1.0;
      return true;
     }

   double price = 0.0;
   const string direct = ccy + acct + suffix;
   if(QM_RiskSizerReadMidPrice(direct, price) && price > 0.0)
     {
      rate = price;
      return true;
     }

   const string inverse = acct + ccy + suffix;
   if(QM_RiskSizerReadMidPrice(inverse, price) && price > 0.0)
     {
      rate = 1.0 / price;
      return true;
     }

   return false;
  }

bool QM_RiskSizerReadDwxFxSnapshot(const string symbol, QM_SymbolRiskSnapshot &snapshot)
  {
   const string suffix = QM_RiskSizerSymbolSuffix(symbol);
   if(suffix != ".DWX")
      return false;

   const string pair = QM_RiskSizerBaseSymbol(symbol);
   if(StringLen(pair) != 6)
      return false;

   const string base = StringSubstr(pair, 0, 3);
   const string quote = StringSubstr(pair, 3, 3);
   if(!QM_RiskSizerIsFiatCode(base) || !QM_RiskSizerIsFiatCode(quote))
      return false;

   snapshot.tick_value     = 0.0;
   snapshot.tick_size      = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   snapshot.point          = SymbolInfoDouble(symbol, SYMBOL_POINT);
   snapshot.volume_min     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   snapshot.volume_max     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   snapshot.volume_step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   snapshot.contract_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   snapshot.margin_initial = 0.0;

   if(snapshot.point <= 0.0 || snapshot.volume_min <= 0.0 ||
      snapshot.volume_max <= 0.0 || snapshot.volume_step <= 0.0 ||
      snapshot.contract_size <= 0.0)
      return false;
   if(snapshot.tick_size <= 0.0)
      snapshot.tick_size = snapshot.point;

   const string account_currency = QM_RiskSizerUpper(AccountInfoString(ACCOUNT_CURRENCY));
   double quote_to_account = 0.0;
   if(!QM_RiskSizerCurrencyToAccountRate(quote, account_currency, suffix, quote_to_account))
      return false;

   snapshot.tick_value = snapshot.contract_size * snapshot.tick_size * quote_to_account;

   double base_to_account = 0.0;
   const double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
   if(leverage > 0.0 &&
      QM_RiskSizerCurrencyToAccountRate(base, account_currency, suffix, base_to_account))
      snapshot.margin_initial = (snapshot.contract_size * base_to_account) / leverage;

   return (snapshot.tick_value > 0.0);
  }

bool QM_RiskSizerReadSymbolSnapshot(const string symbol, QM_SymbolRiskSnapshot &snapshot)
  {
   if(QM_RiskSizerReadDwxFxSnapshot(symbol, snapshot))
      return true;

   snapshot.tick_value     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   snapshot.tick_size      = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   snapshot.point          = SymbolInfoDouble(symbol, SYMBOL_POINT);
   snapshot.volume_min     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   snapshot.volume_max     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   snapshot.volume_step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   snapshot.contract_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   snapshot.margin_initial = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);

   if(snapshot.point <= 0.0 || snapshot.volume_min <= 0.0 || snapshot.volume_max <= 0.0 || snapshot.volume_step <= 0.0)
      return false;
   return true;
  }

double QM_LotsForRiskFromSnapshot(const QM_SymbolRiskSnapshot &snapshot,
                                  const double risk_money,
                                  const double sl_points)
  {
   if(risk_money <= 0.0 || sl_points <= 0.0)
      return 0.0;

   double point_value_per_lot = 0.0;
   if(snapshot.tick_value > 0.0 && snapshot.tick_size > 0.0 && snapshot.point > 0.0)
      point_value_per_lot = snapshot.tick_value * (snapshot.point / snapshot.tick_size);
   else if(snapshot.contract_size > 0.0 && snapshot.point > 0.0)
      point_value_per_lot = snapshot.contract_size * snapshot.point;

   if(point_value_per_lot <= 0.0)
      return 0.0;

   double loss_per_lot = sl_points * point_value_per_lot;
   if(loss_per_lot <= 0.0)
      return 0.0;

   double raw_lots = risk_money / loss_per_lot;
   if(raw_lots <= 0.0)
      return 0.0;

   double lots = QM_RiskSizerQuantizeLots(raw_lots, snapshot.volume_min, snapshot.volume_max, snapshot.volume_step);
   return lots;
  }

double QM_LotsForRisk(const string symbol, const double sl_points)
  {
   QM_SymbolRiskSnapshot snapshot;
   if(!QM_RiskSizerReadSymbolSnapshot(symbol, snapshot))
      return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = QM_RiskSizerRiskMoney(equity);
   if(risk_money <= 0.0)
      return 0.0;

   double lots = QM_LotsForRiskFromSnapshot(snapshot, risk_money, sl_points);
   if(lots <= 0.0)
      return 0.0;

   // rework v2 2026-06-16: cap by available margin even when the broker reports
   // SYMBOL_MARGIN_INITIAL==0 (true for DWX custom symbols). Without this, tight-stop
   // strategies (e.g. opening-range breakout on high-priced indices) compute raw_lots
   // that overflow SYMBOL_VOLUME_MAX, get clamped to the 100-lot cap, and are then
   // rejected by the tester as "no money" on ~95% of days -> spurious MIN_TRADES_NOT_MET.
   // Wide-stop EAs never hit the cap, so this is a no-op for them.
   double margin_per_lot = snapshot.margin_initial;
   if(margin_per_lot <= 0.0)
     {
      // Fallback per-lot margin from notional / leverage when broker omits margin_initial.
      double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(leverage <= 0.0)
         leverage = 100.0;
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(price <= 0.0)
         price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(price > 0.0 && snapshot.contract_size > 0.0)
         margin_per_lot = (price * snapshot.contract_size) / leverage;
     }

   if(margin_per_lot > 0.0)
     {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(free_margin <= 0.0)
         return 0.0;

      // Use a safety fraction so the bracket pair (two pending stops) stays affordable.
      double margin_cap_lots = (free_margin * 0.90) / margin_per_lot;
      lots = QM_RiskSizerQuantizeLots(MathMin(lots, margin_cap_lots),
                                      snapshot.volume_min,
                                      snapshot.volume_max,
                                      snapshot.volume_step);
     }

   return lots;
  }

// Explicit per-strategy percentage overload. The two-argument function above
// intentionally remains intact so every existing EA follows its original
// global percent/fixed-money sizing path bit-for-bit.
double QM_LotsForRisk(const string symbol,
                      const double sl_points,
                      const double explicit_risk_percent)
  {
   QM_SymbolRiskSnapshot snapshot;
   if(!QM_RiskSizerReadSymbolSnapshot(symbol, snapshot))
      return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money = QM_RiskSizerRiskMoney(equity, explicit_risk_percent);
   if(risk_money <= 0.0)
      return 0.0;

   double lots = QM_LotsForRiskFromSnapshot(snapshot, risk_money, sl_points);
   if(lots <= 0.0)
      return 0.0;

   // Keep the same available-margin ceiling as the legacy sizing path,
   // including the DWX fallback when SYMBOL_MARGIN_INITIAL is unavailable.
   double margin_per_lot = snapshot.margin_initial;
   if(margin_per_lot <= 0.0)
     {
      double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
      if(leverage <= 0.0)
         leverage = 100.0;
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(price <= 0.0)
         price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(price > 0.0 && snapshot.contract_size > 0.0)
         margin_per_lot = (price * snapshot.contract_size) / leverage;
     }

   if(margin_per_lot > 0.0)
     {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(free_margin <= 0.0)
         return 0.0;

      double margin_cap_lots = (free_margin * 0.90) / margin_per_lot;
      lots = QM_RiskSizerQuantizeLots(MathMin(lots, margin_cap_lots),
                                      snapshot.volume_min,
                                      snapshot.volume_max,
                                      snapshot.volume_step);
     }

   return lots;
  }

#endif // QM_RISKSIZER_MQH
