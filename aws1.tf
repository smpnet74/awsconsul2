provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_security_group" "consumers" {

  name = "os_consumer"
  vpc_id = "vpc-e6032a83"
  description = "Security group to allow all sources to intercommunicate and to talk out"

  ingress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    self = true
    cidr_blocks = ["73.210.192.218/32"]
  }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    name = "ossg1"
  }
}

data "template_file" "consulfiles" {
    template = "${file("./consul.tpl")}"
    vars {
        LEADER= "${aws_instance.consul.0.private_ip}"
        SERVERCOUNT = "${var.consul_servers}"
    }
}

data "template_file" "userdata" {
  template = "${file("./userdata.tpl")}"
    vars {
        CONSUL= "0.7.0"
    }
}

//Create the aws bucket
//
resource "aws_s3_bucket" "user_data" {
    bucket = "smpuserdatabucket"
}

resource "aws_s3_bucket_object" "consul_userdata" {
    depends_on = ["aws_s3_bucket.user_data", "aws_instance.consul"]
    bucket = "smpuserdatabucket"
    key = "consul_userdata"
    content = "${data.template_file.consulfiles.rendered}"
}

//Create the policy that is assigned to the role to be assumed which is attached to an instance Profile
//
//Creates the IAM instance profile that will be assigned to the ec2 instances

//Creates the policy that will be attached to the ec2 assume role
resource "aws_iam_role_policy" "consul_instance_policy" {
    name = "consul_test_policy"
    role = "${aws_iam_role.consul_instance_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1477509636623",
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::smpuserdatabucket/*"
    },
    {
      "Sid": "Stmt1477509636624",
      "Action": "kms:*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

//Creates the role that will be assigned to the iam_instance_profile of the instance
resource "aws_iam_role" "consul_instance_role" {
    name = "consul_test_role"
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

resource "aws_iam_instance_profile" "consul_ec2_profile" {
    name = "ConsulEc2Profile"
    roles = ["${aws_iam_role.consul_instance_role.name}"]
}

resource "aws_instance" "consul" {
    ami = "ami-2d39803a"
    instance_type = "t2.micro"
    subnet_id = "subnet-49f27362"
    key_name = "ostempkey"
    count = "${var.consul_servers}"
    user_data = "${data.template_file.userdata.rendered}"
    vpc_security_group_ids = ["${aws_security_group.consumers.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.consul_ec2_profile.id}"
    tags {
        Name = "Consultest-${count.index}"
    }
}
