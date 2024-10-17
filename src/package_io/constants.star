GLOBAL_LOG_LEVEL = struct(
    error="error",
    warn="warn",
    info="info",
    debug="debug",
    trace="trace",
)

SEQUENCER_TYPE = struct(
    CDK_ERIGON="erigon",
    ZKEVM="zkevm",
)

SEQUENCER_NAME = struct(
    CDK_ERIGON="cdk-erigon-sequencer",
    ZKEVM="zkevm-node-sequencer",
)

SEQUENCE_SENDER_AGGREGATOR_TYPE = struct(
    cdk="cdk",
    legacy_zkevm="legacy-zkevm",
    new_zkevm="new-zkevm",
)

TX_SPAMMER_IMG = "leovct/toolbox:0.0.4"
