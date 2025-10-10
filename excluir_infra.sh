#!/bin/bash

INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[-1].[InstanceId]" \
    --output text)

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
echo "Excluindo instância"

aws ec2 delete-key-pair --key-name minhachave
rm -f minhachave.pem
echo -e "\nExcluindo par de chaves"

SG_ID=$(aws ec2 describe-security-groups \
    --query "SecurityGroups[?contains(GroupName, '42')].[GroupId]" \
    --output text)
aws ec2 delete-security-group --group-id "$SG_ID"
echo -e "\nExcluindo grupo de segurança"

ALLOCATTION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AllocationId" \
    --output text)

ASSOCIATION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AssociationId" \
    --output text)

aws ec2 disassociate-address --association-id "$ASSOCIATION_ID"
aws ec2 release-address --allocation-id "$ALLOCATTION_ID"
echo -e "\nExcluindo IP elástico"


