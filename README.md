# edb-terraform

Terraform templates aimed to provide easy to use YAML configuration file
describing the target cloud infrastructure.

## Supported Cloud providers

| Provider | Component                | Supported        |
|----------|--------------------------|------------------|
| EDB      | BigAnimal - AWS          |:white_check_mark:|
| AWS      | EC2 - VM                 |:white_check_mark:|
| AWS      | EC2 - additional EBS vol.|:white_check_mark:|
| AWS      | multi-region VPC peering |:white_check_mark:|
| AWS      | Security (ports)         |:white_check_mark:|
| AWS      | RDS                      |:white_check_mark:|
| AWS      | RDS Aurora               |:white_check_mark:|
| AWS      | Elastic Kubernetes Service |:white_check_mark:|
| GCloud   | Compute Engine - VM      |:white_check_mark:|
| GCloud   | CloudSQL                 |:white_check_mark:|
| GCloud   | AlloyDB                  |:white_check_mark:|
| GCloud   | Google Kubernetes Engine |:white_check_mark:|
| EDB      | BigAnimal - Azure        |:white_check_mark:|
| Azure    | VM                       |:white_check_mark:|
| Azure    | Database - Flexible      |:white_check_mark:|
| Azure    | CosmoDB                  |       :x:        |
| Azure    | Azure Kubernetes Service |:white_check_mark:|

## Prerequisites and installation

The following components must be installed on the system:
- Python3 >= 3.6
- AWS CLI
- GCloud CLI
- Azure CLI
- BigAnimal token (CLI currently optional)
- Terraform >= 1.3.6

## Infrastructure file examples

Infrastructure files describing the target cloud
can be found inside of the [infrastructure-examples directory](./infrastructure-examples/README.md)


### Prequisites installation on Debian 11

#### Python3/pip3

```console
$ sudo apt install python3 python3-pip -y
$ sudo pip3 install pip --upgrade
```

#### BigAnimal Token by API
[Getting an API token](https://www.enterprisedb.com/docs/biganimal/latest/using_cluster/terraform_provider/#getting-an-api-token)

- `access_token` - expires in 24 hours
- `refresh_token`
  - expires
    - 30 days
    - when refreshed
    - expired refresh_tokens reused
  - changes after every refresh with a new access_token
```console
wget https://raw.githubusercontent.com/EnterpriseDB/cloud-utilities/main/api/get-token.sh
bash get-token.sh
# Visit the biganimal link to activate the device
# ex. Please login to https://auth.biganimal.com/activate?user_code=JWPL-RCXL with your BigAnimal account
#     Have you finished the login successfully. (y/n)
# Save the refresh token, if needed
export BA_BEARER_TOKEN=<access_token>
```

Refresh the token
```console
bash get-token.sh --refresh <refresh_token>
# Save the new refresh token, if needed again
export BA_BEARER_TOKEN=<access_token>
```

#### BigAnimal CLI
[Using the BigAnimal CLI](https://www.enterprisedb.com/docs/biganimal/latest/reference/cli/)

The CLI currently requires users to visit a link during when using `biganimal reset-credential` .
The token directly from the API is preferred to avoid needing to revisit the link. 

#### AWS CLI

```console
$ sudo pip3 install awscli
```

AWS Access Key and Secret Access Key configuration:
```console
$ aws configure
```

#### GCloud CLI
[Install CLI](https://cloud.google.com/sdk/docs/install)

Initialize GCloud and export project id
```console
$ gcloud init
$ export GOOGLE_PROJECT=<project_id>
```

#### Terraform

```console
$ sudo apt install unzip -y
$ wget https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip
$ unzip terraform_1.3.6_linux_amd64.zip
$ sudo install terraform /usr/bin
```

### edb-terraform installation

```console
$ git clone https://github.com/EnterpriseDB/edb-terraform.git
```
[![asciicast](https://asciinema.org/a/593420.svg)](https://asciinema.org/a/593420)

```console
$ python3 -m pip install edb-terraform/. --upgrade
```
[![asciicast](https://asciinema.org/a/593421.svg)](https://asciinema.org/a/593421)
## Cloud Resources Creation

Once the infrastructure file has been created we can to proceed with cloud
resources creation:

  1. We can attempt to setup a compatable version of Terraform.
     This directory will be inside of `~/.edb-terraform/bin`
     Logs can be found inside of `~/.edb-terraform/logs`
    
     ```shell
     $ edb-terraform setup
     ```

  2. A new Terraform *project* must be created with the help of the
     `edb-terraform` script. This script is in charge of creating a dedicated
     directory for the *project*, generating SSH keys, building Terraform
     configuration based on the infrastructure file, copying Terraform modules
     into the *project* directory.

      a. First argument is the *project* path, second argument is the
     path to the infrastructure file
     
     Use option `-c` to specify the cloud provider option: `azure` `aws` `gcloud`
     
     Defaults to `aws` if not used
     ```shell
     $ edb-terraform generate --project-name aws-terraform \
                              --cloud-service-provider aws \
                              --infra-file edb-terraform/infrastructure-examples/aws/edb-ra-3.yml \
                              --user-templates edb-terraform/infrastructure-examples/templates/inventory.yml.tftpl
     ```

      b. Step 2 can be skipped if option `--validate` is included with `generate`,
     which provides basic validations and checks through terraform.

     ```

[![asciicast](https://asciinema.org/a/593423.svg)](https://asciinema.org/a/593423)

  2. Terraform initialisation of the *project*:
     ```shell
     $ cd aws-terraform
     $ terraform init
     ```

  3. Apply Cloud resources creation:
     ```shell
     $ cd aws-terraform
     $ terraform apply -auto-approve
     ```

[![asciicast](https://asciinema.org/a/593425.svg)](https://asciinema.org/a/593425)

## SSH access to the machines

Once cloud resources provisioning is completed, machines public and private IPs
are stored in the `servers.yml` file, located into the project's directory.
These outputs can be used with a list of templates to generate files for other programs such as ansible.
See example here which uses the below outputs. 

Example:

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

You can also use `terraform output` to get a json object for use
```bash
terraform output -json servers | python3 -m json.tool
```

SSH key files: `ssh-id_rsa` and `ssh-id_rsa.pub`.

## Customizations
Users can further modify their resources after the initial provisioning.
If any output files are needed based on the resources,
terraform templates can be added to the projects `template` directory to have it rendered with any resource outputs once all resources are created.
Examples of template files can be found here:
[edb-ansible included inventory.yml](./edbterraform/data/templates/user/inventory.yml.tftpl)
[sample inventory.yml](./infrastructure-examples/templates/inventory.yml.tftpl)

[![asciicast](https://asciinema.org/a/2SbGuMyEB2cpJK1QHeac8u5EY.svg)](https://asciinema.org/a/2SbGuMyEB2cpJK1QHeac8u5EY)

## Cloud resources destruction

```shell
$ cd aws-terraform
$ terraform destroy -auto-approve
```

[![asciicast](https://asciinema.org/a/593427.svg)](https://asciinema.org/a/593427)
