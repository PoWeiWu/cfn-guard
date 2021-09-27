#!/bin/bash

rule_name=$1
check_data=$2

echo "$rule_name"
echo "$check_data"

# echo "terraform init"
# terraform init
echo "Output terraform plan json-formatted file"
terraform plan --out tfplan.binary
terraform show -json tfplan.binary > $check_data

# delete binary file
rm -f tfplan.binary

echo "Policy Check"
cfn-guard validate -r $rule_name -o yaml -d $check_data || check_state=$?


if [ "$check_state" = '5' ]
then
    echo "fail"
    exit 0
else
    echo "pass"
    terraform apply -auto-approve
fi


