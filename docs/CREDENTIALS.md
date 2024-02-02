# Providers
- [AWS](#aws)
- [Azure](#azure)
- [BigAnimal](#biganimal)
- [GCloud](#gcloud)

> :warning: Protect your credentials!  
> :information_source: Refer to offical provider documentation for the latest credential management recommendations and options.  

## AWS
#### CLI Installation
```console
$ sudo pip3 install awscli
```

#### CLI Credentials
AWS Access Key and Secret Access Key configuration:
```console
$ aws configure
```

#### OpenID Connect (OIDC)

When creating an application, such as a github action, OpenID connect might be preferred to avoid setting of credentials.
This requires an AWS account with IAM permissions.

There are 3 steps to set this up:
1. Create an IAM identity provider and setup policies
2. Create an IAM role and tie to the IAM identity provider
3. Note the role's arn and setup environment for OIDC

- [aws docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html#idp_oidc_Create_GitHub)
- [github actions docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws actions docs](https://github.com/aws-actions/configure-aws-credentials?tab=readme-ov-file#OIDC)

## Azure
#### OpenID Connect (OIDC)

- [github-actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)

## BigAnimal
### API Token
[Getting an API token](https://www.enterprisedb.com/docs/biganimal/latest/using_cluster/terraform_provider/#getting-an-api-token)

- `access_token` - expires in 24 hours
- `refresh_token`
  - expires
    - 30 days
    - when refreshed
    - expired refresh_tokens reused
  - changes after every refresh with a new access_token

#### Script
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

#### CLI
[Using the BigAnimal CLI](https://www.enterprisedb.com/docs/biganimal/latest/reference/cli/)

The CLI currently requires users to visit a link during when using `biganimal reset-credential`.
The token directly from the API is preferred to avoid needing to revisit the link.

## GCloud
#### OpenID Connect (OIDC)

- [github-actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform)

#### GCloud CLI
[Install CLI](https://cloud.google.com/sdk/docs/install)

Initialize GCloud and export project id
```console
$ gcloud init
$ export GOOGLE_PROJECT=<project_id>
```
