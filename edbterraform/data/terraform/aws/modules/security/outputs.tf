output "security_group_ids" {
  value = flatten([aws_security_group.OUTBOUND_ACCESS.id ,[
    for key, values in aws_security_group.rules:
      values.id
  ]])
}
