# edb-terraform

Terraform templates aimed to provide easy to use YAML configuration file
describing the target cloud infrastructure.

## Supported Cloud providers

| Provider | Component                | Supported        |
|----------|--------------------------|------------------|
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
- Terraform >= 1.3.6

## Infrastructure file examples

Infrastructure files describing the target cloud
can be found inside of the [infrastructure-examples directory](./infrastructure-examples/)


### Prequisites installation on Debian 11

#### Python3/pip3

```console
$ sudo apt install python3 python3-pip -y
$ sudo pip3 install pip --upgrade
```

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
$ pip3 install . --upgrade
```

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
     $ edb-terraform generate ~/my_project -c aws my_infrastructure.yml
     ```

      b. Step 2 can be skipped if using option `--validate`,
     which provides basic validations and checks through terraform.
     
     Requires:
      * terraform `>= 1.3.6` 
      * CLI from chosen provider setup already (authenticated, export needed variables/files)
     ```shell
     $ edb-terraform generate ~/my_project -c aws my_infrastructure.yml --validate
     ```

<p align="center">
  <img width="100%" src="./images/generate.svg">
</p>

  2. Terraform initialisation of the *project*:
     ```shell
     $ cd ~/my_project
     $ terraform init
     ```

  3. Apply Cloud resources creation:
     ```shell
     $ cd ~/my_project
     $ terraform apply -auto-approve
     ```

<p align="center">
  <img width="100%" src="./images/apply.svg">
</p>


## SSH access to the machines

Once cloud resources provisioning is completed, machines public and private IPs
are stored in the `servers.yml` file, located into the project's directory.

Example:

```yaml
---
servers:
  barman1:
    type: barman
    region: us-east-1
    zone: us-east-1b
    public_ip: 54.166.46.2
    private_ip: 10.0.0.103
    # Default provided DNS only supported by AWS
    public_dns: ec2-54-166-46-2.compute-1.amazonaws.com
  pg1:
    type: postgres
    region: us-east-1
    zone: us-east-1b
    public_ip: 3.80.202.134
    private_ip: 10.0.0.148
    public_dns: ec2-3-80-202-134.compute-1.amazonaws.com
[...]
```

You can also use `terraform output` to get a json object for use
```bash
terraform output -json servers | python3 -m json.tool
```

SSH key files: `ssh-id_rsa` and `ssh-id_rsa.pub`.

<p align="center">
  <img width="100%" src="./images/ssh.svg">
</p>

## Cloud resources destruction

```shell
$ cd ~/my_project
$ terraform destroy -auto-approve
```

<p align="center">
  <img width="100%" src="./images/destroy.svg">
</p>
