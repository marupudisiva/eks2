provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "kvi_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "kvi-vpc"
  }
}

resource "aws_subnet" "kvi_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.kvi_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.kvi_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)

  tags = {
    Name = "kvi-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "kvi_igw" {
  vpc_id = aws_vpc.kvi_vpc.id

  tags = {
    Name = "kvi-igw"
  }
}

resource "aws_route_table" "kvi_route_table" {
  vpc_id = aws_vpc.kvi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kvi_igw.id
  }

  tags = {
    Name = "kvi-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.kvi_subnet[count.index].id
  route_table_id = aws_route_table.kvi_route_table.id
}

resource "aws_security_group" "kvi_cluster_sg" {
  vpc_id = aws_vpc.kvi_vpc.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "kvi-cluster-sg"
  }
}

resource "aws_security_group" "kvi_node_sg" {
  vpc_id = aws_vpc.kvi_vpc.id
  
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }  
  
  tags = {
    Name = "kvi-node-sg"
  }
}

resource "aws_eks_cluster" "kvi" {
  name     = "kvi-cluster"
  role_arn = aws_iam_role.kvi_cluster_role.arn
  
  vpc_config {
    subnet_ids         = aws_subnet.kvi_subnet[*].id
    security_group_ids = [aws_security_group.kvi_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.kvi_cluster_role_policy]
}

resource "aws_eks_node_group" "kvi" {
  cluster_name    = aws_eks_cluster.kvi.name
  node_group_name = "kvi-node-group"
  node_role_arn   = aws_iam_role.kvi_node_group_role.arn
  subnet_ids      = aws_subnet.kvi_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.micro"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.kvi_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.kvi_node_group_role_policy_attachment,
    aws_iam_role_policy_attachment.kvi_node_group_cni_policy,
    aws_iam_role_policy_attachment.kvi_node_group_registry_policy
  ]
}

resource "aws_iam_role" "kvi_cluster_role" {
  name = "kvi_cluster_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kvi_cluster_role_policy" {
  role       = aws_iam_role.kvi_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "kvi_node_group_role" {
  name = "kvi_node_group_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kvi_node_group_role_policy_attachment" {
  role       = aws_iam_role.kvi_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "kvi_node_group_cni_policy" {
  role       = aws_iam_role.kvi_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "kvi_node_group_registry_policy" {
  role       = aws_iam_role.kvi_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
