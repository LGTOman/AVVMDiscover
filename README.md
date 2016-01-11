# AVVMDiscover

A **PERL** script to automatically discover new Virtual Machines or vApps in vSphere and asign them to Avamar Policies. Virtual Machine discovery is performed based on the Virtual Machine's: Datacenter, Cluster or ESXi Host, Resoruce Group, Virtual Machine Folder and/or Name.

## Description

AVVMDiscover runs on an Avamar server and uses Avamar's `mccli` uitlity to query vSphere for new VMs and/or vApps. It then uses user sepcified options to place those VMs and/or vApps in the appropirate Avamar Policies. When run on a daily basis from cron AVVMDiscover will detect VMs that have been removed from a policy and add them back again. 

## Installation

1) Login to your Avamar single node, AVE or Utility Node as admin.

2) Create and change to a dirctory called /home/admin/scripts/AVVMDiscover.

```bash
mkdir -p /home/admin/scripts/AVVMDiscover
cd /home/admin/scripts/AVVMDiscover
```

3) Copy this respsitory from GITHub to your Avamar single node, AVE or Utility Node. This can be done directily with the command:

```bash
curl -L https://github.com/LGTOman/AVVMDiscover/tarball/master | tar xz --strip-components=1
```

4) Make the `AVVMDiscover.pl` script executable

```bash
chmod +x AVVMDiscover.pl
```

5) Edit the `VMsToExclude.txt` file and add any VMs, vApps or regex patterns to exclude.

6) Run `AVVMDisvover.pl` with the appropriate options and verify that VMs and/or vApps are added as expected. Example:

```bash
 /home/admin/scripts/AVVMDiscover/AVVMDiscover.pl --vcenter=brs-sjc-vcenter-1 --datacenter="BRS SJC SE Lab" --policy="VM Backups" --policydomain=/brs-sjc-vcenter-1/VirtualMachines
```

7) Schedule `AVVMDiscover.pl` to run in cron. Example: 

```bash
admin@brs-sjc-av-1:~/scripts/>: sudo crontab -u admin -e
```

```
05 19 * * * /home/admin/scripts/AVVMDiscover/AVVMDiscover.pl --vcenter=brs-sjc-vcenter-1 --datacenter="BRS SJC SE Lab" --policy="VM Backups" --policydomain=/brs-sjc-vcenter-1/VirtualMachines >> /home/admin/scripts/AVVMDiscover/AVVMDiscover-brs-sjc-vcenter-1.log 2>&1
```
## Usage Instructions

### DESCRIPTION

 `AVVMDiscover.pl` will query Avamar for the vcenter specificed and add vApps and VMs to it based on the query options
 that are specified. The script can add vApps and/or VMs based soly on what vCenter Datacenter that they reside
 in. It can also be retricted to vApps and/or VMs that are part of a host or cluster, full or partial name of
 the vApp and/or VM, in a specfic vCenter folder, or part of a Resource Group. The filters are additive, meaning
 that adding a filter will make the vApps and/or VMs that are selected more specific.

 An exclude file can also be specified. This file contains the names of any vApps and/or VMs that should be
 excluded from the vApps and/or VMs being added and not backed up. One vApp and/or VM is listed per line in the
 exclude file.

### Usage 

 AVVMDiscover.pl [options] --vcenter=<vcenter> --datacenter=<Datacenter> --policy=<Policy> --policydomain=<PolicyDomain>
                 [--hostorcluster=<HostOrClusterName>] [--vmnamequery=<VMNameQuery>] [--folderquery=<FolderQuery>]
                 [--resourcegroup=<ResourceGroupQuery>]  [--excludefile=<ExcludeFile>]

 Options:
   -? | --help      Brief help message
   --debug          Debug mode
   --cache          Use cached mccli data in xml files instead of quering Avamar. For development only.
   --genxmls        Generates xml files for caching. For development only.
   --recursive      Only used with --folderquery. Causes search to be recursive in the folder structure.
                    a regex search is used for this. The folder path is in standard Linux/Unix format.
                    For example /FolderA/FolderB/FolderC. It's recommended to inclue the parent folder
                    name in escaped forward slashes so that the specific folder is matched. Including the
                    full path of the folder will also help. To match FolderB and everything below it in
                    the example you would use: --folderquery="\/FolderA\/FolderB\/" --recursive. Other
                    special charecters such as ( or ) may also need to be escaped.

 --vcenter=<vcenter>                  <required> The name of vCenter as it appears in the domain list in
                                                 Avamar.
 --datacenter=<Datacenter>            <required> The name of the datacenter in vCenter who's vApps
                                                 and/or VMs will be added.
 --policy=<Policy>                    <required> The Policy/Group in Avamar to add the vApp and/or VM too.
 --policydomain=<PolicyDomain>        <required> The full path of the Avamar Domain in which the
                                                 Policy/Group resides.
 --hostorcluster=<HostOrClusterName>  [optional] The ESX host or vCenter cluster from which vApps and/or
                                                 VMs should be selected.
                                                 Can be used in conjunction with all other queries.
                                                 NOTE: ESX hosts that are part of clusters cannot be
                                                       selected. Only the cluser can be selected.
                                                 NOTE: ESX host names must appear exactly as they are
                                                       in vCenter or Avamar. This could be the short name,
                                                       FQDN or IP address.
 --vmnamequery=<VMNameQuery>          [optional] A regexp query to select the vApp and/or VM name.
                                                 Can be used in conjunction with all other queries.
 --folderquery=<FolderQuery>          [optional] A regexp query to select the folder that the vApp and/or
                                                 VM is in.
                                                 Can be used in conjunction with all other queries.
                                                 NOTE: For nested folders only the folder that the vApp
                                                       and/or VM is in is matched. Parent folders are not
                                                       matched. In other words a folder containing
                                                       subfolders will only backup the vApp and/or VMs
                                                       in the folder selected, not any of the subfolders.
 --resourcegroup=<ResourceGroupQuery> [optional] A regexp query to select the Resource Group that the vAPP
                                                 and/or VM is in.
                                                 Can be used in conjunction with all other queries.
                                                 NOTE: If the resource group that the vApp and/or VM is in
                                                       is called "Resoruces" this script will not match it.
 --excludefile=<ExcludeFile>          [optional] A file that lists spcific vApps and/or VMs to exclude from
                                                 the backups. The default file is VMsToExclude.txt in the
                                                 same directory as this script.

 NOTE: All queries are case sensitive, regex format.


## Future

- Detect VMs that have moved between policy domains.
- Detect VMs based on their vSphere tag.
- Detect VMs that have been deleted from vSphere and retire them in Avamar.
