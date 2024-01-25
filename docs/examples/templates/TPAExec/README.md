This is a minimal configuration which deploys a single driver node and 3 postgres node for use in a pgd cluster with TPAExec.
`config.yml` will contain the configuration for use with TPA as well as helper files since this is considered a bare-bones cluster.

```shell
edb-terraform generate \
    --infra-file single_instance.yml \
    --user-templates ../TPAExec \ # can accept a directory of templates
    --cloud-service-provider aws \
    --project-name TPAExec-Demo
```
