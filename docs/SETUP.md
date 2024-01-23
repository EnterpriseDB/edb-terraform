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
