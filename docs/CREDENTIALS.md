# Providers
- [AWS](#aws)
- [Azure](#azure)
- [BigAnimal](#biganimal)
- [GCloud](#gcloud)

> :warning: Protect your credentials!  
> :information_source: Refer to offical provider documentation for the latest credential management recommendations and options.  

## AWS
#### CLI Installation
PIPY's v2 release is `NOT` maintained by AWS
Instead, install it directly from git or through your package manager.
If v1 is installled it will have the same executable name as v2.
```console
$ sudo pip3 install https://github.com/aws/aws-cli/archive/refs/heads/v2.zip
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

#### Script
```bash
#!/bin/bash
# Modify as needed as the script assumes
# - the current user has the necessary permissions to create the role.
# - Minimal role permissions to test the connection with github actions.
# Creates:
# - The OIDC provider
# - A role for use with Github Actions
# https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/
set -eou pipefail

FORCE_RECREATE_ROLE=false
ROLE_NAME="EXAMPLE_ACTION_ROLE"
ORGANIZATION="EnterpriseDB"
REPO="SET_TO_REPO_NAME"

IDP_URL="token.actions.githubusercontent.com"
OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
AUDIENCE="sts.amazonaws.com"
POLICY_FILE="assume-role-policy-document.json"

# Get current accounts ARN ID
echo "Getting ARN ID from current user"
ARN_ID=$(aws sts get-caller-identity | jq -r '.Account')
echo "ARN ID: ${ARN_ID}"

PROVIDER_ARN="arn:aws:iam::${ARN_ID}:oidc-provider/${IDP_URL}"

# Create the OIDC provider
echo "Checking if OIDC provider exists: ${IDP_URL}"
if aws iam list-open-id-connect-providers | grep -q "${PROVIDER_ARN}"
then
  echo "OIDC provider already exists"
else
  echo "OIDC provider does not exist"
  echo "Creating OIDC provider: ${IDP_URL}"
  aws iam create-open-id-connect-provider --url "https://${IDP_URL}" \
                                          --thumbprint-list "${OIDC_THUMBPRINT}" \
                                          --client-id-list "${AUDIENCE}"
fi

# Create permissions for the role
# Creating roles doc: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp.html#roles-creatingrole-identityprovider-cli
echo "Creating permissions for the role - filename: ${POLICY_FILE}"
cat << EOF > "${POLICY_FILE}"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "arn:aws:iam::${ARN_ID}:oidc-provider/${IDP_URL}"
      },
      "Condition": {
        "StringEquals": {
          "${IDP_URL}:aud": [
            "${AUDIENCE}"
          ]
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:${ORGANIZATION}/${REPO}"
          ]
        }
      }
    }
  ]
}
EOF

# Create the role
echo "Creating role: ${ROLE_NAME}"
# Check if the role exists, delete it and recreate it
if [ "${FORCE_RECREATE_ROLE}" = "true" ] || [ "${FORCE_RECREATE_ROLE}" = "1" ] && \
    aws iam get-role --role-name "${ROLE_NAME}" > /dev/null 2>&1
then
    echo "Role already exists, deleting role: ${ROLE_NAME}"
    ROLE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name "${ROLE_NAME}")
    ROLE_INLINE_POLICIES=$(aws iam list-role-policies --role-name "${ROLE_NAME}")
    ROLE_ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "${ROLE_NAME}")

    for profile in $(echo $ROLE_PROFILES | jq -r '.InstanceProfiles[].InstanceProfileName')
    do
        echo "Deleting instance profile: ${profile}"
        aws iam remove-role-from-instance-profile --role-name "${ROLE_NAME}" --instance-profile-name "${profile}"
    done

    for policy in $(echo $ROLE_INLINE_POLICIES | jq -r '.PolicyNames[]')
    do
        echo "Deleting role policy: ${policy}"
        aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "${policy}"
    done

    for policy in $(echo $ROLE_ATTACHED_POLICIES | jq -r '.AttachedPolicies[].PolicyArn')
    do
        echo "Detaching role policy: ${policy}"
        aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${policy}"
    done

    aws iam delete-role --role-name "${ROLE_NAME}"
fi
ROLE=$(aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document "file://${POLICY_FILE}")
ROLE_ARN=$(echo $ROLE | jq -r '.Role.Arn')

echo "role-to-assume: ${ROLE_ARN}"
```

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
