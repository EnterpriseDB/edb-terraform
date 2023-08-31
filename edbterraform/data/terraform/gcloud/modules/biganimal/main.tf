resource "biganimal_cluster" "instance" {

    # required 
    cloud_provider = local.cloud_provider
    cluster_architecture {
        id = var.cluster_type
        nodes = var.node_count
    }
    cluster_name = local.cluster_name
    instance_type = local.instance_type
    password = var.password
    pg_type = var.engine
    pg_version = var.engine_version
    project_id = var.project.id
    region = var.region
    storage {
        volume_type = var.volume.type
        volume_properties = var.volume.properties
        size = local.volume_size
        # IOPs and Throughput not configurable for pd-ssd
    }

    # optional
    dynamic "allowed_ip_ranges" {
        for_each = { for key,values in var.allowed_ip_ranges: key=>values }
        content {
            cidr_block = allowed_ip_ranges.value.cidr_block
            description = allowed_ip_ranges.value.description
        }
    }
    backup_retention_period = "1d"
    csp_auth = false
    dynamic "pg_config" {
        for_each = { for key,values in var.settings: key=>values }
        content {
            name         = pg_config.value.name
            value        = pg_config.value.value
        }
    }
    # VPC Peering or other must be configured with CLI
    # when using a private network
    private_networking = !var.publicly_accessible
    read_only_connections = false
}
