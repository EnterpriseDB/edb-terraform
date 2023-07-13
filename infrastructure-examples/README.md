# Infrastructure Examples

Provided are examples are all 3 major cloud providers.
Each filename should reference the service it is an example for.

** machines and kubernetes are the exception
- [AWS](./aws/)
- [Azure](./azure/)
- [GCloud](./gcloud/)

Templates can be used to create files after all resources are created.
It will have the the outputs from servers.yml available for use.
Templates can be passed in with `edb-terraform generate` and option `--user-templates`.
- [Example template](./templates/inventory.yml.tftpl)
