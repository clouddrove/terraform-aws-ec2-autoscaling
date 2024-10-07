## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| associate\_public\_ip\_address | Associate a public IP address with an instance in a VPC. | `bool` | `false` | no |
| cpu\_utilization\_high\_evaluation\_periods | The number of periods over which data is compared to the specified threshold. | `number` | `2` | no |
| cpu\_utilization\_high\_period\_seconds | The period in seconds over which the specified statistic is applied. | `number` | `300` | no |
| cpu\_utilization\_high\_statistic | The statistic to apply to the alarm's associated metric. Either of the following is supported: `SampleCount`, `Average`, `Sum`, `Minimum`, `Maximum`. | `string` | `"Average"` | no |
| cpu\_utilization\_high\_threshold\_percent | The value against which the specified statistic is compared. | `number` | `90` | no |
| cpu\_utilization\_low\_evaluation\_periods | The number of periods over which data is compared to the specified threshold. | `number` | `2` | no |
| cpu\_utilization\_low\_period\_seconds | The period in seconds over which the specified statistic is applied. | `number` | `200` | no |
| cpu\_utilization\_low\_statistic | The statistic to apply to the alarm's associated metric. Either of the following is supported: `SampleCount`, `Average`, `Sum`, `Minimum`, `Maximum`. | `string` | `"Average"` | no |
| cpu\_utilization\_low\_threshold\_percent | The value against which the specified statistic is compared. | `number` | `10` | no |
| default\_cooldown | The amount of time, in seconds, after a scaling activity completes before another scaling activity can start. | `number` | `150` | no |
| delimiter | Delimiter to be used between `organization`, `environment`, `name` and `attributes`. | `string` | `"-"` | no |
| desired\_capacity | The number of Amazon EC2 instances that should be running in the group. | `number` | `3` | no |
| ebs\_encryption | Enables EBS encryption on the volume (Default: false). Cannot be used with snapshot\_id. | `bool` | `false` | no |
| enable\_monitoring | Enable/disable detailed monitoring. | `bool` | `true` | no |
| enabled | Whether to create the resources. Set to `false` to prevent the module from creating any resources. | `bool` | `true` | no |
| enabled\_metrics | A list of metrics to collect. The allowed values are `GroupMinSize`, `GroupMaxSize`, `GroupDesiredCapacity`, `GroupInServiceInstances`, `GroupPendingInstances`, `GroupStandbyInstances`, `GroupTerminatingInstances`, `GroupTotalInstances`. | `list(string)` | <pre>[<br>  "GroupMinSize",<br>  "GroupMaxSize",<br>  "GroupDesiredCapacity",<br>  "GroupInServiceInstances",<br>  "GroupPendingInstances",<br>  "GroupStandbyInstances",<br>  "GroupTerminatingInstances",<br>  "GroupTotalInstances"<br>]</pre> | no |
| environment | Environment (e.g. `prod`, `dev`, `staging`). | `string` | `""` | no |
| force\_delete | Allows deleting the autoscaling group without waiting for all instances in the pool to terminate. You can force an autoscaling group to delete even if it's in the process of scaling a resource. Normally, Terraform drains all the instances before deleting the group. This bypasses that behavior and potentially leaves resources dangling. | `bool` | `false` | no |
| health\_check\_grace\_period | Time (in seconds) after instance comes into service before checking health. | `number` | `300` | no |
| health\_check\_type | Controls how health checking is done. Valid values are `EC2` or `ELB`. | `string` | `"EC2"` | no |
| iam\_instance\_profile\_name | The IAM instance profile name to associate with launched instances. | `string` | `null` | no |
| image\_id | The EC2 image ID to launch. | `string` | `""` | no |
| instance\_initiated\_shutdown\_behavior | Shutdown behavior for the instances. Can be `stop` or `terminate`. | `string` | `"terminate"` | no |
| instance\_interruption\_behavior | The behavior when a Spot Instance is interrupted. Can be hibernate, stop, or terminate. (Default: terminate). | `string` | `"terminate"` | no |
| instance\_profile\_enabled | Associate a public IP address with an instance in a VPC. | `bool` | `true` | no |
| instance\_type | Instance type to launch. | `string` | `"t2.nano"` | no |
| key\_name | The SSH key name that should be used for the instance. | `string` | `""` | no |
| kms\_key\_arn | AWS Key Management Service (AWS KMS) customer master key (CMK) to use when creating the encrypted volume. encrypted must be set to true when this is set. | `string` | `""` | no |
| label\_order | Label order, e.g. `name`,`application`. | `list(any)` | <pre>[<br>  "environment",<br>  "name"<br>]</pre> | no |
| load\_balancers | A list of elastic load balancer names to add to the autoscaling group names. Only valid for classic load balancers. For ALBs, use `target_group_arns` instead. | `list(string)` | `[]` | no |
| managedby | ManagedBy, eg 'CloudDrove' or 'AnmolNagpal'. | `string` | `"anmol@clouddrove.com"` | no |
| max\_price | The maximum hourly price you're willing to pay for the Spot Instances. | `string` | `""` | no |
| max\_size | The maximum size of the autoscale group. | `number` | `3` | no |
| max\_size\_scaledown | The maximum size for the Auto Scaling group. Default 0. Set to -1 if you don't want to change the minimum size at the scheduled time. | `number` | `1` | no |
| max\_size\_scaleup | The maximum size of the autoscale group. | `number` | `3` | no |
| metrics\_granularity | The granularity to associate with the metrics to collect. The only valid value is 1Minute. | `string` | `"1Minute"` | no |
| min\_elb\_capacity | Setting this causes Terraform to wait for this number of instances to show up healthy in the ELB only on creation. Updates will not wait on ELB instance number changes. | `number` | `null` | no |
| min\_size | The minimum size of the autoscale group. | `number` | `1` | no |
| min\_size\_scaledown | The minimum size for the Auto Scaling group. Default 0. Set to -1 if you don't want to change the minimum size at the scheduled time. | `number` | `0` | no |
| min\_size\_scaleup | The minimum size of the autoscale group. | `number` | `1` | no |
| name | Name  (e.g. `app` or `cluster`). | `string` | `""` | no |
| on\_demand\_enabled | Whether to create `aws_autoscaling_policy` and `aws_cloudwatch_metric_alarm` resources to control Auto Scaling. | `bool` | `true` | no |
| protect\_from\_scale\_in | Allows setting instance protection. The autoscaling group will not select instances with this setting for terminination during scale in events. | `bool` | `false` | no |
| repository | Terraform current module repo | `string` | `"https://github.com/clouddrove/terraform-aws-ec2-autoscaling"` | no |
| scale\_down\_adjustment\_type | Specifies whether the adjustment is an absolute number or a percentage of the current capacity. Valid values are `ChangeInCapacity`, `ExactCapacity` and `PercentChangeInCapacity`. | `string` | `"ChangeInCapacity"` | no |
| scale\_down\_cooldown\_seconds | The amount of time, in seconds, after a scaling activity completes and before the next scaling activity can start. | `number` | `300` | no |
| scale\_down\_desired | The number of Amazon EC2 instances that should be running in the group. | `number` | `0` | no |
| scale\_down\_policy\_type | The scalling policy type, either `SimpleScaling`, `StepScaling` or `TargetTrackingScaling`. | `string` | `"SimpleScaling"` | no |
| scale\_down\_scaling\_adjustment | The number of instances by which to scale. `scale_down_scaling_adjustment` determines the interpretation of this number (e.g. as an absolute number or as a percentage of the existing Auto Scaling group size). A positive increment adds to the current capacity and a negative value removes from the current capacity. | `number` | `-1` | no |
| scale\_up\_adjustment\_type | Specifies whether the adjustment is an absolute number or a percentage of the current capacity. Valid values are `ChangeInCapacity`, `ExactCapacity` and `PercentChangeInCapacity`. | `string` | `"ChangeInCapacity"` | no |
| scale\_up\_cooldown\_seconds | The amount of time, in seconds, after a scaling activity completes and before the next scaling activity can start. | `number` | `150` | no |
| scale\_up\_desired | The number of Amazon EC2 instances that should be running in the group. | `number` | `0` | no |
| scale\_up\_policy\_type | The scalling policy type, either `SimpleScaling`, `StepScaling` or `TargetTrackingScaling`. | `string` | `"SimpleScaling"` | no |
| scale\_up\_scaling\_adjustment | The number of instances by which to scale. `scale_up_adjustment_type` determines the interpretation of this number (e.g. as an absolute number or as a percentage of the existing Auto Scaling group size). A positive increment adds to the current capacity and a negative value removes from the current capacity. | `number` | `1` | no |
| schedule\_enabled | AutoScaling Schedule resource | `bool` | `false` | no |
| scheduler\_down | What is the recurrency for scaling up operations ? | `string` | `"0 19 * * MON-FRI"` | no |
| scheduler\_up | What is the recurrency for scaling down operations ? | `string` | `"0 6 * * MON-FRI"` | no |
| security\_group\_ids | A list of associated security group IDs. | `list(string)` | `[]` | no |
| service\_linked\_role\_arn | The ARN of the service-linked role that the ASG will use to call other AWS services. | `string` | `""` | no |
| spot\_desired\_capacity | The number of Amazon EC2 instances that should be running in the group. | `number` | `3` | no |
| spot\_enabled | Whether to create the spot instance. Set to `false` to prevent the module from creating any  spot instances. | `bool` | `false` | no |
| spot\_instance\_type | Sport instance type to launch. | `string` | `"t2.medium"` | no |
| spot\_max\_size | The maximum size of the spot autoscale group. | `number` | `"1"` | no |
| spot\_max\_size\_scaledown | The maximum size for the Auto Scaling group of spot instances. Default 0. Set to -1 if you don't want to change the minimum size at the scheduled time. | `number` | `1` | no |
| spot\_min\_size | The minimum size of the spot autoscale group. | `number` | `"1"` | no |
| spot\_min\_size\_scaledown | The minimum size for the Auto Scaling group of spot instances. Default 0. Set to -1 if you don't want to change the minimum size at the scheduled time. | `number` | `0` | no |
| spot\_scale\_down\_desired | The number of Amazon EC2 instances that should be running in the group. | `number` | `0` | no |
| spot\_scale\_up\_desired | The number of Amazon EC2 instances that should be running in the group. | `number` | `0` | no |
| spot\_schedule\_enabled | AutoScaling Schedule resource for spot | `bool` | `false` | no |
| subnet\_ids | A list of subnet IDs to launch resources in. | `list(string)` | `[]` | no |
| suspended\_processes | A list of processes to suspend for the AutoScaling Group. The allowed values are `Launch`, `Terminate`, `HealthCheck`, `ReplaceUnhealthy`, `AZRebalance`, `AlarmNotification`, `ScheduledActions`, `AddToLoadBalancer`. Note that if you suspend either the `Launch` or `Terminate` process types, it can prevent your autoscaling group from functioning properly. | `list(string)` | `[]` | no |
| tags | Additional tags (e.g. map(`BusinessUnit`,`XYZ`). | `map(any)` | `{}` | no |
| target\_group\_arns | A list of aws\_alb\_target\_group ARNs, for use with Application Load Balancing. | `list(string)` | `[]` | no |
| termination\_policies | A list of policies to decide how the instances in the auto scale group should be terminated. The allowed values are `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `Default`. | `list(string)` | <pre>[<br>  "Default"<br>]</pre> | no |
| user\_data\_base64 | The Base64-encoded user data to provide when launching the instances. | `string` | `""` | no |
| volume\_size | The size of ebs volume. | `number` | `100` | no |
| volume\_type | The type of volume. Can be `standard`, `gp2`, or `io1`. (Default: `standard`). | `string` | `"standard"` | no |
| wait\_for\_capacity\_timeout | A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. Setting this to '0' causes Terraform to skip all Capacity Waiting behavior. | `string` | `"15m"` | no |

## Outputs

| Name | Description |
|------|-------------|
| autoscaling\_group\_arn | The ARN for this AutoScaling Group |
| autoscaling\_group\_default\_cooldown | Time between a scaling activity and the succeeding scaling activity |
| autoscaling\_group\_desired\_capacity | The number of Amazon EC2 instances that should be running in the group |
| autoscaling\_group\_health\_check\_grace\_period | Time after instance comes into service before checking health |
| autoscaling\_group\_health\_check\_type | `EC2` or `ELB`. Controls how health checking is done |
| autoscaling\_group\_id | The autoscaling group id |
| autoscaling\_group\_max\_size | The maximum size of the autoscale group |
| autoscaling\_group\_min\_size | The minimum size of the autoscale group |
| autoscaling\_group\_name | The autoscaling group name |
| launch\_template\_arn | The ARN of the launch template |
| launch\_template\_id | The ID of the launch template |
