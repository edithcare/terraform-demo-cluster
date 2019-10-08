# AWS demo cluster

## Getting started

```sh
terraform plan -out .tfplan
terraform apply .tfplan
```

## TODOs

- Tighten [network ACLs][1]
- Revisit [security groups][2]
- Auto-update worker nodes
- Create a [tagging strategy][3] and tag resources
- Add support for [spot][4] instances
- Add AlwaysPullImages admission controllers

## Features

- Encrypted default storage class
- Worker nodes in private subnets, NAT per availability zone
- Automatic DNS provisioning via [ExternalDNS](
  https://github.com/kubernetes-incubator/external-dns)
- [GPU] nodes

## Further links

- <https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt>
- <https://github.com/awslabs/amazon-eks-ami/issues/66>
- <https://aws.amazon.com/blogs/opensource/firecracker-open-source-secure-fast-microvm-serverless/>
- <https://medium.com/@gokulchandrapr/kata-containers-on-kubernetes-and-kata-firecracker-vmm-support-28abb3a196e7>
- <https://github.com/kata-containers/documentation/blob/master/install/aws-installation-guide.md>
- <https://github.com/IBM/portieris>

[1]: https://docs.aws.amazon.com/en_pv/vpc/latest/userguide/vpc-network-acls.html
[2]: https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
[3]: https://aws.amazon.com/answers/account-management/aws-tagging-strategies/
[4]: https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#mixed_instances_policy-instances_distribution
