# :seedling: edb-terraform

A tool for generating Terraform projects using pre-defined templates and modules. It simplifies the creation of target cloud resources for automation by leveraging an easy-to-use YAML configuration. This tool supports setting of IPs, image configurations, and the creation of simple clusters which can be divided into subnets. It also provides basic cross-region support.

> :information_source:  
> Supported [providers and components](./docs/SUPPORTED.md)

## :nut_and_bolt: Prerequisites

The following components must be installed on the system:
- [Terraform >= 1.3.6, <= 1.5.5](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform)
- Python >= 3.8
- Bash
- [JQ >= 1.6](https://jqlang.github.io/jq/download/)
- Cloud provider cli tool with credentials configured
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [GCloud CLI](https://cloud.google.com/sdk/docs/install-sdk)
  - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
  - [BigAnimal CLI](https://www.enterprisedb.com/docs/biganimal/latest/reference/cli/)

> :information_source:  
> Refer to official documentation for credential management and environment specific installation.  
> For quick examples of setup, please refer to the [setup guide](./docs/SETUP.md).  
> [Credential setup](./docs/CREDENTIALS.md)  

## :zap: Quick start
```bash
git clone https://github.com/EnterpriseDB/edb-terraform.git
python3 -m venv venv-terraform
source venv-terraform/bin/activate
python -m pip install ./edb-terraform/
edb-terraform generate \
  --project-name example \
  --cloud-service-provider aws \
  --infra-file edb-terraform/docs/examples/aws/edb-ra-3.yml
cd example
terraform init
edb-terraform help --project-path .
terraform apply -var "force_dynamic_ip=true" -var "force_service_machines=true"
terraform destroy
```

> :warning:  
> Protect your project directory to avoid manual destruction  
> All resources are tracked with tags `terraform_id` and `terraform_hex`, if manual destruction is needed.

> :information_source:  
> Help command to list all options: `edb-terraform generate --help`  
> More examples of infrastructure files describing target cloud providers can be found inside of the [docs/examples](./docs/examples/README.md)  
> For automation, install without manual cloning: `python3 -m pip install git+https://github.com/EnterpriseDB/edb-terraform.git`

### :outbox_tray: Outputs
After resources are created,
you can access their attributes for use with other tools or for rendering with any `--user-templates`.
These values are available as:
- json with the command `terraform output -json servers`
  - python pretty print: `terraform output -json servers | python3 -m json.tool`
- yaml with a file named `servers.yml` under the project directory.
  - can be disabled with `TF_VAR_create_servers_yml=false terraform apply`
    - Created by default but will be disabled by default in a future release.
    - export for all commands: `export TF_CLI_ARGS="-var='create_servers_yml=false'"`

For accessing your machines,
the `public_ip` and `operating_system.ssh_user` values can be used and
SSH keys are named `ssh-id_rsa` and `ssh-id_rsa.pub` by default under the project directory.

```yaml
---
servers:
  machines:
    dbt2-driver:
      additional_volumes: []
      instance_type: "c5.4xlarge"
      operating_system: {"name":"debian-10-amd64","owner":"136693071363","ssh_user":"admin"}
      private_ip: "10.2.20.38"
      public_dns: "ec2-54-197-78-139.compute-1.amazonaws.com"
      public_ip: "54.197.78.139"
      region: "us-east-1"
      tags: {"Name":"dbt2-driver-Demo-Infra-d8d0a932","cluster_name":"Demo-Infra","created_by":"edb-terraform","terraform_hex":"d8d0a932","terraform_id":"2NCpMg","terraform_time":"2023-05-24T21:09:11Z","type":"dbt2-driver"}
      type: null
      zone: "us-east-1b"
    pg1:
      additional_volumes: [{"encrypted":false,"iops":5000,"mount_point":"/opt/pg_data","size_gb":20,"type":"io2"},{"encrypted":false,"iops":5000,"mount_point":"/opt/pg_wal","size_gb":20,"type":"io2"}]
      instance_type: "c5.4xlarge"
      operating_system: {"name":"Rocky-8-ec2-8.6-20220515.0.x86_64","owner":"679593333241","ssh_user":"rocky"}
      private_ip: "10.2.30.197"
      public_dns: "ec2-3-89-238-24.compute-1.amazonaws.com"
      public_ip: "3.89.238.24"
      region: "us-east-1"
      tags: {"Name":"pg1-Demo-Infra-d8d0a932","cluster_name":"Demo-Infra","created_by":"edb-terraform","terraform_hex":"d8d0a932","terraform_id":"2NCpMg","terraform_time":"2023-05-24T21:09:11Z","type":"postgres"}
      type: null
      zone: "us-east-1b"
[...]
```

### :page_with_curl: Templates
Templating is allowed for dynamic configurations:
- Infrastructure file jinja2 templating which renders during `edb-terraform generate`:
  - `--infra-file` accepts a single yaml file or jinja2 template.
  - `--infra-template-variables` accepts yaml/json as a file or string to use with the infrastructure template.
  - Use-cases:
    - Updating allowed ssh list
    - setting a desired AMI from a set of images.
    - dev, test, prod variations
- User-provided terraform templates which renders with terraform after all other resources are created:
  - `--user-templates` accepts a list of template files or template directories with file-extension `.tftpl`.
  - Use-cases:
    - config.yml for TPAExec Bare
    - inventory.yml for EDB-Ansible

> :information_source:  
> Examples of infrastructure files with templates found inside of [docs/examples/templates](./docs/examples/templates)

### :lock: State file
By default, state will be saved locally.
This can be overwritten when generating the project by passing in the `--remote-state-type` option.
The backend will be saved with an empty configuration,
  this forces `terraform init` to prompt the user or requires `-backend-config` as key-values or a filepath with key-values.

Options:
- `local` - (Default) saves state to `terraform.tfstate`.
- `cloud` - save state to cloud provider's backend offering.
- `postgres` | `postgresql` - save state to a Postgres database.
- `hashicorp` - save state to HashiCorp Consul.
- Unknown options will be written directly to `providers.tf.json` file

### :factory: Provider Versions
Terraform provider versions will be locked to a maximum version.
This version information is available within `providers.tf.json` under `terraform.required_providers` when a project is created.
Since this is a json file,
  it can be updated to accomodate new versions or remove the version to get the max version.
This avoids the need to also maintain a .terraform.hcl.lock file

### :handbag: Setup tools
There is a `setup` command available to download terraform, jq and each providers cli.
The final line in the output will be stringified json with any installed binaries path: `{"terraform":"/home/user/.edb-terraform/terraform/1.5.5/bin/terraform","jq":"/home/user/.edb-terraform/jq/1.7.1/bin/jq"}`
  These should be added to your path by linking, moving or manually installing the needed tool.
By default the maximum allowed versions are installed and to skip the installation of any tool, set `--<tool>-version` to `0`.
To avoid the need for sudo, the default install directory is: `$HOME/.edb-terraform/<tool>/<semvar-version>/bin/<tool>`
```
edb-terraform setup --help
edb-terraform setup
```

## Configurations
Each provider has a:
- set of example configurations available under the docs directory.
- spec object within `variables.tf` of its specification module.

AWS
- [spec](./edbterraform/data/terraform/aws/modules/specification/variables.tf)
- [examples](./docs/examples/aws/machines-v2.yml)

Azure
- [spec](./edbterraform/data/terraform/azure/modules/specification/variables.tf)
- [examples](./docs/examples/azure/machines-v2.yml)

GCloud
- [spec](./edbterraform/data/terraform/gcloud/modules/specification/variables.tf)
- [examples](./docs/examples/gcloud/machines-v2.yml)

### Networking
To open up ports,
they must be defined per region or per instance under the keyname `ports`.

> :warning:  
> SSH is currently required when configuring `machines` so that volumes can be formatted and mounted.  
> In the near future, we will attempt to move to provider-specific connection agents to:  
> - remove ssh requirement for machines  
> - avoid blocked connections due to improperly configured port rules or account policy restricitions.

Example:
```yaml
      # If defined under a region configuration, it will apply the rules to that region's address space.
      # If defined under a machine configuration, it will apply the rules to that instance's address space.
      ports:
        # Allow ssh access without cidrs defined since the service IPs are unknown.
        # This will require the use of cli arguments, service_cidrblocks or force_dynamic_ip, to setup the allow list.
        # force_service_machines option can be used to dynamically set ssh access per machine
        #   and if both explicit and dynamic ips are needed, set defaults to "" or omit it to avoid duplicate rules.
        - port: 22
          protocol: tcp
          description: "SSH"
          defaults: service
        # Allow instances, including cross-region, to ping.
        # Allow 9.8.7.6 to ping.
        - protocol: icmp
          description: ping
          defaults: internal
          cidrs:
            - 9.8.7.6/32
        # Allow https connections from anywhere
        - port: 443
          protocol: tcp
          description: Web service
          defaults: public
        # Allow 1.2.3.4 to connect to the postgres service
        - protocol: 5432
          protocol: tcp
          description: Postgres service
          cidrs:
            - 1.2.3.4/32
```

The keyname `defaults` can be set to reference a set of cidrblocks.
It will append a set of predefined cidrblocks to the rule's `cidrs` list:
- [`public`](./edbterraform/data/terraform/common_vars.tf) - Public cidrblocks
- [`service`](./edbterraform/data/terraform/common_vars.tf) - Service cidrblocks and dynamic ip, if configured
- `internal` - All Region cidrblocks defined within the configuration: `regions.*.cidr_block`
- `""` - No Defaults (Default)

When defining ports,
users can use 4 variables to dynamically update the allowed ips on top of adding values under the `cidrs` key.
This is meant for single time use and in most cases you should set the pre-defined cidr range.
- `service_cidrblocks` - a list of cidrblocks for service access when `defaults=service`
- `force_dynamic_ip` - use an http endpoint to get the current public ip and appended to service_cidrblocks.
- `force_service_biganimal` - append service_cidrblocks to biganimal's allow list
- `force_service_machines` - create an ssh access rule and append service_cidrblocks to each machines port rules.
  - Avoid setting a vpc-level ssh rule with `defaults` to `service` if making use of this option.
    This can cause duplicate rule conflicts depending on provider.

> :warning:  
> Policy rules might block generic rules such as `0.0.0.0/0`,  
>   which is often used by users with changing ips.  
> This can cause unexpected ssh errors since resources are available before policies are applied.  
> If possible, make use of a jump host to have a set of persistent ips.  
> Otherwise, make use of the `force_dynamic_ip` or `service_cidrblocks` options to dynamically set service ips.

> :warning:  
> Only AWS supports security groups, which allows for more flexibility with port configurations.  
> We mimic the functionality of security groups for Azure and GCloud to allow ports to be defined per instance.  

#### BigAnimal
BigAnimal controls a single VPC per project for its cluster.
Pairing can be done by setting the allow list for the provider or using vpc-peering/provider-private-connections.
- VPC peering can fail if not careful since you must not overlap the address space of each VPC.
- By default, it will allow connections from all machine instances created.
  - `allowed_machines` is a configuration option which accepts a list of machine names which are allowed to access the database.
    - Default is a wildcard to append all machine ips: `["*"]`
  - To change the allow list after provisioning, the file `terraform.tfvars.json` can be directly modified and use `terraform apply` again.

BigAnimal specific environment variables that can be used during `terraform apply`:
- `BA_API_URI` - api endpoint
  - Default: `https://portal.biganimal.com/api/v3/`
- Setting access key
  - `BA_ACCESS_KEY` (priority)
    - Go to `https://portal.biganimal.com/access-keys` to create an access token that last 1-365 days.
  - `BA_BEARER_TOKEN` (deprecated).
    - [get-token.sh script](https://raw.githubusercontent.com/EnterpriseDB/cloud-utilities/main/api/get-token.sh) requires manual intervention every:
      - New token request
      - 30 days since initial token request
      - Expired token is reused

### Environment variables
Terraform allows for top-level variables to be defined with cli arguments or environment variables.

For any variable you can define:
- Environment variables for all stages: `TF_VAR_ARGS=<CLI ARGS>`
- Environment variables for a targetted stage: `TF_VAR_ARGS_<stage>=<CLI ARGS>`
- Environment variables for root variables: `TF_VAR_<variable>=<ARGS>`
- CLI Arguments for root variables: `-var <variable>=<ARGS>`
Terraform will surface an error if an invalid variable is set with `-var` but will continue if it is set with environment variables for root variables.

Example variable:
- `TF_VAR_force_dynamic_ip=true` is the same as `-var force_dynamic_ip=true`
- `TF_VAR_service_cidrblocks='["0.0.0.0/0"]'`
- `-var "force_service_biganimal=true"`
- `-var "force_service_machines=true"`

### :open_file_folder: Project directory layout
```
.
├── edb-terraform # edb-terraform backup directory
│   ├── infrastructure.yml.j2 # infrastructure file/template
│   ├── system.yml # edb-terraform/python information
│   ├── terraform.lock.hcl # original lock file
│   ├── terraform.tfvars.yml # final terraform vars before conversion to json
│   └── variables.yml # infrastructure file variables
├── main.tf # Terraform entrypoint
├── modules # Cloud Provider Custom Modules including the specification module
│   ├── aurora
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── biganimal
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   ├── database
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── key_pair
│   │   ├── main.tf
│   │   └── output.tf
│   ├── kubernetes
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   ├── machine
│   │   ├── lsblk_devices.sh # List resources attached devices and returned to terraform
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── setup_volume.sh # Basic volume management to avoid re-ordering of disks after reboots
│   │   └── variables.tf
│   ├── network
│   │   └── main.tf
│   ├── routes
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── security
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   ├── specification
│   │   ├── files.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf # terraform.tfvars.json variable passed to spec module to validate the data's structure
│   ├── validation
│   │   ├── main.tf
│   │   └── providers.tf
│   ├── vpc
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── vpc_peering
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── vpc_peering_accepter
│   │   └── main.tf
│   └── vpc_peering_routes
│       └── main.tf
├── providers.tf.json # Configuration blocks for `provider` and `terraform`
├── versions.tf # Provider Versioning file
├── templates # user templates rendered in parent directory with extension `.tftpl` removed
│   ├── config.yml.tftpl
│   └── inventory.yml.tftpl
├── terraform.tfstate # Terraform state - used as a terraform project marker for edb-terraform when state is remote
├── terraform.tfvars.json # Automatically detected Terraform variables. Original values under `edb-terraform/terraform.tfvars.yml`
└── common_vars.tf # Terraform placeholder variables used by all providers
```
