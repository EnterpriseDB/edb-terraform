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
| GCloud   | -                        |       :x:        |
| Azure    | -                        |       :x:        |

## Infrastructure file

Following are examples of infrastructure files describing the target cloud
infrastructure on AWS.

### AWS EC2 machines

```yaml
cluster_name: ec2-machines-demo
aws:
  ssh_user: rocky
  operating_system:
    name: Rocky-8-ec2-8.6-20220515.0.x86_64
    owner: 679593333241
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      azs:
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
      az: us-east-1b
      instance_type: c5.18xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    dbt2-driver:
      type: dbt2-driver
      region: us-east-1
      az: us-east-1b
      instance_type: c5.18xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    pg1:
      type: postgres
      region: us-east-1
      az: us-east-1b
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
cluster_name: rds-database-demo
aws:
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      azs:
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
cluster_name: aurora-demo
aws:
  regions:
    us-east-1:
      cidr_block: 10.0.0.0/16
      azs:
        us-east-1a: 10.0.1.0/24
        us-east-1b: 10.0.2.0/24
      service_ports:
        - port: 5432
          protocol: tcp
          description: "PostgreSQL"
  aurora:
    mydb2:
      region: us-east-1
      azs:
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
cluster_name: BuildBot-Demo
aws:
  ssh_user: ubuntu
  operating_system:
    name: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-
    owner: 099720109477
  regions:
    us-east-2:
      cidr_block: 10.0.0.0/16
      azs:
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
      az: us-east-2b
      instance_type: c5.xlarge
      volume:
        type: gp2
        size_gb: 50
        iops: 5000
        encrypted: false
    ebac-worker-0:
      type: worker
      region: us-east-2
      az: us-east-2b
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
#### Options:
* `service_ports`: ports open to the public
* `region_ports`: ports open and restricted to region's subnet cidrblocks

## Prerequisites and installation

The following components must be installed on the system:
- Python3
- AWS CLI
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

#### Terraform

```console
$ sudo apt install unzip -y
$ wget https://releases.hashicorp.com/terraform/1.2.6/terraform_1.2.6_linux_amd64.zip
$ unzip terraform_1.2.6_linux_amd64.zip
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

     First argument is the *project* path, second argument is the
     path to the infrastructure file:
     ```shell
     $ edb-terraform ~/my_project my_infrastructure.yml
     ```

  2. Terraform initialisation of the *project*:
     ```shell
     $ cd ~/my_project
     $ terraform init
     ```

  3. Apply Cloud resources creation:
     ```shell
     $ cd ~/my_project
     $ terraform apply \
           -var-file=./terraform_vars.json \
           -auto-approve
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
    az: us-east-1b
    public_ip: 54.166.46.2
    private_ip: 10.0.0.103
    public_dns: ec2-54-166-46-2.compute-1.amazonaws.com
  pg1:
    type: postgres
    region: us-east-1
    az: us-east-1b
    public_ip: 3.80.202.134
    private_ip: 10.0.0.148
    public_dns: ec2-3-80-202-134.compute-1.amazonaws.com
[...]
```

SSH key files: `ssh-id_rsa` and `ssh-id_rsa.pub`.

## Cloud resources destruction

```shell
$ cd ~/my_project
$ terraform destroy \
    -var-file=./terraform_vars.json \
    -auto-approve
```
