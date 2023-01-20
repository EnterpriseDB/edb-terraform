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
| GCloud   | Compute Engine - VM      |:white_check_mark:|
| GCloud   | CloudSQL                 |:white_check_mark:|
| GCloud   | AlloyDB                  |:white_check_mark:|
| GCloud   | Google Kubernetes Engine |:white_check_mark:|
| Azure    | VM                       |:white_check_mark:|
| Azure    | Database - Flexible      |       :x:        |
| Azure    | CosmosDB                 |       :x:        |

## Infrastructure file

Following are examples of infrastructure files describing the target cloud
infrastructure. Example yaml files found inside [infrastructure-examples directory](./infrastructure-examples/)

### AWS EC2 machines

```yaml
aws:
  tags:
    cluster_name: ec2-machines-demo
    created_by: terraform
  ssh_user: rocky
  operating_system:
    name: Rocky-8-ec2-8.6-20220515.0.x86_64
    owner: 679593333241
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      zones:
        us-east-1b: 10.0.0.0/24
        us-east-1c: 10.0.1.0/24
      service_ports:
        - port: 22
          protocol: tcp
          description: "SSH"
        - port: 30000
          protocol: tcp
          description: "DBT-2"
        - port: 30000
          protocol: udp
          description: "DBT-2"
        - port: 5432
          protocol: tcp
          description: "PostgreSQL"
  machines:
    dbt2-client:
      type: dbt2-client
      region: us-east-1
      zone: us-east-1b
      instance_type: c5.18xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    dbt2-driver:
      type: dbt2-driver
      region: us-east-1
      zone: us-east-1b
      instance_type: c5.18xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    pg1:
      type: postgres
      region: us-east-1
      zone: us-east-1b
      instance_type: c5.4xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
      additional_volumes:
        - mount_point: /opt/pg_data
          size_gb: 200
          type: io2
          iops: 50000
          encrypted: false
        - mount_point: /opt/pg_wal
          size_gb: 200
          type: io2
          iops: 50000
          encrypted: false
```

### AWS RDS Database

```yaml
aws:
  tags:
    cluster_name: rds-database-demo
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      zones:
        us-east-1a: 10.0.0.0/24
      service_ports:
        - port: 5432
          protocol: tcp
          description: "PostgreSQL"
  databases:
    mydb1:
      region: us-east-1
      engine: postgres
      engine_version: 13
      instance_type: db.t3.micro
      dbname: "dbt2"
      username: "postgres"
      password: "12Password!"
      port: 5432
      volume:
        size_gb: 100
        type: io1
        iops: 1000
        encrypted: true
      settings:
        - name: checkpoint_timeout
          value: 900
        - name: max_connections
          value: 300
        - name: max_wal_size
          value: 5000
        - name: random_page_cost
          value: 1.25
        - name: work_mem
          value: 16000
```

### AWS Aurora Database

```yaml
aws:
  tags:
    cluster_name: aurora-demo
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      zones:
        us-east-1a: 10.0.1.0/24
        us-east-1b: 10.0.2.0/24
      service_ports:
        - port: 5432
          protocol: tcp
          description: "PostgreSQL"
  aurora:
    mydb2:
      region: us-east-1
      zones:
        - us-east-1a
        - us-east-1b
      count: 1
      engine: aurora-postgresql
      engine_version: 13
      dbname: "test"
      username: "postgres"
      password: "12Password!"
      port: 5432
      instance_type: db.t3.medium
      settings:
        - name: max_connections
          value: 300
        - name: random_page_cost
          value: 1.25
        - name: work_mem
          value: 16000
```

### AWS Buildbot Master and Worker

```yaml
aws:
  tags:
    cluster_name: BuildBot-Demo
  ssh_user: ubuntu
  operating_system:
    name: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-
    owner: 099720109477
  regions:
    us-east-2:
      cidr_block: 10.0.0.0/16
      zones:
        us-east-2b: 10.0.0.0/24
      service_ports:
        - port: 22
          protocol: tcp
          description: "SSH"
      region_ports:
        - port: 9989
          protocol: tcp
          description: "worker connection to master"
        - port: 8010
          protocol: tcp
          description: "master web UI"
  machines:
    ebac-master:
      count: 1
      type: master
      region: us-east-2
      zone: us-east-2b
      instance_type: c5.xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    ebac-worker-0:
      type: worker
      region: us-east-2
      zone: us-east-2b
      instance_type: c5.xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
      additional_volumes:
        - mount_point: /var/lib/buildbot-worker
          size_gb: 300
          type: io2
          iops: 5000
          encrypted: false
```

### GCloud Compute Engine VMs

```yaml
gcloud:
  tags:
    cluster_name: gcloud-infra
  ssh_user: rocky
  operating_system:
    name: rocky-linux-8
  regions:
    us-west2:
      cidr_block: 10.2.0.0/16
      zones:
        us-west2-b: 10.2.20.0/24
      service_ports:
        - port: 22
          protocol: tcp
          description: "SSH"
    us-west1:
      cidr_block: 10.1.0.0/16
      zones:
        us-west1-b: 10.1.20.0/24
        us-west1-c: 10.1.30.0/24
      service_ports:
        - port: 22
          protocol: tcp
          description: "SSH"
      region_ports:
        - protocol: icmp
          description: "ping"
  machines:
    dbt2-driver:
      type: dbt2-driver
      region: us-west2
      zone: us-west2-b
      instance_type: c2-standard-4
      volume:
        type: pd-standard
        size_gb: 50
    pg1:
      type: postgres
      region: us-west1
      zone: us-west1-c
      instance_type: e2-standard-4
      service_ip: true
      volume:
        type: pd-standard
        size_gb: 50
      additional_volumes:
        - mount_point: /opt/pg_data
          type: pd-ssd
          size_gb: 50
          iops: null
        - mount_point: /opt/pg_wal
          type: pd-ssd
          size_gb: 50
          iops: null
```

#### Options:
* `service_ports`: ports open to the public
* `region_ports`: ports open and restricted to region's and cross-region's subnet cidrblocks

## Prerequisites and installation

The following components must be installed on the system:
- Python3
- AWS CLI
- GCloud CLI
- Azure CLI
- Terraform

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

  1. A new Terraform *project* must be created with the help of the
     `edb-terraform` script. This script is in charge of creating a dedicated
     directory for the *project*, generating SSH keys, building Terraform
     configuration based on the infrastructure file, copying Terraform modules
     into the *project* directory.

      a. First argument is the *project* path, second argument is the
     path to the infrastructure file
     
     Use option `-c` to specify the cloud provider option: `azure` `aws` `gcloud`
     
     Defaults to `aws` if not used
     ```shell
     $ edb-terraform ~/my_project -c aws my_infrastructure.yml
     ```

      b. Step 2 can be skipped if using option `--validate`,
     which provides basic validations and checks through terraform.
     
     Requires:
      * terraform `>= 1.3.6` 
      * CLI from chosen provider setup already (authenticated, export needed variables/files)
     ```shell
     $ edb-terraform ~/my_project -c aws my_infrastructure.yml --validate
     ```

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

SSH key files: `ssh-id_rsa` and `ssh-id_rsa.pub`.

## Cloud resources destruction

```shell
$ cd ~/my_project
$ terraform destroy -auto-approve
```
