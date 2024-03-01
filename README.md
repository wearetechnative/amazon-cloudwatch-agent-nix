## Amazon CloudWatch Agent on NixOS

Flake to install's the CloudWatch Agent on NixOS.

## TODO

- more configuration options
- more documentation
- PR for nixpkgs

## Usage

This is how you Install Amazon CloudWatch Agent on NixOS. In the inputs of your
flake, add the Amazon CloudWatch Agent flake.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    amazon-cloudwatch-agent.url = "github:mipmip/amazon-cloudwatch-agent-nix";
  }
}
```

Then you will need to import the module and also add the cloudwatch agent
software to the system packages.

Below is an example setup.

```nix
{
  description = "NixOS configuration Amazon CloudWatch Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    amazon-cloudwatch-agent.url = "github:mipmip/amazon-cloudwatch-agent-nix";
  };

  outputs = { self, nixpkgs, amazon-cloudwatch-agent }:
    let
      system = "x86_64-linux";

      amazon-cloudwatch-module = amazon-cloudwatch-agent.nixosModules.default;
      amazon-cloudwatch-config = {
        services.amazon-cloudwatch-agent.enable = true;
        environment.systemPackages = [
         amazon-cloudwatch-agent.packages."${system}".amazon-cloudwatch-agent
        ];
      };

    in {
      nixosConfigurations."<hostname>" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          amazon-cloudwatch-module
          amazon-cloudwatch-config
          ./configuration.nix
        ];
      };
    };
}
```

## Give CloudWatch Agent permission to publish to CloudWatch

Once the agent is installed, you just need to make sure it has permission to
publish its metrics to CloudWatch. You grant this permission by adding a policy
to the IAM Instance Profile.

Below is an example piece of Terraform code on how to add this to your EC2
profile.

```hcl
resource "aws_iam_instance_profile" "ssm-access-iam-profile" {
  name = "ec2_profile"
  role = aws_iam_role.ssm-access-iam-role.name
}

resource "aws_iam_role" "ssm-access-iam-role" {
  name        = "ssm-access-role"
  description = "The role to access EC2 with SSM"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch-policy" {
  role       = aws_iam_role.ssm-access-iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```




## credits

- https://github.com/reckenrode/nix-foundryvtt - used as example for module
