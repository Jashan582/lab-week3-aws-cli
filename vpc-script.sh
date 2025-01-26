#!/usr/bin/env bash

set -eu

# Variables
region="us-east-1"
vpc_cidr="10.0.0.0/16"
subnet_cidr="10.0.1.0/24"
key_name="bcitkey"
ami_id="ami-0e1bed4f06a3b463d" # Ubuntu 22.04 AMI in us-east-1

# Create VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $vpc_cidr --query 'Vpc.VpcId' --output text --region $region)
echo "Created VPC: $vpc_id"
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value=MyVPC --region $region

# Enable DNS hostname
aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames "{\"Value\":true}" --region $region
echo "Enabled DNS hostname for VPC: $vpc_id"

# Create public subnet
subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id \
  --cidr-block $subnet_cidr \
  --availability-zone ${region}a \
  --query 'Subnet.SubnetId' \
  --output text --region $region)
echo "Created Subnet: $subnet_id"
aws ec2 create-tags --resources $subnet_id --tags Key=Name,Value=PublicSubnet --region $region

# Create internet gateway
igw_id=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' \
  --output text --region $region)
echo "Created Internet Gateway: $igw_id"
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region

# Create route table
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id \
  --query 'RouteTable.RouteTableId' \
  --output text --region $region)
echo "Created Route Table: $route_table_id"

# Associate route table with public subnet
aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id --region $region
echo "Associated Route Table: $route_table_id with Subnet: $subnet_id"

# Create route to the internet via the internet gateway
aws ec2 create-route --route-table-id $route_table_id \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --region $region
echo "Created Internet Route for Route Table: $route_table_id"

# Create security group in the VPC
security_group_id=$(aws ec2 create-security-group \
  --group-name MySecurityGroup \
  --description "My security group" \
  --vpc-id $vpc_id \
  --query 'GroupId' \
  --output text --region $region)
echo "Created Security Group: $security_group_id"

# Add inbound rule to allow SSH (port 22)
aws ec2 authorize-security-group-ingress \
  --group-id $security_group_id \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $region
echo "Added SSH rule to Security Group: $security_group_id"

# Launch EC2 instance
instance_id=$(aws ec2 run-instances \
  --image-id $ami_id \
  --instance-type t2.micro \
  --key-name $key_name \
  --security-group-ids $security_group_id \
  --subnet-id $subnet_id \
  --associate-public-ip-address \
  --query 'Instances[0].InstanceId' \
  --output text --region $region)
echo "Launched EC2 instance: $instance_id"

# Wait until the instance is running
aws ec2 wait instance-running --instance-ids $instance_id --region $region
echo "Instance $instance_id is now running."

# Get the public IP address of the instance
public_ip=$(aws ec2 describe-instances \
  --instance-ids $instance_id \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region $region)
echo "Instance Public IP: $public_ip"

# Save instance and infrastructure data to files
echo "public_ip=${public_ip}" > instance_data
echo "Instance data saved to instance_data"
echo "vpc_id=${vpc_id}" > infrastructure_data
echo "subnet_id=${subnet_id}" >> infrastructure_data
echo "security_group_id=${security_group_id}" >> infrastructure_data
echo "Infrastructure data saved to infrastructure_data"
