# :seedling: edb-terraform

A tool for generating Terraform projects using pre-defined templates and modules. It simplifies the creation of target cloud resources for automation by leveraging an easy-to-use YAML configuration. This tool supports setting of IPs, image configurations, and the creation of simple clusters which can be divided into subnets. It also provides basic cross-region support.

> :information_source:  
> Supported [providers and components](./docs/SUPPORTED.md)

## :nut_and_bolt: Prerequisites

The following components must be installed on the system:
- [Terraform >= 1.3.6, <= 1.5.5](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform)
- Python >= 3.6
- Bash
- [JQ](https://jqlang.github.io/jq/download/)
- Cloud provider cli tool with credentials set
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [GCloud CLI](https://cloud.google.com/sdk/docs/install-sdk)
  - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
  - [BigAnimal CLI](https://www.enterprisedb.com/docs/biganimal/latest/reference/cli/) currently optional since the terraform provider relies on the environment variable `BA_BEARER_TOKEN` and it requires manual authentication.
    - For automation, [get-token.sh script](https://raw.githubusercontent.com/EnterpriseDB/cloud-utilities/main/api/get-token.sh) requires manual intervention every:
      - 30 days
      - Expired token is reused

> :information_source:  
> Refer to official documentation for credential management and environment specific installation.  
> For quick examples of setup, please refer to the [setup guide](./docs/SETUP.md).

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
terraform apply
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
└── variables.tf # Terraform placeholder variables
```
