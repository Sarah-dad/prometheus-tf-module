
# Prometheus module

The goal of this module is to create a monitoring stack by using prometheus. 

## Inputs

| Name | Description | Default | Required |
|------|-------------|:-----:|:-----:|
| ami | The ID of the AMI that has Prometheus installed. | - | yes |
| key_pair_name | The name of the AWS Keypair. | - | yes |
| name | The name used to namespace resources created by this module | - | yes |
| port | The port grafana should listen on for HTTP requests | - | yes |
| vpc_id |  | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| url | # Output the URL of the EC2 instance after the templates are applied |

