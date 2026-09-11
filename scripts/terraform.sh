#!/bin/sh


# Compare the commits and create the file list
#git diff --name-only $second_last_commit $last_commit > locations.txt
# last_commit=$(git rev-parse HEAD~0)
# second_last_commit=$(git rev-parse HEAD~1)


echo " "


# Path to the text file containing file locations
locations_file="./scripts/locations.txt"


# Read locations from the file and process each directory
for location in $(cat "$locations_file"); do

    directory=$location
    echo $directory
    echo $2
        cd "$directory"

        if [[ "main" == "$2" ]]; then
            echo "###################Begin#####################"
            pwd
            echo "Running terraform apply in $2 (Production) branch."
            #terraform init -no-color
            terraform init -no-color
            #terraform plan -out=terraform.tfplan -no-color
            terraform apply --auto-approve -no-color
            if [ $? -ne 0 ]; then
                echo "Terraform apply failed, exiting script."
                exit 1
            fi
            echo "***"
            echo "Terraform apply complete."
        fi
        if [[ "dev" == "$2" ]]; then
            echo "###################Begin#####################"
            pwd
            echo "****"
            echo "Running Terraform init in $2 branch."
            terraform init -no-color
            echo "***"
            echo "Running Terraform plan in $2 branch."
            terraform plan -out=terraform.tfplan -no-color
            if [ $? -ne 0 ]; then
                echo "Terraform plan failed, exiting script."
                exit 1
            fi
            terraform show -json ./terraform.tfplan > ./terraform.json
            echo "***"
            echo "Running Terraform Vet validation"
            chmod +x /workspace/scripts/terraform_validator.sh
            sh /workspace/scripts/terraform_validator.sh
            echo "Terraform plan complete."
        fi
        cd -
        echo " "
done < "$locations_file"
