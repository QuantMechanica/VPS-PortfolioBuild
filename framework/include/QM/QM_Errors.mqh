#ifndef QM_ERRORS_MQH
#define QM_ERRORS_MQH

// V5 Framework Step 01:
// Named error codes only (no logic), exposed as string constants.
const string EA_INPUT_RISK_BOTH_ZERO                = "EA_INPUT_RISK_BOTH_ZERO";
const string EA_INPUT_RISK_BOTH_SET                 = "EA_INPUT_RISK_BOTH_SET";
const string EA_INPUT_RISK_MODE_MISMATCH            = "EA_INPUT_RISK_MODE_MISMATCH";
const string EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE = "EA_INPUT_PORTFOLIO_WEIGHT_OUT_OF_RANGE";
const string EA_INPUT_GROUP_MISSING                 = "EA_INPUT_GROUP_MISSING";
const string EA_MAGIC_COLLISION_DETECTED            = "EA_MAGIC_COLLISION_DETECTED";
const string EA_MAGIC_NOT_REGISTERED                = "EA_MAGIC_NOT_REGISTERED";
const string EA_ML_FORBIDDEN                        = "EA_ML_FORBIDDEN";
const string EA_GRID_RISK_EXCEEDED                  = "EA_GRID_RISK_EXCEEDED";

const string SETUP_DATA_MISSING                     = "SETUP_DATA_MISSING";
const string SETUP_DATA_MISMATCH                    = "SETUP_DATA_MISMATCH";
const string SETUP_DATA_STALE                       = "SETUP_DATA_STALE";

const string KS_DAILY_LOSS                          = "KS_DAILY_LOSS";
const string KS_PORTFOLIO_DD                        = "KS_PORTFOLIO_DD";
const string KS_MANUAL                              = "KS_MANUAL";

const string BROKER_REQUOTE                         = "BROKER_REQUOTE";
const string BROKER_OFF_QUOTE                       = "BROKER_OFF_QUOTE";
const string BROKER_NOT_ENOUGH_MONEY                = "BROKER_NOT_ENOUGH_MONEY";
const string BROKER_TRADE_DISABLED                  = "BROKER_TRADE_DISABLED";
const string BROKER_INVALID_VOLUME                  = "BROKER_INVALID_VOLUME";
const string BROKER_OTHER                           = "BROKER_OTHER";

#endif // QM_ERRORS_MQH
