flake: { config, lib, pkgs, ... }:

let
  inherit (lib) types mkEnableOption mkOption;

  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) amazon-cloudwatch-agent;

  cfg = config.services.amazon-cloudwatch-agent;
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
    users.users.cwagent = {
      description = "amazon-cloudwatch-agent daemon user";
      isSystemUser = true;
      group = "cwagent";
    };

    users.groups.cwagent = { };

    systemd.services.amazon-cloudwatch-agent = {
      description = "amazon-cloudwatch-agent";
      documentation = [ "https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html" ];

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "cwagent";
        Group = "cwagent";
        Restart = "always";
        ExecStart = "${lib.getBin cfg.package}/bin/start-amazon-cloudwatch-agent  -c \"${config.services.amazon-cloudwatch-agent.dataDir}\"";
      };

      preStart = ''
        installedConfigFile="${config.services.amazon-cloudwatch-agent.dataDir}/config.json"
        install -d -m750 ${config.services.amazon-cloudwatch-agent.dataDir}/logs
      '';
    };
  };
}
