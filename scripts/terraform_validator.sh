terraform validate
POLICY_LIBRARY="/workspace/policy-library"
VIOLATIONS=$(gcloud beta terraform vet terraform.json --policy-library=$POLICY_LIBRARY --format=json)
retVal=$?
if [ $retVal -eq 2 ]; then
  # Optional: parse the VIOLATIONS variable as json and check the severity level
  echo "$VIOLATIONS" > VIOLATIONS.txt
  echo "Violations found; not proceeding with terraform apply"
  exit 1
fi
if [ $retVal -ne 0 ]; then
  echo "Error during gcloud beta terraform vet; not proceeding with terraform apply"
  exit 1
fi

echo "No policy violations detected; proceeding with terraform apply"
