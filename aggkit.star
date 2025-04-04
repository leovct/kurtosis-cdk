data_availability_package = import_module("./lib/data_availability.star")
aggkit_package = import_module("./lib/aggkit.star")
databases = import_module("./databases.star")
zkevm_bridge_package = import_module("./lib/zkevm_bridge.star")


def run(plan, args, contract_setup_addresses, sovereign_contract_setup_addresses):
    db_configs = databases.get_db_configs(
        args["deployment_suffix"], args["sequencer_type"]
    )

    keystore_artifacts = get_keystores_artifacts(plan, args)

    # Create the cdk aggoracle config.
    aggkit_config_template = read_file(src="./templates/aggkit/aggkit-config.toml")
    aggkit_config_artifact = plan.render_templates(
        name="cdk-aggoracle-config-artifact",
        config={
            "config.toml": struct(
                template=aggkit_config_template,
                data=args
                | {
                    "is_cdk_validium": data_availability_package.is_cdk_validium(args),
                }
                | db_configs
                | contract_setup_addresses
                | sovereign_contract_setup_addresses,
            )
        },
    )

    sovereign_genesis_file = read_file(src=args["sovereign_genesis_file"])
    sovereign_genesis_artifact = plan.render_templates(
        name="sovereign_genesis",
        config={"genesis.json": struct(template=sovereign_genesis_file, data={})},
    )

    # Start the aggoracle components.
    aggkit_configs = aggkit_package.create_aggkit_service_config(
        args, aggkit_config_artifact, sovereign_genesis_artifact, keystore_artifacts
    )

    plan.add_services(
        configs=aggkit_configs,
        description="Starting the cdk aggkit components",
    )

    # Start the bridge service.
    bridge_config_artifact = create_bridge_config_artifact(
        plan,
        args,
        contract_setup_addresses,
        sovereign_contract_setup_addresses,
        db_configs,
    )
    bridge_service_config = zkevm_bridge_package.create_bridge_service_config(
        args, bridge_config_artifact, keystore_artifacts.claimtx
    )
    plan.add_service(
        name="sovereign-bridge-service" + args["deployment_suffix"],
        config=bridge_service_config,
    )


def get_keystores_artifacts(plan, args):
    aggoracle_keystore_artifact = plan.store_service_files(
        name="aggoracle-keystore",
        service_name="contracts" + args["deployment_suffix"],
        src="/opt/zkevm/aggoracle.keystore",
    )
    sovereignadmin_keystore_artifact = plan.store_service_files(
        name="sovereignadmin-keystore",
        service_name="contracts" + args["deployment_suffix"],
        src="/opt/zkevm/sovereignadmin.keystore",
    )
    claimtx_keystore_artifact = plan.store_service_files(
        name="claimtxmanager-keystore",
        service_name="contracts" + args["deployment_suffix"],
        src="/opt/zkevm/claimtxmanager.keystore",
    )
    return struct(
        aggoracle=aggoracle_keystore_artifact,
        sovereignadmin=sovereignadmin_keystore_artifact,
        claimtx=claimtx_keystore_artifact,
    )


def create_bridge_config_artifact(
    plan, args, contract_setup_addresses, sovereign_contract_setup_addresses, db_configs
):
    bridge_config_template = read_file(
        src="./templates/bridge-infra/bridge-config.toml"
    )
    l1_rpc_url = args["mitm_rpc_url"].get("aggkit", args["l1_rpc_url"])
    l2_rpc_url = args["op_el_rpc_url"]
    contract_addresses = contract_setup_addresses | {
        "zkevm_rollup_address": sovereign_contract_setup_addresses.get(
            "sovereign_rollup_addr"
        ),
        "zkevm_bridge_l2_address": sovereign_contract_setup_addresses.get(
            "sovereign_bridge_proxy_addr"
        ),
        "zkevm_global_exit_root_l2_address": sovereign_contract_setup_addresses.get(
            "sovereign_ger_proxy_addr"
        ),
    }
    return plan.render_templates(
        name="sovereign-bridge-config-artifact",
        config={
            "bridge-config.toml": struct(
                template=bridge_config_template,
                data={
                    "global_log_level": args["global_log_level"],
                    "zkevm_l2_keystore_password": args["zkevm_l2_keystore_password"],
                    "db": db_configs.get("sovereign_bridge_db"),
                    "require_sovereign_chain_contract": True,
                    # rpc urls
                    "l1_rpc_url": l1_rpc_url,
                    "l2_rpc_url": l2_rpc_url,
                    # ports
                    "grpc_port_number": args["zkevm_bridge_grpc_port"],
                    "rpc_port_number": args["zkevm_bridge_rpc_port"],
                    "metrics_port_number": args["zkevm_bridge_metrics_port"],
                }
                | contract_addresses,
            )
        },
    )
