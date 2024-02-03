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

#### OpenID Connect

When creating an application, such as a github action, OpenID connect might be preferred to avoid the use of long-term credentials.
This requires an AWS account with IAM permissions.

Setup has 3 main steps:
1. Create an IAM identity provider.
2. Create an IAM role with permissions/policies and tie it back to the IAM identity provider.
3. Note the role's arn and setup an environment for OIDC.

Console setup for Github Actions:
1. Inside of the AWS console, go to `IAM`, then `Identity Providers` and click on `Add provider`.
![image](https://github.com/EnterpriseDB/edb-terraform/assets/31219516/c06c06c4-3039-4657-8aa0-5ee1ae9f077f)
2. Add the Github Identity Provider's url and audience
![image](https://github.com/EnterpriseDB/edb-terraform/assets/31219516/b349ab67-f937-4072-972d-ddb4f5a435a7)
3. Go to `IAM`, then `Roles` and click on `Create Role`
![image](https://github.com/EnterpriseDB/edb-terraform/assets/31219516/de8a9f9f-e7a0-4457-a741-fd963344975a)

4. Select `Web Identity` and setup the identity provider, audience, and restrict the role by Organization, Repo or Branch.
   Step 2 will ask for permissions and permission boundaries, which are skipped here. Make sure to restrict permissions instead of using `AdministratorAccess` which grants all permissions. Fill out step 3, create the role and make note of the role name and role arn.
![image](https://github.com/EnterpriseDB/edb-terraform/assets/31219516/4ef9e7f1-ad3d-4763-817e-28c8d7fc3472)
- The `trust policy` cannot be edited when `Web Identity` is selected but you can take the json and use it as a base with `Custom Trust Policy`. In this case, we will only check if the credentials are valid with `aws sts get-caller-identity` from any EnterpriseDB repo or branch.
```yaml
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Principal": {
                "Federated": "arn:aws:iam::<ARN_ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": [
                        "sts.amazonaws.com"
                    ]
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:EnterpriseDB/*"
                    ]
                }
            }
        }
    ]
}
```
5. Go back to the identity provider and assign the role you created.
![image](https://github.com/EnterpriseDB/edb-terraform/assets/31219516/5efc4b16-831e-47e7-90ff-00914834e620)
6. OIDC can now be used within a github workflow. This requires some permissions for the token to read/write and the role's arn.
```yaml
name: Infrastructure
on:
  workflow_dispatch:
permissions:
  id-token: write
  contents: read
jobs:
  credentials:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ROLE_ARN>:role/<ROLE_NAME>
          role-session-name: github-actions
          aws-region: us-east-1
      - name: Check if AWS credentials are valid
        shell: bash
        run: aws sts get-caller-identity
```
7. Go back to your role to open or restrict credential permissions and adjust workflow permissions as needed.

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
