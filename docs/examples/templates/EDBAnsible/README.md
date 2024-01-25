This is a minimal configuration which deploys a single driver node and a postgres node for use with edb-ansible.
`inventory.yml` defines the hosts for use within ansible.

```shell
edb-terraform generate \
    --infra-file single_instance.yml \
    --user-templates inventory.yml.tftpl \
    --cloud-service-provider aws \
    --project-name EDBAnsible-Demo
```
