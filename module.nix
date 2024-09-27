flake: { config, lib, pkgs, ... }:

let
  inherit (lib) types mkEnableOption mkOption;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) amazon-cloudwatch-agent;

  cfg = config.services.amazon-cloudwatch-agent;
  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  commonConfigurationFile = tomlFormat.generate "common-config.toml" cfg.commonConfiguration;
  configurationFile = jsonFormat.generate "amazon-cloudwatch-agent.json" cfg.configuration;

  initConfigFile = ./config.json;
in
{
  options.services.amazon-cloudwatch-agent = {
    enable = lib.mkEnableOption "Amazon CloudWatch Agent";
    package = lib.mkPackageOption pkgs "amazon-cloudwatch-agent" { };
    commonConfiguration = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Amazon CloudWatch Agent common configuration. See
        <https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-commandline-fleet.html#CloudWatch-Agent-profile-instance-first>
        for supported values.
      '';
      example = {
        credentials = {
          shared_credential_profile = "{profile_name}";
          shared_credential_file = "{file_name}";
        };
        proxy = {
          http_proxy = "{http_url}";
          https_proxy = "{https_url}";
          no_proxy = "{domain}";
        };
      };
    };
    configuration = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Amazon CloudWatch Agent configuration. See
        <https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html>
        for supported values.
      '';
      # Subset of "CloudWatch agent configuration file: Complete examples" and "CloudWatch agent configuration file: Traces section" in the description link.
      #
      # Log file path changed from "/opt/aws/amazon-cloudwatch-agent/logs" to "/var/log/amazon-cloudwatch-agent".
      example = {
        agent = {
          metrics_collection_interval = 10;
          logfile = "/var/log/amazon-cloudwatch-agent/amazon-cloudwatch-agent.log";
        };
        metrics = {
          namespace = "MyCustomNamespace";
          metrics_collected = {
            cpu = {
              resource = [ "*" ];
              measurement = [
                {
                  name = "cpu_usage_idle";
                  rename = "CPU_USAGE_IDLE";
                  unit = "Percent";
                }
                {
                  name = "cpu_usage_nice";
                  unit = "Percent";
                }
                "cpu_usage_guest"
              ];
              totalcpu = false;
              metrics_collection_interval = 10;
              append_dimensions = {
                customized_dimension_key_1 = "customized_dimension_value_1";
                customized_dimension_key_2 = "customized_dimension_value_2";
              };
            };
          };
        };
        logs = {
          logs_collected = {
            files = {
              collect_list = [
                {
                  file_path = "/var/log/amazon-cloudwatch-agent/amazon-cloudwatch-agent.log";
                  log_group_name = "amazon-cloudwatch-agent.log";
                  log_stream_name = "amazon-cloudwatch-agent.log";
                  timezone = "UTC";
                }
              ];
            };
          };
          log_stream_name = "my_log_stream_name";
          force_flush_interval = 15;
        };
        traces = {
          traces_collected = {
            xray = { };
            oltp = { };
          };
        };
      };
    };
    mode = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        Amazon CloudWatch Agent mode. Indicates whether the agent is running in EC2 ("ec2"), on-premises ("onPremise"),
        or if it should guess based on metadata endpoints like IMDS or the ECS task metadata endpoint ("auto").
      '';
      example = "onPremise";
    };
    dataDir = mkOption {
      type = types.str;
      default = "/opt/aws/amazon-cloudwatch-agent";
      description = lib.mdDoc ''
        The path where amazon-cloudwatch-agent keeps its config, and logs.
      '';
    };
  };
  # options = {
  #   services.amazon-cloudwatch-agent = {
  #     enable = mkEnableOption ''
  #       Amazon CloudWatch Amazon
  #     '';

  #     dataDir = mkOption {
  #       type = types.str;
  #       default = "/opt/aws/amazon-cloudwatch-agent";
  #       description = lib.mdDoc ''
  #         The path where amazon-cloudwatch-agent keeps its config, and logs.
  #       '';
  #     };

  #     package = mkOption {
  #       type = types.package;
  #       default = amazon-cloudwatch-agent;
  #       description = ''
  #         The package to use with the service.
  #       '';
  #     };
  #   };
  # };

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

        ${config.services.amazon-cloudwatch-agent.dataDir}/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/config.json

        # GEN /opt/aws/amazon-cloudwatch-agent/etc/env-config.json
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_config.json
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.yaml
        # GEN /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml

      '';
    };
  };
}
