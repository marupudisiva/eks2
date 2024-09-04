module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  manage_aws_auth_configmap = false

  cluster_name    = var.cluster_name
  cluster_version = "1.30"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
 

  node_groups = {
    eks_nodes = {
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity

      instance_type = var.instance_type
      key_name      = var.key_name

      additional_security_group_ids = [aws_security_group.eks_node_sg.id]
      iam_role_arn                  = module.node_role.iam_role_arn
    }
  }

  cluster_security_group_id = aws_security_group.eks_cluster_sg.id
  tags                      = var.tags
}