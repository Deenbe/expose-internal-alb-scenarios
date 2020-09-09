# Public Network Load Balancer

- Create Public Network Load Balancer
- Create VPC Endpoint Service, to be accessible over AWS PrivateLink
- Allows Consumer Account Id and Consumer IAM role, both are configured via vars.env file at the root directory, via VPC Endpoint Permission

Public Network Load Balancer (VPC Endpoint Service + VPC Endpoint Service permission) -------> Private ALB ----> ECS tasks running in Private Subnet