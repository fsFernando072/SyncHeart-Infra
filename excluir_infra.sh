#!/bin/bash

echo "Excluindo instância"
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[-1].[InstanceId]" \
    --output text)

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"

echo -e "\nExcluindo par de chaves"
aws ec2 delete-key-pair --key-name minhachave
rm -f minhachave.pem

echo -e "\nExcluindo grupo de segurança"
SG_ID=$(aws ec2 describe-security-groups \
    --query "SecurityGroups[?contains(GroupName, '42')].[GroupId]" \
    --output text)
aws ec2 delete-security-group --group-id "$SG_ID"


echo -e "\nExcluindo IP elástico"
ALLOCATTION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AllocationId" \
    --output text)

ASSOCIATION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AssociationId" \
    --output text)

aws ec2 disassociate-address --association-id "$ASSOCIATION_ID"
aws ec2 release-address --allocation-id "$ALLOCATTION_ID"

BUCKET_RAW=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 's3-raw-syncheart')].Name | [0]" --output text)
BUCKET_TRUSTED=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 's3-trusted-syncheart')].Name | [0]" --output text)
BUCKET_CLIENT=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 's3-client-syncheart')].Name | [0]" --output text)

echo -e "\nExcluindo bucket $BUCKET_RAW"
aws s3 rm s3://$BUCKET_RAW --recursive
aws s3 rb s3://$BUCKET_RAW --force

echo -e "\nExcluindo bucket $BUCKET_TRUSTED"
aws s3 rm s3://$BUCKET_TRUSTED --recursive
aws s3 rb s3://$BUCKET_TRUSTED --force

echo -e "\nExcluindo bucket $BUCKET_CLIENT"
aws s3 rm s3://$BUCKET_CLIENT --recursive
aws s3 rb s3://$BUCKET_CLIENT --force
