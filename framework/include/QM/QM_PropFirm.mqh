#ifndef QM_PROP_FIRM_MQH
#define QM_PROP_FIRM_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

// V5 Framework — prop-firm / challenge-account awareness.
//
// WHY THIS EXISTS, and why the defaults are what they are.
//
// A challenge account is not a trading account with extra rules bolted on; it is
// a different objective. A funded account must survive indefinitely. A challenge
// must reach +10% once and then stop mattering. Our EAs had no notion of the
// second, and the cost was measured on the FTMO campaign books
// (docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md, 22-day windows,
// selection 2017-2022, scoring 2022-2025):
//
//     target reached at any trade close, then flat   86.3 %
//     target held to that day's close, then flat     86.0 %
//     NO target awareness — must simply END >= +10%  57.5 %
//
// Reaching the target and continuing to trade gives back 28.8 points of pass
// probability. That is the single largest lever found anywhere in that work —
// larger than account count, leverage, or any risk overlay. Hence
// prop_flatten_at_target defaults TRUE, and it is the reason this file exists.
//
// The opposite is true of the loss-side throttles, which is why they default OFF
// despite being the obvious things to add. Measured on the same books, the
// existing preservation governor (FTMO_2S_P1_100K_V2: halt entries at -0.9% on
// the day, liquidate at -1.25%, give up at -6%, taper size above +7.5%) took the
// campaign from 86.3% down to 65.2%. Throttling protects capital and costs the
// sprint the upward excursion it needs to reach target. An earlier measurement
// appeared to show these throttles helping; that was a modelling error — halting
// dropped the trade's P&L entirely instead of realising the loss at the stop.
// Once the loss is realised, an in-sample search over the on/off assignment
// chooses OFF for every sleeve.
//
// So: prop_daily_halt_pct and prop_derisk_* are provided because a venue or a
// future book may need them, and are zero by default because for the books we
// have they destroy probability. Turning them on is a decision that should carry
// its own evidence.
//
// LIVE TARGET SEMANTICS — a deliberate, documented divergence from the study.
//
// The 86.3% measurement above was produced from CLOSED-trade P&L: the offline
// stream data could express nothing else, so "target reached" there meant
// realised equity crossing +prop_target_pct. The live check in
// QM_PropEntryAllowed deliberately uses ACCOUNT_EQUITY instead, which INCLUDES
// floating P&L on still-open positions. This mismatch is intentional and is NOT
// reconciled by changing either side: ACCOUNT_EQUITY is the correct LIVE
// semantic — a challenge is scored on equity, and we want to lock the +10% the
// instant it exists on the book, realised or floating — whereas closed P&L was
// merely the only thing the backtest streams could measure. The operational
// consequence is that live may trip the target slightly earlier than the study
// would have, on an unrealised excursion; QM_PropFlattenAll then realises that
// excursion by closing the book. Do not "fix" this by switching the live check
// to closed P&L to match the study — that would defeat the feature's purpose.

input group "Prop Firm (challenge accounts)"
input bool   prop_enabled              = false;   // master switch; false = framework unchanged
input string prop_venue                = "FTMO";  // recorded in telemetry only
input double prop_start_balance        = 0.0;     // 0 = capture at first init and persist
input double prop_target_pct           = 10.0;    // profit target, % of start balance
input bool   prop_flatten_at_target    = true;    // MEASURED +28.8pp — see header
input double prop_daily_halt_pct       = 0.0;     // self-imposed daily stop; 0 = off
input double prop_derisk_at_loss_pct   = 0.0;     // shrink size below this drawdown; 0 = off
input double prop_derisk_scale         = 1.0;     // size multiplier once below it
input bool   prop_anchor_risk_to_start = true;    // size off start balance, not live equity

double   g_qm_prop_start_balance   = 0.0;
double   g_qm_prop_day_start_eq    = 0.0;
int      g_qm_prop_day_key         = -1;
bool     g_qm_prop_initialized     = false;
bool     g_qm_prop_target_reached  = false;
bool     g_qm_prop_day_halted      = false;
string   g_qm_prop_state_file      = "";
CTrade   g_qm_prop_trade;

int QM_PropDayKey(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.year * 10000 + s.mon * 100 + s.day;
  }

// State must survive terminal restarts: a challenge runs for weeks, and a
// restart that forgets the start balance would silently re-anchor the target to
// whatever the balance happens to be that morning.
//
// The file lives under FILE_COMMON, which is shared by EVERY terminal on this
// machine. Two accounts running the same EA therefore collide unless the state
// is namespaced per account. It is keyed by ea_id + login + server in the file
// NAME, and the account login is also recorded INSIDE the file so a stale or
// mis-copied file cannot feed one account another account's start balance or
// target flag (see QM_PropLoadState).
bool QM_PropSaveState()
  {
   if(g_qm_prop_state_file == "")
      return false;
   int h = FileOpen(g_qm_prop_state_file, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, StringFormat("%I64d;%.2f;%d\n",
                                   AccountInfoInteger(ACCOUNT_LOGIN),
                                   g_qm_prop_start_balance,
                                   g_qm_prop_target_reached ? 1 : 0));
   FileClose(h);
   return true;
  }

bool QM_PropLoadState()
  {
   if(g_qm_prop_state_file == "" ||
      !FileIsExist(g_qm_prop_state_file, FILE_COMMON))
      return false;
   int h = FileOpen(g_qm_prop_state_file, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   string line = FileReadString(h);
   FileClose(h);
   string parts[];
   if(StringSplit(line, ';', parts) < 3)
      return false;
   // Defence in depth against the shared FILE_COMMON namespace: refuse any file
   // whose recorded login does not match the account we are actually attached
   // to, rather than trusting the balance/target it carries.
   const long recorded_login = (long)StringToInteger(parts[0]);
   const long current_login  = AccountInfoInteger(ACCOUNT_LOGIN);
   if(recorded_login != current_login)
     {
      QM_LogEvent(QM_WARN, "prop_state_account_mismatch",
                  StringFormat("{\"recorded_login\":%I64d,\"current_login\":%I64d,"
                               "\"action\":\"ignore_state\"}",
                               recorded_login, current_login));
      return false;
     }
   double bal = StringToDouble(parts[1]);
   if(bal <= 0.0)
      return false;
   g_qm_prop_start_balance  = bal;
   g_qm_prop_target_reached = (StringToInteger(parts[2]) == 1);
   return true;
  }

bool QM_PropInit(const int ea_id)
  {
   g_qm_prop_initialized    = false;
   g_qm_prop_target_reached = false;
   g_qm_prop_day_halted     = false;
   if(!prop_enabled)
      return true;

   // Namespace the shared-FILE_COMMON state per account so two accounts running
   // the same EA cannot read or overwrite each other's start balance / target.
   const long   login  = AccountInfoInteger(ACCOUNT_LOGIN);
   const string server = QM_LoggerSanitizeSlug(AccountInfoString(ACCOUNT_SERVER));
   g_qm_prop_state_file = StringFormat("QM\\prop\\%d_%I64d_%s.state",
                                       ea_id, login, server);

   if(!QM_PropLoadState())
     {
      g_qm_prop_start_balance = (prop_start_balance > 0.0)
                                ? prop_start_balance
                                : AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_qm_prop_start_balance <= 0.0)
        {
         QM_LogEvent(QM_ERROR, "prop_init_no_balance",
                     "{\"reason\":\"cannot anchor challenge start balance\"}");
         return false;
        }
      QM_PropSaveState();
     }

   g_qm_prop_day_key      = QM_PropDayKey(TimeCurrent());
   g_qm_prop_day_start_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_qm_prop_initialized  = true;

   QM_LogEvent(QM_INFO, "prop_init",
               StringFormat("{\"venue\":\"%s\",\"start_balance\":%.2f,"
                            "\"target_pct\":%.2f,\"flatten_at_target\":%s,"
                            "\"daily_halt_pct\":%.2f,\"derisk_at_pct\":%.2f,"
                            "\"derisk_scale\":%.2f,\"risk_anchor\":\"%s\"}",
                            QM_LoggerEscapeJson(prop_venue),
                            g_qm_prop_start_balance, prop_target_pct,
                            prop_flatten_at_target ? "true" : "false",
                            prop_daily_halt_pct, prop_derisk_at_loss_pct,
                            prop_derisk_scale,
                            prop_anchor_risk_to_start ? "start_balance" : "equity"));
   return true;
  }

// The balance risk sizing is computed against. RISK_PERCENT normally sizes off
// live equity, which drifts upward as the challenge gains and so does not
// reproduce the RISK_FIXED behaviour every backtest used. Anchoring to the start
// balance keeps deployed size equal to what was measured.
double QM_PropRiskBasis(const double fallback)
  {
   if(!prop_enabled || !g_qm_prop_initialized || !prop_anchor_risk_to_start)
      return fallback;
   return g_qm_prop_start_balance;
  }

double QM_PropRiskScale()
  {
   if(!prop_enabled || !g_qm_prop_initialized)
      return 1.0;
   if(prop_derisk_at_loss_pct <= 0.0)
      return 1.0;
   const double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   const double down = (g_qm_prop_start_balance - eq) / g_qm_prop_start_balance * 100.0;
   return (down >= prop_derisk_at_loss_pct) ? prop_derisk_scale : 1.0;
  }

void QM_PropFlattenAll(const long magic, const string reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!g_qm_prop_trade.PositionClose(ticket))
         QM_LogEvent(QM_ERROR, "prop_flatten_failed",
                     StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"retcode\":%d}",
                                  ticket, QM_LoggerEscapeJson(reason),
                                  g_qm_prop_trade.ResultRetcode()));
     }
  }

// How many positions for this magic are still open. Used to CONFIRM a flatten
// actually emptied the book before the challenge state is recorded as halted.
int QM_PropOpenPositions(const long magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      n++;
     }
   return n;
  }

// Call once per tick, before entry logic. Returns false when the EA must not
// open new positions.
bool QM_PropEntryAllowed(const long magic)
  {
   if(!prop_enabled || !g_qm_prop_initialized)
      return true;

   const int today = QM_PropDayKey(TimeCurrent());
   if(today != g_qm_prop_day_key)
     {
      g_qm_prop_day_key      = today;
      g_qm_prop_day_start_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      g_qm_prop_day_halted   = false;
     }

   if(g_qm_prop_target_reached)
      return false;

   const double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   const double target = g_qm_prop_start_balance * (1.0 + prop_target_pct / 100.0);

   if(prop_flatten_at_target && eq >= target)
     {
      // Order matters: flatten FIRST, and only persist the halted state once the
      // book is confirmed empty for this magic. If a close fails, leave the
      // state unwritten (target_reached stays false) so the next tick retries —
      // recording "target reached and halted" while positions are still open
      // would strand live exposure behind a flag that says we are flat.
      QM_PropFlattenAll(magic, "target_reached");
      const int remaining = QM_PropOpenPositions(magic);
      if(remaining == 0)
        {
         g_qm_prop_target_reached = true;
         QM_PropSaveState();
         QM_LogEvent(QM_INFO, "prop_target_reached",
                     StringFormat("{\"equity\":%.2f,\"target\":%.2f,\"action\":\"flat_and_halt\"}",
                                  eq, target));
        }
      else
        {
         QM_LogEvent(QM_WARN, "prop_target_flatten_pending",
                     StringFormat("{\"equity\":%.2f,\"target\":%.2f,\"remaining\":%d,"
                                  "\"action\":\"retry_next_tick\"}",
                                  eq, target, remaining));
        }
      return false;
     }

   if(prop_daily_halt_pct > 0.0)
     {
      const double day_pnl_pct =
         (eq - g_qm_prop_day_start_eq) / g_qm_prop_start_balance * 100.0;
      if(day_pnl_pct <= -prop_daily_halt_pct)
        {
         if(!g_qm_prop_day_halted)
           {
            g_qm_prop_day_halted = true;
            QM_PropFlattenAll(magic, "daily_halt");
            QM_LogEvent(QM_INFO, "prop_daily_halt",
                        StringFormat("{\"day_pnl_pct\":%.2f,\"limit_pct\":%.2f}",
                                     day_pnl_pct, prop_daily_halt_pct));
           }
         return false;
        }
     }

   return true;
  }

#endif // QM_PROP_FIRM_MQH
