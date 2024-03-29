{ lib, buildGoModule, fetchgit }:

buildGoModule rec {
  pname = "amazon-cloudwatch-agent";
  version = "1.300032.3";

  src = fetchgit {
    url = "https://github.com/aws/amazon-cloudwatch-agent.git";
    rev = "v${version}";
    sha256 = "sha256-M/SGxMkALTCSRjrMdCCEr4iHR+CzDwIlD9DC3KAVITk=";
    #sha256 = "sha256:0000000000000000000000000000000000000000000000000000";
  };

  vendorHash = "sha256-bXyFrdWsMlfapoDQdkDk6nbTvn1uEKEh68QWRWACO4g=";

  meta = with lib; {
    description = ''
      Amazon CloudWatch Agent
      '';
    homepage = "https://github.com/aws/amazon-cloudwatch-agent";
    license = licenses.mit;
  };

  doCheck = false;

  initConfigFile = ./config.json;

  patchPhase = ''

    echo "" >> Makefile
    echo "amazon-cloudwatch-agent-nixos-linux: copy-version-file" >> Makefile
    echo -e "\t@echo Building CloudWatchAgent for Linux,Debian with ARM64 and AMD64" >> Makefile
    echo -e "\t\$(LINUX_AMD64_BUILD)/config-downloader github.com/aws/amazon-cloudwatch-agent/cmd/config-downloader" >> Makefile
    echo -e "\t\$(LINUX_AMD64_BUILD)/config-translator github.com/aws/amazon-cloudwatch-agent/cmd/config-translator" >> Makefile
    echo -e "\t\$(LINUX_AMD64_BUILD)/amazon-cloudwatch-agent github.com/aws/amazon-cloudwatch-agent/cmd/amazon-cloudwatch-agent" >> Makefile
    echo -e "\t\$(LINUX_AMD64_BUILD)/start-amazon-cloudwatch-agent github.com/aws/amazon-cloudwatch-agent/cmd/start-amazon-cloudwatch-agent" >> Makefile
    echo -e "\t\$(LINUX_AMD64_BUILD)/amazon-cloudwatch-agent-config-wizard github.com/aws/amazon-cloudwatch-agent/cmd/amazon-cloudwatch-agent-config-wizard" >> Makefile

  '';

  buildPhase = ''

    export FAKEBUILD="false"

    if [ $FAKEBUILD == "true" ]
    then
      mkdir -p build/bin/linux_amd64
      touch build/bin/linux_amd64/fakebin
    else
      make amazon-cloudwatch-agent-nixos-linux
    fi

  '';

  installPhase = ''

    runHook preInstall

    mkdir -p $out/etc

    cp -av build/bin/linux_amd64 $out/bin

    ln -s ${initConfigFile} $out/config.json

    cp LICENSE $out/
    cp NOTICE $out/
    cp licensing/THIRD-PARTY-LICENSES $out/
    cp RELEASE_NOTES $out/
    cp packaging/dependencies/amazon-cloudwatch-agent-ctl $out/bin/
    cp cfg/commonconfig/common-config.toml $out/etc/

    # TODO in patchPhase

    mkdir -p /tmp/amazon-cloudwatch-agent
    touch /tmp/amazon-cloudwatch-agent/amazon-cloudwatch-agent.log
    ln -s /tmp/amazon-cloudwatch-agent/log $out/log

    runHook postInstall
    '';

  postInstall = ''
    echo Here are the commands executed after installPhase
  '';
}
