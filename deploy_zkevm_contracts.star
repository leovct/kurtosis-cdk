data_availability_package = import_module("./lib/data_availability.star")

CONTRACT_DEPLOY_ARTIFACTS = [
    {
        "name": "deploy_parameters.json",
        "file": "./templates/contract-deploy/deploy_parameters.json",
    },
    {
        "name": "create_rollup_parameters.json",
        "file": "./templates/contract-deploy/create_rollup_parameters.json",
    },
    {
        "name": "run-contract-setup.sh",
        "file": "./templates/contract-deploy/run-contract-setup.sh",
    },
    {
        "name": "create-keystores.sh",
        "file": "./templates/contract-deploy/create-keystores.sh",
    },
    {
        "name": "update-ger.sh",
        "file": "./templates/contract-deploy/update-ger.sh",
    },
]

ZKEVM_ARTIFACTS = [
    {
        "name": "genesis.json",
        "file": "./templates/contract-deploy/genesis.json",
    },
    {
        "name": "combined.json",
        "file": "./templates/contract-deploy/combined.json",
    },
    {
        "name": "dynamic-kurtosis-conf.json",
        "file": "./templates/contract-deploy/dynamic-kurtosis-conf.json",
    },
    {
        "name": "dynamic-kurtosis-allocs.json",
        "file": "./templates/contract-deploy/dynamic-kurtosis-allocs.json",
    },
]


def render_templates(plan, args, artifact_configs):
    artifacts = []
    for artifact_cfg in artifact_configs:
        template = read_file(src=artifact_cfg["file"])
        artifact = plan.render_templates(
            name=artifact_cfg["name"],
            config={
                artifact_cfg["name"]: struct(
                    template=template,
                    data=args
                    | {
                        "is_cdk_validium": data_availability_package.is_cdk_validium(
                            args
                        ),
                        "zkevm_rollup_consensus": data_availability_package.get_consensus_contract(
                            args
                        ),
                    },
                )
            },
        )
        artifacts.append(artifact)
    return artifacts


def run(plan, args):
    # Render templates.
    contract_deploy_artifacts = render_templates(
        plan, args, list(CONTRACT_DEPLOY_ARTIFACTS)
    )
    zkevm_artifacts = []

    # If we are configured to use a previous deployment, we'll dynamically add artifacts for the
    # genesis and combined outputs.
    if args.get("use_previously_deployed_contracts", False):
        zkevm_artifacts = render_templates(plan, args, list(ZKEVM_ARTIFACTS))

    # Create helper service to deploy contracts
    contracts_service_name = "contracts" + args["deployment_suffix"]
    plan.add_service(
        name=contracts_service_name,
        config=ServiceConfig(
            image=args["zkevm_contracts_image"],
            files={
                "/opt/zkevm": Directory(artifact_names=zkevm_artifacts),
                "/opt/contract-deploy/": Directory(
                    artifact_names=contract_deploy_artifacts
                ),
            },
            # These two lines are only necessary to deploy to any Kubernetes environment (e.g. GKE).
            entrypoint=["bash", "-c"],
            cmd=["sleep infinity"],
            user=User(uid=0, gid=0),  # Run the container as root user.
        ),
    )

    # Deploy contracts.
    # plan.exec(
    #     description="Deploying zkevm contracts on L1",
    #     service_name=contracts_service_name,
    #     recipe=ExecRecipe(
    #         command=[
    #             "/bin/sh",
    #             "-c",
    #             "chmod +x {0} && {0}".format(
    #                 "/opt/contract-deploy/run-contract-setup.sh"
    #             ),
    #         ]
    #     ),
    # )

    # Create keystores.
    plan.exec(
        description="Creating keystores for zkevm-node/cdk-validium components",
        service_name=contracts_service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "chmod +x {0} && {0}".format(
                    "/opt/contract-deploy/create-keystores.sh"
                ),
            ]
        ),
    )

    # Store CDK configs.
    plan.store_service_files(
        name="cdk-erigon-node-chain-config",
        service_name=contracts_service_name,
        src="/opt/zkevm/dynamic-kurtosis-conf.json",
    )

    plan.store_service_files(
        name="cdk-erigon-node-chain-allocs",
        service_name=contracts_service_name,
        src="/opt/zkevm/dynamic-kurtosis-allocs.json",
    )

    # Force update GER.
    # plan.exec(
    #     description="Update the GER so the L1 Info Tree Index is greater than 0",
    #     service_name=contracts_service_name,
    #     recipe=ExecRecipe(
    #         command=[
    #             "/bin/sh",
    #             "-c",
    #             "chmod +x {0} && {0}".format("/opt/contract-deploy/update-ger.sh"),
    #         ]
    #     ),
    # )
