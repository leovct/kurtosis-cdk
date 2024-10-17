def run_zkevm_sequence_sender(
    plan, args, genesis_artifact, sequencer_keystore_artifact
):
    config_artifact = plan.render_templates(
        name="zkevm-sequence-sender-config-artifact",
        config={
            "zkevm-sequence-sender-config.toml": struct(
                data=args
                | {
                    "zkevm_is_validium": data_availability_package.is_cdk_validium(
                        args
                    ),
                },
                template=read_file(
                    src="../templates/trusted-node/zkevm-sequence-sender-config.toml"
                ),
            ),
        },
    )

    plan.add_service(
        name="zkevm-sequence-sender" + args["deployment_suffix"],
        config=ServiceConfig(
            image=args["zkevm_sequence_sender_image"],
            files={
                "/etc/zkevm": Directory(
                    artifact_names=[
                        config_artifact,
                        genesis_artifact,
                        sequencer_keystore_artifact,
                    ]
                )
            },
            cmd=[
                "/bin/sh",
                "-c",
                "/app/zkevm-seqsender run --network custom --custom-network-file /etc/zkevm/genesis.json --cfg /etc/zkevm/zkevm-sequence-sender-config.toml",
            ],
        ),
    )


def run_zkevm_aggregator(
    plan,
    args,
    db_configs,
    genesis_artifact,
    aggregator_keystore_artifact,
):
    config_artifact = plan.render_templates(
        name="zkevm-aggregator-config-artifact",
        config={
            "zkevm-aggregator-config.toml": struct(
                data=args
                | {
                    "zkevm_is_validium": data_availability_package.is_cdk_validium(
                        args
                    ),
                },
                template=read_file(
                    src="../templates/trusted-node/zkevm-aggregator-config.toml"
                ),
            ),
        },
    )

    plan.add_service(
        name="zkevm-aggregator" + args["deployment_suffix"],
        config=ServiceConfig(
            image=args["zkevm_aggregator_image"],
            ports={
                "aggregator": PortSpec(
                    args["zkevm_aggregator_port"], application_protocol="grpc"
                ),
            },
            files={
                "/etc/zkevm": Directory(
                    artifact_names=[
                        config_artifact,
                        genesis_artifact,
                        aggregator_keystore_artifact,
                    ]
                )
            },
            cmd=[
                "/bin/sh",
                "-c",
                "/app/zkevm-aggregator run --network custom --custom-network-file /etc/zkevm/genesis.json --cfg /etc/zkevm/zkevm-aggregator-config.toml",
            ],
        ),
    )
