locals {
{% if has_network %}
  region_az_networks = {
    for region, region_spec in var.regions: region => {
      for az, network in region_spec.azs: az => network
    }
  }
{% endif %}
{% if has_machine %}
  region_machines = {
    for name, machine_spec in var.machines: machine_spec.region => {
      name = name
      spec = machine_spec
    }...
  }
{% endif %}
{% if has_database %}
  region_databases = {
    for name, database_spec in var.databases: database_spec.region => {
      name = name
      spec = database_spec
    }...
  }
{% endif %}
{% if has_aurora %}
  region_auroras = {
    for name, aurora_spec in var.aurora: aurora_spec.region => {
      name = name
      spec = aurora_spec
    }...
  }
{% endif %}
}

{% for region in regions.keys() %}
{%   set region_ = region | replace('-', '_') %}

{%   if has_network %}
{%     include "network.tf" %}
{%   endif %}

{%   if has_machine %}
{%     include "key_pair.tf" %}

{%     include "machine.tf" %}
{%   endif %}

{%   if has_database %}
{%     include "database.tf" %}
{%   endif %}

{%   if has_aurora %}
{%     include "aurora.tf" %}
{%   endif %}

{% endfor %}

{% if has_region_peering %}
{%   include "region_peering.tf" %}
{% endif %}

resource "local_file" "servers_yml" {
  filename        = "${abspath(path.root)}/servers.yml"
  file_permission = "0600"
  content         = <<-EOT
---
servers:
{% if machine_regions | length > 0 %}
  machines:
{% endif %}
{% for region in machine_regions %}
{% set region_ = region | replace('-', '_') %}
%{for key in keys(module.machine_{{ region_ }}) ~}
    ${key}:
      type: ${module.machine_{{ region_ }}[key].machine_ips.type}
      region: ${module.machine_{{ region_ }}[key].machine_ips.region}
      az: ${module.machine_{{ region_ }}[key].machine_ips.az}
      public_ip: ${module.machine_{{ region_ }}[key].machine_ips.public_ip}
      private_ip: ${module.machine_{{ region_ }}[key].machine_ips.private_ip}
      public_dns: ${module.machine_{{ region_ }}[key].machine_ips.public_dns}
%{endfor~}
{% endfor %}
{% if database_regions | length > 0 %}
  databases:
{% endif %}
{% for region in database_regions %}
{% set region_ = region | replace('-', '_') %}
%{for key in keys(module.database_{{ region_ }}) ~}
    ${key}:
      region: ${module.database_{{ region_ }}[key].database_ips.region}
      username: "${module.database_{{ region_ }}[key].database_ips.username}"
      password: "${module.database_{{ region_ }}[key].database_ips.password}"
      address: ${module.database_{{ region_ }}[key].database_ips.address}
      port: ${module.database_{{ region_ }}[key].database_ips.port}
      dbname: "${module.database_{{ region_ }}[key].database_ips.dbname}"
%{endfor~}
{% endfor %}
{% if aurora_regions | length > 0 %}
  aurora:
{% endif %}
{% for region in aurora_regions %}
{% set region_ = region | replace('-', '_') %}
%{for key in keys(module.aurora_{{ region_ }}) ~}
    ${key}:
      region: ${module.aurora_{{ region_ }}[key].aurora_ips.region}
      username: "${module.aurora_{{ region_ }}[key].aurora_ips.username}"
      password: "${module.aurora_{{ region_ }}[key].aurora_ips.password}"
      address: ${module.aurora_{{ region_ }}[key].aurora_ips.address}
      port: ${module.aurora_{{ region_ }}[key].aurora_ips.port}
      dbname: "${module.aurora_{{ region_ }}[key].aurora_ips.dbname}"
%{endfor~}
{% endfor %}
    EOT
}
