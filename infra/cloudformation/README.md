# CloudFormation notes

1. `backend.yml` intentionally contains placeholders for the EC2 AMI and SSH KeyPair.
2. Replace `ami-REPLACE_ME` with an AMI valid for your AWS region.
3. Replace the `KeyName` default or pass it as a CloudFormation parameter.
4. For a stronger production setup, move EC2 to private subnets behind ALB and add NAT Gateway.
5. The starter kit uses a simple public EC2 layout to keep the 10-day assignment deployable.
6. Before production use, review security groups, encryption, backups, IAM permissions and secret handling.
