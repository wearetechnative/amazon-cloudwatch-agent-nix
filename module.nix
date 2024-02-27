flake: { config, lib, pkgs, ... }:

let
  inherit (lib) types mkEnableOption mkOption;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) amazon-cloudwatch-agent;

  cfg = config.services.amazon-cloudwatch-agent;

  initConfigFile = ./config.json;
in
{
  options = {
    services.amazon-cloudwatch-agent = {
      enable = mkEnableOption ''
        Amazon CloudWatch Amazon
      '';

      dataDir = mkOption {
        type = types.str;
        default = "/opt/aws/amazon-cloudwatch-agent";
        description = lib.mdDoc ''
          The path where amazon-cloudwatch-agent keeps its config, and logs.
        '';
      };

      package = mkOption {
        type = types.package;
        default = amazon-cloudwatch-agent;
        description = ''
          The package to use with the service.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
#    users.users.cwagent = {
#      description = "amazon-cloudwatch-agent daemon user";
#      isSystemUser = true;
#      group = "cwagent";
#    };
#
#    users.groups.cwagent = { };

    systemd.services.amazon-cloudwatch-agent = {
      enable = true;
      description = "Amazon CloudWatch Agent";
      documentation = [ "https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html" ];

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

#      unitConfig = {
#        Type = "simple";
#      };

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 60;
        KillMode="control-group";
        User = "root";
        Group = "root";
        ExecStart = "${lib.getBin cfg.package}/bin/start-amazon-cloudwatch-agent  -c \"${config.services.amazon-cloudwatch-agent.dataDir}\"";
      };

      preStart = ''

        install -d -m750 ${config.services.amazon-cloudwatch-agent.dataDir}/{bin,var,logs,etc}
        install -d -m750 ${config.services.amazon-cloudwatch-agent.dataDir}/etc/amazon-cloudwatch-agent.d

        ln -sf ${initConfigFile} ${config.services.amazon-cloudwatch-agent.dataDir}/config.json
        ln -sf ${lib.getBin cfg.package}/etc/common-config.toml ${config.services.amazon-cloudwatch-agent.dataDir}/etc/common-config.toml

        ln -sf ${lib.getBin cfg.package}/bin/config-translator ${config.services.amazon-cloudwatch-agent.dataDir}/bin/config-translator
        ln -sf ${lib.getBin cfg.package}/bin/config-downloader ${config.services.amazon-cloudwatch-agent.dataDir}/bin/config-downloader
        ln -sf ${lib.getBin cfg.package}/bin/amazon-cloudwatch-agent ${config.services.amazon-cloudwatch-agent.dataDir}/bin/amazon-cloudwatch-agent
        ln -sf ${lib.getBin cfg.package}/bin/amazon-cloudwatch-agent-ctl ${config.services.amazon-cloudwatch-agent.dataDir}/bin/amazon-cloudwatch-agent-ctl

        ${config.services.amazon-cloudwatch-agent.dataDir}/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/config.json

        # GEN /opt/aws/amazon-cloudwatch-agent/etc/env-config.json
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_config.json
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.yaml
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml

      '';
    };
  };
}
