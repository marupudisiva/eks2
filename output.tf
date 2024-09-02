output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.kvi_vpc.id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = aws_subnet.kvi_subnet[*].id
}

output "eks_cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.kvi.id
}

output "eks_node_group_id" {
  description = "The ID of the EKS node group"
  value       = aws_eks_node_group.kvi.id
}
