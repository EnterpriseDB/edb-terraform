# Dependabot does not support .tf.json
# https://github.com/dependabot/dependabot-core/issues/4080
# https://github.com/dependabot/dependabot-core/pull/5293

terraform {
  required_providers {

    biganimal = {
      source = "registry.terraform.io/EnterpriseDB/biganimal"
      version = "<= 0.7.1"
    }
    # https://github.com/EnterpriseDB/terraform-provider-toolbox/issues/44
    toolbox = {
      source = "registry.terraform.io/bryan-bar/toolbox"
      version = "<= 0.2.2"
    }

    aws = {
      source = "registry.terraform.io/hashicorp/aws"
      version = "<= 5.37.0"
    }

    azurerm = {
      source = "registry.terraform.io/hashicorp/azurerm"
      version = "<= 3.89.0"
    }

    google = {
      source = "registry.terraform.io/hashicorp/google"
      version = "<= 5.14.0"
    }

    kubernetes = {
      source = "registry.terraform.io/hashicorp/kubernetes"
      version = "<= 2.25.2"
    }

    null = {
      source = "registry.terraform.io/hashicorp/null"
      version = "<= 3.2.2"
    }

    time = {
      source = "registry.terraform.io/hashicorp/time"
      version = "<= 0.10.0"
    }

    local = {
      source = "registry.terraform.io/hashicorp/local"
      version = "<= 2.4.1"
    }

    random = {
      source = "registry.terraform.io/hashicorp/random"
      version = "<= 3.6.0"
    }

    tls = {
      source = "registry.terraform.io/hashicorp/tls"
      version = "<= 4.0.5"
    }

  }
}
