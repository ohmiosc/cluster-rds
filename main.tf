provider "aws" {
  region = var.provider_region
}

locals {
  port                 = var.port == "" ? var.engine == "aurora-postgresql" ? "5432" : "3306" : var.port
  master_password      = var.password == "" ? random_password.master_password.result : var.password
  //db_subnet_group_name = var.db_subnet_group_name == "" ? join("", aws_db_subnet_group.this.*.name) : var.db_subnet_group_name
  backtrack_window     = (var.engine == "aurora-mysql" || var.engine == "aurora") && var.engine_mode != "serverless" ? var.backtrack_window : 0

  rds_enhanced_monitoring_arn  = join("", aws_iam_role.rds_enhanced_monitoring.*.arn)
  rds_enhanced_monitoring_name = join("", aws_iam_role.rds_enhanced_monitoring.*.name)

  allowed_cidr_blocks              = ["0.0.0.0/0"]

  name = "aurora-${var.name}"

  default_tags = {
    Owner = var.owner
    Environment = var.env
    Product = var.owner
  }
  
}

# Random string to use as master password unless one is specified
resource "random_password" "master_password" {
  length  = 10
  special = false
}

######################################
# Data sources to get VPC and subnets
######################################
data "aws_vpc" "default" {
  id = var.vpc_id
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

######################################
# Sources roles, monitoring, policity, etc
######################################

data "aws_iam_policy_document" "monitoring_rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name               = "rds-enhanced-monitoring-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.monitoring_rds_assume_role.json

  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = local.rds_enhanced_monitoring_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

####################
# RDS Aurora Module
####################
module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 2.0"  
  name                            = format("%s-%s-aurora-mysql", var.owner, var.env)
  engine                          = var.engine
  engine_version                  = var.engine_version
  subnets                         = data.aws_subnet_ids.all.ids
  vpc_id                          = data.aws_vpc.default.id
  replica_count                   = 1
  apply_immediately               = true
  skip_final_snapshot             = true
  db_parameter_group_name         = aws_db_parameter_group.aurora_db_mysql_parameter_group.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cluster_mysql_parameter_group.id
  //  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  security_group_description      = ""

  instance_type                   = var.instance_type
  username                        = var.username
  password                        = local.master_password
  port                            = local.port

  tags = {
    Owner       = var.owner
    Environment = var.env
  }

}

resource "aws_db_parameter_group" "aurora_db_mysql_parameter_group" {
  name        = format("%s-%s-aurora-db-mysql-parameter-group", var.owner, var.env)
  family      = "aurora-mysql5.7"
  description = format("%s-%s-aurora-db-mysql-parameter-group", var.owner, var.env)
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_mysql_parameter_group" {
  name        = format("%s-%s-aurora-mysql-cluster-parameter-group", var.owner, var.env)
  family      = "aurora-mysql5.7"
  description = format("%s-%s-aurora-mysql-cluster-parameter-group", var.owner, var.env)
}

############################
# Example of security group
############################
resource "aws_security_group" "app_servers" {
  name_prefix = "app-servers-"
  description = "For application servers"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "allow_access" {
  type                     = "ingress"
  from_port                = module.aurora.this_rds_cluster_port
  to_port                  = module.aurora.this_rds_cluster_port
  protocol                 = "tcp"
  #source_security_group_id = aws_security_group.app_servers.id
  cidr_blocks              = local.allowed_cidr_blocks
  security_group_id        = module.aurora.this_security_group_id
}


resource "aws_security_group_rule" "egress" {
  type                     = "egress"
  from_port                = module.aurora.this_rds_cluster_port
  to_port                  = module.aurora.this_rds_cluster_port
  protocol                 = "tcp"
  #source_security_group_id = aws_security_group.app_servers.id
  cidr_blocks              = local.allowed_cidr_blocks
  security_group_id        = module.aurora.this_security_group_id
}