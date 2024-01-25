This minimal configuration shows how to template the infrastructure file for dynamic configurations, such as the ssh access list.

```shell
edb-terraform generate \
    --infra-file ssh.yml.j2 \
    --infra-template-variables '{"ssh_ips":["1.2.3.4/5"]}' \
    --cloud-service-provider aws \
    --project-name SSH-Access-Demo
```
