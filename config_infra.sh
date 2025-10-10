#!/bin/bash

echo "Capturando id da VPC"
VPC_ID=$(aws ec2 describe-vpcs \
    --query "Vpcs[0].[VpcId]" \
    --output text)
echo -e "VPC-ID: $VPC_ID\n"

echo "Capturando id da subnet"
SUBNET_ID=$(aws ec2 describe-subnets \
    --query "Subnets[4].[SubnetId]" \
    --output text)
echo -e "SUBNET_ID: $SUBNET_ID\n"

echo "Criando par de chaves"
aws ec2 create-key-pair \
    --key-name minhachave \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > minhachave.pem
echo "Chave criada: minhachave"

chmod 400 minhachave.pem

echo -e "\nCriando grupo de segurança"
aws ec2 create-security-group \
    --group-name launch-wizard-42 \
    --vpc-id "$VPC_ID" \
    --description "grupo de seguranca 042" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=sg-042}]"

echo -e "\nCapturando id do grupo de segurança"
SG_ID=$(aws ec2 describe-security-groups \
    --query "SecurityGroups[?contains(GroupName, '42')].[GroupId]" \
    --output text)
echo -e "SG_ID: $SG_ID\n"

echo -e "\nCriação de regra de entrada no grupo de segurança"
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 3306 \
    --cidr 0.0.0.0/0

echo -e "\nCriando instância"
aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --count 1 \
    --security-group-ids "$SG_ID" \
    --instance-type t3.small \
    --subnet-id "$SUBNET_ID" \
    --key-name minhachave \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=syncheart-server}]' \
    --user-data file://config_sfw.sh

echo "Instância criada com sucesso"

INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[-1].[InstanceId]" \
    --output text)

ALLOCATTION_ID=$(aws ec2 allocate-address \
    --query 'AllocationId' \
    --output text)

echo -e "\nCriando ip elástico"
aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATTION_ID"

echo -e "\nChecando informações das instâncias"
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],KeyName,InstanceType,State.Name, PublicIpAddress]" \
    --output table
