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

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 3333 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 8080 \
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
    --user-data file://config_sfw.sh \
    --query 'Instances[0].{ID:InstanceId, Type:InstanceType, Key:KeyName, State:State.Name, Subnet:SubnetId}' \
    --output table

echo "Instância criada com sucesso"

INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,pending" \
    --query "Reservations[0].Instances[-1].[InstanceId]" \
    --output text)

ALLOCATTION_ID=$(aws ec2 allocate-address \
    --query 'AllocationId' \
    --output text)

echo -e "\nCriando ip elástico"
aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATTION_ID"

echo -e "\nAssociando função IAM"
aws ec2 associate-iam-instance-profile \
    --instance-id "$INSTANCE_ID" \
    --iam-instance-profile Name="LabInstanceProfile"

echo -e "\nChecando informações das instâncias"
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],KeyName,InstanceType,State.Name, PublicIpAddress]" \
    --output table

BUCKET_RAW="s3-raw-syncheart"
echo -e "\nCriando bucket $BUCKET_RAW"
aws s3 mb s3://$BUCKET_RAW

BUCKET_TRUSTED="s3-trusted-syncheart"
echo -e "\nCriando bucket $BUCKET_TRUSTED"
aws s3 mb s3://$BUCKET_TRUSTED

BUCKET_CLIENT="s3-client-syncheart"
echo -e "\nCriando bucket $BUCKET_CLIENT"
aws s3 mb s3://$BUCKET_CLIENT

NOME_FUNCAO="lambda-syncheart-offline"
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)  
JAR_PATH="../SyncHeart-Java/etl_offline/target/etl_offline-1.0-SNAPSHOT.jar"     
HANDLER="school.sptech.Main::enviarAlertasOfflineJira"                       
RUNTIME="java21"                                    
TIMEOUT=180                                         
ENV_CHAVE="BD_IP"
ENV_VALOR=$(aws ec2 describe-instances \
     --filters "Name=tag:id,Values=${INSTANCE_ID}" \
     --query 'Reservations[*].Instances[*].PublicIpAddress' \ 
     --output text)

echo "criando lambda offline" 
aws lambda create-function \
    --function-name "$NOME_FUNCAO" \
    --runtime "$RUNTIME" \
    --role "$ROLE_ARN" \
    --handler "$HANDLER" \ 
    --timeout "$TIMEOUT" \
    --environment "Variables={$ENV_CHAVE=$ENV_VALOR}" \
    --zip-file "fileb://$JAR_PATH" \
    --output table

echo "criando url para lambda"
aws lambda create-function-url-config \
    --function-name "$NOME_FUNCAO" \
    --auth-type NONE \
    --output table

NOME_REGRA="Regra-Monitoramento-6min"
INTERVALO_CRON="rate(6 minutes)"
AWS_REGION="us-east-1"

echo "Criando regra de agendamento"
aws events put-rule \
    --name "$NOME_REGRA" \
    --schedule-expression "$INTERVALO_CRON" \
    --state ENABLED \
    --region "$AWS_REGION" \
    --output text

echo "Concedendo permissão de invocação para a Lambda"
aws lambda add-permission \
    --function-name "$NOME_FUNCAO" \
    --statement-id "EventBridgeInvokePermission" \
    --action "lambda:InvokeFunction" \
    --principal "events.amazonaws.com" \
    --source-arn "arn:aws:events:$AWS_REGION:$CONTA:rule/$NOME_REGRA" \
    --region "$AWS_REGION" \
    --output text

echo "Vinculando a Lambda à regra de agendamento"
aws events put-targets \
    --rule "$NOME_REGRA" \
    --targets "Id=1,Arn=arn:aws:lambda:$AWS_REGION:$CONTA:function:$NOME_FUNCAO" \
    --region "$AWS_REGION" \
    --output text

# echo "criando lambda trusted"
# NOME_FUNCAO_TRUSTED="lambda-syncheart-trusted"
# TIMEOUT_TRUSTED=360       
# HANDLER_TRUSTED="school.sptech.Main::main"                                
# JAR_PATH_TRUSTED="../SyncHeart-Java/etl_v1/target/etl_v1-1.0-SNAPSHOT.jar"     

# aws lambda create-function \
#     --function-name "$NOME_FUNCAO_TRUSTED" \
#     --runtime "$RUNTIME" \
#     --role "$ROLE_ARN" \
#     --handler "$HANDLER_TRUSTED" \
#     --timeout "$TIMEOUT_TRUSTED" \ 
#     --memory-size 512 \
#     --environment "Variables={$ENV_CHAVE=$ENV_VALOR}" \
#     --zip-file "fileb://$JAR_PATH_TRUSTED" \
#     --output table
	
# echo "criando url para lambda trusted"
# aws lambda create-function-url-config \
#     --function-name "$NOME_FUNCAO_TRUSTED" \
#     --auth-type NONE \
#     --output table

# CONTA=$(aws sts get-caller-identity --query "Account" --output text)
# aws lambda add-permission 
#     --function-name "$NOME_FUNCAO_TRUSTED" \
#     --statement-id S3InvokePermission \
#     --action "lambda:InvokeFunction" \
#     --principal s3.amazonaws.com \
#     --source-arn arn:aws:s3:::$BUCKET_RAW \
#     --source-account $CONTA

# echo "configurando trigger"
# aws s3api put-bucket-notification-configuration --bucket $BUCKET_RAW --notification-configuration "{
#   \"LambdaFunctionConfigurations\": [
#     {
#       \"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:$CONTA:function:$NOME_FUNCAO_TRUSTED\",
#       \"Events\": [\"s3:ObjectCreated:*\"]
#     }
#   ]
# }"