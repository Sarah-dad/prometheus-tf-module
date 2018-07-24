# Create an EC2 instance:
resource "aws_instance" "prometheus" {
  count                  = "1"
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_flavor}"
  vpc_security_group_ids = ["${aws_security_group.prometheus.id}", "${data.aws_security_group.monitoring_sec_group.id}"]
  subnet_id              = "${var.private_subnets[0]}"
  key_name               = "${var.key_pair_name}"
  iam_instance_profile   = "${aws_iam_instance_profile.prometheus.name}"
#  ebs_optimized          = true
  user_data              = "${data.template_file.prometheus.rendered}"

  root_block_device {
    volume_type           = "gp2"
    delete_on_termination = true
    volume_size           = "${var.volume_size}"
  }

  tags = "${merge(var.tags,
    map("Name", "${var.env}-${var.application}-${var.component}"),
  )}"
}

data "aws_security_group" "monitoring_sec_group" {
  filter {
    name   = "tag:Name"
    values = ["${var.monitoring_sec_group}"]
  }
}

# A Security Group that controls what network traffic can go in and out of the EC2 instance
resource "aws_security_group" "prometheus" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.component}"
  description = "A Security Group for ${var.component}"

  tags = "${merge(var.tags,
    map("Name", "${var.env}-${var.application}-${var.component}"),
  )}"

  # Inbound 80 from ELB
  ingress {
    from_port       = "80"
    to_port         = "80"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.prometheus-elb.id}"]
  }

  # Inbound 8080 from anywhere
  ingress {
    from_port       = "8080"
    to_port         = "8080"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.prometheus-elb.id}"]
  }

  # Inbound SSH from anywhere
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${var.sg_bastion_id}"]
  }

  # Outbound everything
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "prometheus-policy" {

  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:Describe*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:Describe*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:Describe*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "prometheus" {
  name = "${var.component}"
  path = "/"

  policy = "${data.aws_iam_policy_document.prometheus-policy.json}"
}

resource "aws_iam_role" "prometheus" {
  name               = "${var.component}"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

resource "aws_iam_policy_attachment" "prometheus" {
  name       = "${var.component}"
  roles      = ["${aws_iam_role.prometheus.name}"]
  policy_arn = "${aws_iam_policy.prometheus.arn}"

  lifecycle {
    ignore_changes = ["roles", "users", "groups"]
  }
}

resource "aws_iam_instance_profile" "prometheus" {
  name = "${var.component}"
  role = "${aws_iam_role.prometheus.name}"
}

# ELB
resource "aws_elb" "prometheus" {
  name            = "${var.component}"
  subnets         = ["${var.public_subnets}"]
  security_groups = ["${aws_security_group.prometheus-elb.id}", "${aws_security_group.prometheus.id}"]
  instances       = ["${aws_instance.prometheus.id}"]

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${data.aws_acm_certificate.prometheus.arn}"
  }

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 8443
    lb_protocol        = "https"
    ssl_certificate_id = "${data.aws_acm_certificate.prometheus.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

  tags = "${merge(var.tags,
    map("Name", "${var.env}-${var.application}-${var.component}"),
  )}"
}

data "aws_acm_certificate" "prometheus" {
  domain   = "${var.certificate_prefix}.${var.client}.${var.tld}"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "prometheus" {
  name  = "${var.client}.${var.tld}."
}

resource "aws_route53_record" "prometheus" {
  zone_id = "${data.aws_route53_zone.prometheus.zone_id}"
  name    = "${var.subdomain}.${var.client}.${var.tld}"
  type    = "A"

  alias {
    name                   = "${aws_elb.prometheus.dns_name}"
    zone_id                = "${aws_elb.prometheus.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_security_group_rule" "prometheus-elb_ingress_https" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.prometheus-elb.id}"
}

resource "aws_security_group_rule" "prometheus-elb_ingress_https2" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.prometheus-elb.id}"
}

resource "aws_security_group_rule" "prometheus-elb_egress" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = "${aws_security_group.prometheus-elb.id}"
}

resource "aws_security_group" "prometheus-elb" {
  name   = "${var.component}-elb"
  vpc_id = "${var.vpc_id}"

  tags {
    Name = "${var.component}-elb"
    Env  = "${var.env}"
  }
}

data "template_file" "prometheus" {
  template = "${file("${path.module}/user-data.tpl.sh")}"

  vars {
    gitlab_token = "${var.gitlab_token}"
    ansible_tag = "${var.ansible_tag}"
  }
}
