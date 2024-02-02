#### [Provider and Credential Setup](./CREDENTIALS.md)

#### Terraform

```console
$ sudo apt install unzip -y
$ wget https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip
$ unzip terraform_1.3.6_linux_amd64.zip
$ sudo install terraform /usr/bin
```

#### Python3/pip3

```console
$ sudo apt install python3 python3-pip -y
$ sudo pip3 install pip --upgrade
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
