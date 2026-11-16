data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "jenkins" {
  name        = "${var.name}-sg"
  description = "No inbound access; administer Jenkins using AWS Systems Manager."
  vpc_id      = var.vpc_id

  egress {
    description = "Package repositories and AWS APIs through the private subnet NAT."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.name}-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "${var.name}-ssm" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name}-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  count                       = var.provision_instance ? 1 : 0
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/install-jenkins.sh", {
    cloudwatch_log_group = "/jenkins/${var.name}"
  })
  user_data_replace_on_change = true

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.volume_size_gib
    delete_on_termination = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true
  tags       = { Name = var.name }

  depends_on = [
    aws_cloudwatch_log_group.jenkins,
    aws_iam_role_policy_attachment.cloudwatch_agent
  ]
}

resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/jenkins/${var.name}"
  retention_in_days = 30
  tags              = { Name = "/jenkins/${var.name}" }
}
