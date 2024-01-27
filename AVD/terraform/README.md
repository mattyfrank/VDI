# Azure Virtual Desktop

Azure Virtual Desktop (AVD), formerly known as Windows Virtual Desktop, is a Microsoft Azure-based system for virtualizing its Windows operating systems, providing virtualized desktops and applications in the cloud.

Microsoft manages the connection brokering and availability of desktops for users to access. Internal IT is responsible for deployment and configuration of the virtual desktops within Azure. Contained in this project is Terraform code for creating and managing those components.

## Environments

Each environment is separated by branches with where each branch only runs its specified variables file within the GitLab pipeline.

### Production Environment

Production or prod branch disallows anyone to push code directly and must go through a merge process. 2 people are required for merge approval.

### Nonprod Environment

Test or Nonprod branch allows anyone in the project to push code directly.

## Manual Terraform Import

Reference: https://www.terraform.io/docs/cli/import/index.html

The pipeline supports [manually importing](https://www.terraform.io/docs/cli/import/index.html) objects into the state file. This should **NOT** be a common action! To import an existing Azure resource into Terraform control, first create the Terraform code, then manually run the pipeline and pass in the variable at run time:

        TF_IMPORT

As an example to import an existing subnet named `internal-desktops-01` with the resource id of `/subscriptions/####/resourceGroups/Subscription_Network_RG/providers/Microsoft.Network/virtualNetworks/vNet-network/subnets/subnet-01`. Run the pipeline with variable

        TF_IMPORT = azurerm_subnet.<terraform_code_resource_name_here> /subscriptions/####/resourceGroups/Subscription_Network_RG/providers/Microsoft.Network/virtualNetworks/vNet-network/subnets/subnet-01

The pipeline also supports [replacing a resource](https://www.terraform.io/cli/commands/plan#replace-address). This action is reserved for a malfunctioning resource. To replace an existing Azure resource in Terraform, first identify the resource variable that needs to be destroyed and recreated, then manually run the pipeline and provide the input variable key `TF_REPLACE` followed by the resource input variable name.

As an example to replace an existing sessionHost run the pipeline with variable:

`TF_REPLACE = module.pool_desktops_w10general.azurerm_windows_virtual_machine.vm[0]`


<!-- If TF state file is locked, visit gitlab repo, navigate to operations, terraform, and under actions click unlock -->