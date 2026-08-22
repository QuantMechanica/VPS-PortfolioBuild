#ifndef QM_ACCOUNT_RISK_RESERVATION_MQH
#define QM_ACCOUNT_RISK_RESERVATION_MQH

// SP-C2: account-wide, pre-trade planned-stop-risk reservation.
//
// The reservation is deliberately dormant for legacy execution contracts. A
// Card-v3 FTMO contract must explicitly bind an OWNER-ratified policy hash,
// account/challenge identity, initial-balance anchor, and cap. Backtests remain
// RISK_FIXED and cannot enable this live RISK_PERCENT control.
//
// All framework exposure-opening requests serialize through one terminal-global
// compare-and-swap lease. While holding it, the caller measures every broker
// position and pending order without a magic allowlist, adds the proposed order,
// and keeps the lease through synchronous OrderSend/retry completion. A crash
// leaves a fail-closed lease until its conservative stale timeout expires; the
// next holder then rescans broker truth before admitting anything.

const string QM_ACCOUNT_RISK_POLICY_ID = "FTMO_2S_100K_OPEN_STOP_RISK_V1";
const double QM_ACCOUNT_RISK_MAX_CAP_PERCENT = 2.5;
const int QM_ACCOUNT_RISK_LEASE_STALE_SECONDS = 120;

enum QM_AccountRiskReservationStatus
  {
   QM_ACCOUNT_RISK_DISABLED = 0,
   QM_ACCOUNT_RISK_RESERVED = 1,
   QM_ACCOUNT_RISK_REJECT_CONFIG = 2,
   QM_ACCOUNT_RISK_REJECT_BUSY = 3,
   QM_ACCOUNT_RISK_REJECT_INVENTORY_UNKNOWN = 4,
   QM_ACCOUNT_RISK_REJECT_OVER_BUDGET = 5
  };

struct QM_AccountRiskReservationDecision
  {
   QM_AccountRiskReservationStatus status;
   string reason;
   bool lease_acquired;
   string lease_key;
   double lease_value;
   double existing_risk_money;
   double request_risk_money;
   double projected_risk_money;
   double cap_money;
   int positions_count;
   int pending_orders_count;
  };

bool   g_qm_account_risk_enabled = false;
bool   g_qm_account_risk_owner_ratified = false;
long   g_qm_account_risk_login = 0;
string g_qm_account_risk_policy_id = "";
string g_qm_account_risk_policy_sha256 = "";
string g_qm_account_risk_challenge_id = "";
double g_qm_account_risk_anchor_balance = 0.0;
double g_qm_account_risk_cap_percent = 0.0;
double g_qm_account_risk_cap_money = 0.0;

void QM_AccountRiskDecisionReset(QM_AccountRiskReservationDecision &decision)
  {
   decision.status = QM_ACCOUNT_RISK_DISABLED;
   decision.reason = "ACCOUNT_RISK_DISABLED";
   decision.lease_acquired = false;
   decision.lease_key = "";
   decision.lease_value = 0.0;
   decision.existing_risk_money = 0.0;
   decision.request_risk_money = 0.0;
   decision.projected_risk_money = 0.0;
   decision.cap_money = g_qm_account_risk_cap_money;
   decision.positions_count = 0;
   decision.pending_orders_count = 0;
  }

bool QM_AccountRiskIdentifierValid(const string value)
  {
   const int length = StringLen(value);
   if(length < 3 || length > 128)
      return false;
   for(int i = 0; i < length; ++i)
     {
      const ushort code = (ushort)StringGetCharacter(value, i);
      const bool alpha = ((code >= 'a' && code <= 'z') ||
                          (code >= 'A' && code <= 'Z'));
      const bool digit = (code >= '0' && code <= '9');
      if(!alpha && !digit && code != '_' && code != '-' && code != '.')
         return false;
     }
   return true;
  }

bool QM_AccountRiskHashValid(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   for(int i = 0; i < 64; ++i)
     {
      const ushort code = (ushort)StringGetCharacter(value, i);
      const bool digit = (code >= '0' && code <= '9');
      const bool lower = (code >= 'a' && code <= 'f');
      const bool upper = (code >= 'A' && code <= 'F');
      if(!digit && !lower && !upper)
         return false;
     }
   return true;
  }

ulong QM_AccountRiskIdentifierHash(const string value)
  {
   ulong hash = 5381;
   for(int i = 0; i < StringLen(value); ++i)
      hash = ((hash << 5) + hash) ^ (ulong)StringGetCharacter(value, i);
   return hash;
  }

void QM_AccountRiskReservationDisable()
  {
   g_qm_account_risk_enabled = false;
   g_qm_account_risk_owner_ratified = false;
   g_qm_account_risk_login = 0;
   g_qm_account_risk_policy_id = "";
   g_qm_account_risk_policy_sha256 = "";
   g_qm_account_risk_challenge_id = "";
   g_qm_account_risk_anchor_balance = 0.0;
   g_qm_account_risk_cap_percent = 0.0;
   g_qm_account_risk_cap_money = 0.0;
  }

bool QM_AccountRiskReservationConfigure(const bool required,
                                        const string policy_id,
                                        const string policy_sha256,
                                        const string challenge_id,
                                        const long account_login,
                                        const double anchor_balance,
                                        const double cap_percent,
                                        const bool owner_ratified,
                                        const bool risk_percent_mode)
  {
   QM_AccountRiskReservationDisable();
   if(!required)
      return true;

   // This is a live pre-trade control. Tester evidence must retain the
   // RISK_FIXED contract and must never be silently changed by account state.
   if(MQLInfoInteger(MQL_TESTER) != 0 || !risk_percent_mode || !owner_ratified)
      return false;
   if(policy_id != QM_ACCOUNT_RISK_POLICY_ID ||
      !QM_AccountRiskHashValid(policy_sha256) ||
      !QM_AccountRiskIdentifierValid(challenge_id) ||
      account_login <= 0 || account_login != AccountInfoInteger(ACCOUNT_LOGIN) ||
      !MathIsValidNumber(anchor_balance) || anchor_balance != 100000.0 ||
      !MathIsValidNumber(cap_percent) || cap_percent <= 0.0 ||
      cap_percent > QM_ACCOUNT_RISK_MAX_CAP_PERCENT)
      return false;

   const double cap_money = anchor_balance * cap_percent / 100.0;
   if(!MathIsValidNumber(cap_money) || cap_money <= 0.0)
      return false;

   g_qm_account_risk_owner_ratified = true;
   g_qm_account_risk_login = account_login;
   g_qm_account_risk_policy_id = policy_id;
   g_qm_account_risk_policy_sha256 = policy_sha256;
   g_qm_account_risk_challenge_id = challenge_id;
   g_qm_account_risk_anchor_balance = anchor_balance;
   g_qm_account_risk_cap_percent = cap_percent;
   g_qm_account_risk_cap_money = cap_money;
   g_qm_account_risk_enabled = true;
   return true;
  }

bool QM_AccountRiskOrderSide(const ENUM_ORDER_TYPE type, bool &is_buy)
  {
   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT ||
      type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT)
     {
      is_buy = true;
      return true;
     }
   if(type == ORDER_TYPE_SELL || type == ORDER_TYPE_SELL_LIMIT ||
      type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_STOP_LIMIT)
     {
      is_buy = false;
      return true;
     }
   return false;
  }

bool QM_AccountRiskDirectionalLoss(const string symbol,
                                   const ENUM_ORDER_TYPE request_type,
                                   const double volume,
                                   const double from_price,
                                   const double stop_price,
                                   double &loss_money)
  {
   loss_money = 0.0;
   bool is_buy = false;
   if(!QM_AccountRiskOrderSide(request_type, is_buy) ||
      symbol == "" || !MathIsValidNumber(volume) || volume <= 0.0 ||
      !MathIsValidNumber(from_price) || from_price <= 0.0 ||
      !MathIsValidNumber(stop_price) || stop_price <= 0.0)
      return false;
   if((is_buy && stop_price >= from_price) ||
      (!is_buy && stop_price <= from_price))
      return false;

   double profit_at_stop = 0.0;
   const ENUM_ORDER_TYPE side = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   ResetLastError();
   if(!OrderCalcProfit(side, symbol, volume, from_price, stop_price,
                       profit_at_stop) ||
      !MathIsValidNumber(profit_at_stop) || profit_at_stop >= 0.0)
      return false;
   loss_money = -profit_at_stop;
   return (MathIsValidNumber(loss_money) && loss_money > 0.0);
  }

bool QM_AccountRiskPositionLoss(const ulong ticket, double &loss_money)
  {
   loss_money = 0.0;
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   double current = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double stop = PositionGetDouble(POSITION_SL);
   const ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   ENUM_ORDER_TYPE order_type;
   if(position_type == POSITION_TYPE_BUY)
     {
      order_type = ORDER_TYPE_BUY;
      if(current <= 0.0)
         current = SymbolInfoDouble(symbol, SYMBOL_BID);
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      order_type = ORDER_TYPE_SELL;
      if(current <= 0.0)
         current = SymbolInfoDouble(symbol, SYMBOL_ASK);
     }
   else
      return false;
   return QM_AccountRiskDirectionalLoss(symbol, order_type, volume, current,
                                        stop, loss_money);
  }

double QM_AccountRiskPendingEntryPrice(const ENUM_ORDER_TYPE order_type,
                                       const double open_price,
                                       const double stop_limit_price)
  {
   bool is_buy = false;
   if(!QM_AccountRiskOrderSide(order_type, is_buy))
      return 0.0;
   if(stop_limit_price <= 0.0)
      return open_price;
   // Reserve against the less favorable of trigger and stop-limit price.
   return is_buy ? MathMax(open_price, stop_limit_price)
                 : MathMin(open_price, stop_limit_price);
  }

bool QM_AccountRiskPendingOrderLoss(const ulong ticket, double &loss_money)
  {
   loss_money = 0.0;
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   const ENUM_ORDER_TYPE order_type =
      (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   bool is_buy = false;
   if(!QM_AccountRiskOrderSide(order_type, is_buy) ||
      order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL)
      return false;
   const string symbol = OrderGetString(ORDER_SYMBOL);
   const double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
   const double entry = QM_AccountRiskPendingEntryPrice(
      order_type,
      OrderGetDouble(ORDER_PRICE_OPEN),
      OrderGetDouble(ORDER_PRICE_STOPLIMIT));
   const double stop = OrderGetDouble(ORDER_SL);
   return QM_AccountRiskDirectionalLoss(symbol, order_type, volume, entry,
                                        stop, loss_money);
  }

bool QM_AccountRiskRequestLoss(const MqlTradeRequest &request,
                               double &loss_money)
  {
   loss_money = 0.0;
   if(request.action != TRADE_ACTION_DEAL &&
      request.action != TRADE_ACTION_PENDING)
      return false;
   if(request.action == TRADE_ACTION_DEAL && request.position > 0)
      return false;

   bool is_buy = false;
   if(!QM_AccountRiskOrderSide(request.type, is_buy))
      return false;
   double entry = request.price;
   if(request.action == TRADE_ACTION_DEAL)
     {
      const double quote = SymbolInfoDouble(
         request.symbol, is_buy ? SYMBOL_ASK : SYMBOL_BID);
      if(quote > 0.0)
         entry = quote;
      const double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
      if(point > 0.0 && request.deviation > 0)
        {
         const double slippage = (double)request.deviation * point;
         entry += is_buy ? slippage : -slippage;
        }
     }
   else
      entry = QM_AccountRiskPendingEntryPrice(request.type, request.price,
                                              request.stoplimit);

   return QM_AccountRiskDirectionalLoss(request.symbol, request.type,
                                        request.volume, entry, request.sl,
                                        loss_money);
  }

bool QM_AccountRiskMeasureInventory(double &risk_money,
                                    int &position_count,
                                    int &pending_count,
                                    string &reason)
  {
   risk_money = 0.0;
   reason = "ACCOUNT_RISK_INVENTORY_UNKNOWN";
   const int positions_before = PositionsTotal();
   const int orders_before = OrdersTotal();
   position_count = positions_before;
   pending_count = orders_before;
   if(positions_before < 0 || orders_before < 0)
      return false;

   for(int i = 0; i < positions_before; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      double row_loss = 0.0;
      if(ticket == 0 || !QM_AccountRiskPositionLoss(ticket, row_loss))
        {
         reason = StringFormat("ACCOUNT_RISK_POSITION_UNPRICED_%I64u", ticket);
         return false;
        }
      risk_money += row_loss;
      if(!MathIsValidNumber(risk_money))
         return false;
     }

   for(int i = 0; i < orders_before; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      double row_loss = 0.0;
      if(ticket == 0 || !QM_AccountRiskPendingOrderLoss(ticket, row_loss))
        {
         reason = StringFormat("ACCOUNT_RISK_PENDING_UNPRICED_%I64u", ticket);
         return false;
        }
      risk_money += row_loss;
      if(!MathIsValidNumber(risk_money))
         return false;
     }

   // Count drift means another actor changed broker state while inventory was
   // read. Never turn a torn snapshot into an admission.
   if(positions_before != PositionsTotal() || orders_before != OrdersTotal())
     {
      reason = "ACCOUNT_RISK_INVENTORY_COUNT_DRIFT";
      return false;
     }
   reason = "ACCOUNT_RISK_INVENTORY_COMPLETE";
   return true;
  }

string QM_AccountRiskLeaseKey()
  {
   const string scope = g_qm_account_risk_policy_id + "_" +
                        g_qm_account_risk_challenge_id;
   return StringFormat("QM.AR1.%I64d.%I64u", g_qm_account_risk_login,
                       QM_AccountRiskIdentifierHash(scope));
  }

double QM_AccountRiskLeaseCandidate(const datetime now_local)
  {
   const string identity = StringFormat("%I64d_%I64d_%I64u",
                                        g_qm_account_risk_login,
                                        ChartID(), GetMicrosecondCount());
   const ulong token = (QM_AccountRiskIdentifierHash(identity) % 900000) + 1;
   return (double)now_local + ((double)token / 1000000.0);
  }

bool QM_AccountRiskAcquireLease(QM_AccountRiskReservationDecision &decision)
  {
   const datetime now_local = TimeLocal();
   if(now_local <= 0)
     {
      decision.reason = "ACCOUNT_RISK_CLOCK_INVALID";
      return false;
     }
   const string key = QM_AccountRiskLeaseKey();
   if(key == "" || !GlobalVariableTemp(key))
     {
      decision.reason = "ACCOUNT_RISK_LEASE_INIT_FAILED";
      return false;
     }
   ResetLastError();
   const double observed = GlobalVariableGet(key);
   if(GetLastError() != 0 || !MathIsValidNumber(observed) || observed < 0.0)
     {
      decision.reason = "ACCOUNT_RISK_LEASE_READ_FAILED";
      return false;
     }
   if(observed > 0.0)
     {
      const datetime observed_at = (datetime)MathFloor(observed);
      const long age = (long)(now_local - observed_at);
      if(age < 0 || age <= QM_ACCOUNT_RISK_LEASE_STALE_SECONDS)
        {
         decision.reason = "ACCOUNT_RISK_RESERVATION_BUSY";
         return false;
        }
     }

   const double candidate = QM_AccountRiskLeaseCandidate(now_local);
   ResetLastError();
   if(candidate <= 0.0 ||
      !GlobalVariableSetOnCondition(key, candidate, observed))
     {
      decision.reason = "ACCOUNT_RISK_RESERVATION_BUSY";
      return false;
     }
   GlobalVariablesFlush();
   decision.lease_key = key;
   decision.lease_value = candidate;
   decision.lease_acquired = true;
   return true;
  }

bool QM_AccountRiskReleaseLease(QM_AccountRiskReservationDecision &decision)
  {
   if(!decision.lease_acquired)
      return true;
   ResetLastError();
   const bool released = GlobalVariableSetOnCondition(
      decision.lease_key, 0.0, decision.lease_value);
   GlobalVariablesFlush();
   decision.lease_acquired = false;
   return released;
  }

bool QM_AccountRiskReservationBegin(
   const MqlTradeRequest &request,
   QM_AccountRiskReservationDecision &decision)
  {
   QM_AccountRiskDecisionReset(decision);
   if(!g_qm_account_risk_enabled)
      return true;
   if(request.action != TRADE_ACTION_DEAL &&
      request.action != TRADE_ACTION_PENDING)
      return true;
   // Position-ticket deals are closes/partial closes. They reduce exposure and
   // must remain available even while the entry budget is busy or uncertain.
   if(request.action == TRADE_ACTION_DEAL && request.position > 0)
      return true;

   decision.cap_money = g_qm_account_risk_cap_money;
   if(!g_qm_account_risk_owner_ratified ||
      g_qm_account_risk_login != AccountInfoInteger(ACCOUNT_LOGIN) ||
      g_qm_account_risk_policy_id != QM_ACCOUNT_RISK_POLICY_ID ||
      !QM_AccountRiskHashValid(g_qm_account_risk_policy_sha256) ||
      !MathIsValidNumber(g_qm_account_risk_cap_money) ||
      g_qm_account_risk_cap_money <= 0.0)
     {
      decision.status = QM_ACCOUNT_RISK_REJECT_CONFIG;
      decision.reason = "ACCOUNT_RISK_CONFIG_INVALID";
      return false;
     }

   if(!QM_AccountRiskAcquireLease(decision))
     {
      decision.status = QM_ACCOUNT_RISK_REJECT_BUSY;
      return false;
     }

   string inventory_reason = "";
   if(!QM_AccountRiskMeasureInventory(decision.existing_risk_money,
                                      decision.positions_count,
                                      decision.pending_orders_count,
                                      inventory_reason) ||
      !QM_AccountRiskRequestLoss(request, decision.request_risk_money))
     {
      decision.status = QM_ACCOUNT_RISK_REJECT_INVENTORY_UNKNOWN;
      decision.reason = (inventory_reason == "ACCOUNT_RISK_INVENTORY_COMPLETE")
                        ? "ACCOUNT_RISK_REQUEST_UNPRICED"
                        : inventory_reason;
      QM_AccountRiskReleaseLease(decision);
      return false;
     }

   decision.projected_risk_money = decision.existing_risk_money +
                                   decision.request_risk_money;
   if(!MathIsValidNumber(decision.projected_risk_money) ||
      decision.projected_risk_money > decision.cap_money + 0.005)
     {
      decision.status = QM_ACCOUNT_RISK_REJECT_OVER_BUDGET;
      decision.reason = "ACCOUNT_RISK_OVER_BUDGET";
      QM_AccountRiskReleaseLease(decision);
      return false;
     }

   decision.status = QM_ACCOUNT_RISK_RESERVED;
   decision.reason = "ACCOUNT_RISK_RESERVED";
   return true;
  }

#endif // QM_ACCOUNT_RISK_RESERVATION_MQH
