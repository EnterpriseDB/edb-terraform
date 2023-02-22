output "security_group_ids" {
  value = flatten([
    for key, values in merge(aws_security_group.rules):
      values.id
  ])
}
