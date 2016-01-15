#!/usr/bin/perl -w

#############################################################################
#       Avamar Virtual Machine Discover
#       --------------------------------
#  This script dynamically adds Virtual Machines to Avamar and assigns backup
#  policies based on the VM's Datacenter, Cluster/Host, Resource Group,
#  VM Folder, and/or Name.
#
#  Place this script on the Utilty Node at /home/admin/scripts (as "admin")
#  and make executable (chmod 755). Run the script with the parameters as 
#  defined below. If you need to exclude VMs use the exclude file option.
#  After running initally the script can be scheduled via cron. It's
#  recommeded to run it 55 minutes before the first backup of any VMs. This
#  is because Avamar's cache of vCenter is updated 60 minutes before the
#  first scheduled VM backup. Running this script 5 minutes later will ensure
#  that it has the most up to date infomration to work with.
#
#  NOTE: VMs will be added to the /<vcenter>/VirtualMachines domain in Avamar.
#
#  Author: Damani Norman - damani.norman@emc.com - 02/19/2015  
#  Updated: Damani Norman - damani.norman@emc.com - 03/12/2015
#           - Added error checking for missing excludefile.
#           - Updated error messages for missing files with "ERROR:" prefix.
#  Updated: Damani Norman - damani.norman@emc.com - 04/14/2015
#           - Fixed exclude so that regex exclusions would work.
#
#############################################################################


use strict;
use warnings;
use XML::LibXML;
use Getopt::Long;
use Pod::Usage;

print "Start time: ";
system("date");
my $sttime = time;

my $vcenter = "";
my $datacenter = "";
my $hostorcluster = "";
my $policy = "";
my $policydomain = "";
my $vmnamequery = "";
my $folderquery = "";
my $resourcegroupquery = "";
my $excludefile = "/home/admin/scripts/VMsToExclude.txt";
my $cache = 0;
my $genxmls = 0;
my $recursive = 0;
my $help = 0;

GetOptions ('vcenter=s' => \$vcenter,
            'datacenter=s' => \$datacenter,
            'hostorcluster=s' => \$hostorcluster,
            'policy=s' => \$policy,
            'policydomain=s' => \$policydomain,
            'vmnamequery=s' => \$vmnamequery,
            'folderquery=s' => \$folderquery,
            'resourcegroup=s' => \$resourcegroupquery,
            'excludefile=s' => \$excludefile,
            'cache' =>\$cache,
            'genxmls' =>\$genxmls,  
            'recursive' =>\$recursive,
            'help|?' =>\$help) or pod2usage(-verbose => 1) && exit;

pod2usage(1) if $help;
#pod2usage("$0: No options given.")  if (@ARGV == 0);
pod2usage("$0: vCenter not specified.")  if ($vcenter eq "");
pod2usage("$0: Datacener not specified.")  if ($datacenter eq "");
pod2usage("$0: Policy not specified.")  if ($policy eq "");
pod2usage("$0: Policy Domain not specified.")  if ($policydomain eq "");
pod2usage("$0: --recursive option only valid with --folderquery.") if ($recursive && $folderquery eq "");

=head1 NAME

 AVVMDiscover.pl - Dyanamically adds Virtual Machines to Avamar

=head1 SYNOPSIS

 AVVMDiscover.pl [options] --vcenter=<vcenter> --datacenter=<Datacenter> --policy=<Policy> --policydomain=<PolicyDomain> 
          [--hostorcluster=<HostOrClusterName>] [--vmnamequery=<VMNameQuery>] [--folderquery=<FolderQuery>]
          [--resourcegroup=<ResourceGroupQuery>]  [--excludefile=<ExcludeFile>]

 Options:
   -? | --help      Brief help message
   --cache          Use cached mccli data in xml files instead of quering Avamar. For development only.
   --genxmls        Generates xml files for caching. For development only.
   --recursive      Only used with --folderquery. Causes search to be recursive in the folder structure. 
                    a regex search is used for this. The folder path is in standard Linux/Unix format. 
                    For example /FolderA/FolderB/FolderC. It's recommended to inclue the parent folder 
                    name in escaped forward slashes so that the specific folder is matched. Including the
                    full path of the folder will also help. To match FolderB and everything below it in 
                    the example you would use: --folderquery="\/FolderA\/FolderB\/" --recursive. Other
                    special charecters such as ( or ) may also need to be escaped.

=head1 OPTIONS

 --vcenter=<vcenter>                  <required> The name of vCenter as it appears in the domain list in Avamar. 
 --datacenter=<Datacenter>            <required> The name of the datacenter in vCenter who's VMs will be added. 
 --policy=<Policy>                    <required> The Policy/Group in Avamar to add the VM too.
 --policydomain=<PolicyDomain>        <required> The full path of the Avamar Domain in which the Policy/Group resides. 
 --hostorcluster=<HostOrClusterName>  [optional] The ESX host or vCenter cluster from which VMs should be selected.
                                                 NOTE: ESX hosts that are part of clusters cannot be selected. Only
                                                       the cluser can be selected. 
                                                 NOTE: ESX host names must appeara exactly as they are in vCenter or
                                                       avamar. This could be the short name, FQDN or IP address.
                                                 Can be used in conjunction with all other queries.
 --vmnamequery=<VMNameQuery>          [optional] A regexp query to select the VM name. 
                                                 Can be used in conjunction with all other queries.
 --folderquery=<FolderQuery>          [optional] A regexp query to select the folder that the VM is in.
                                                 Can be used in conjunction with all other queries.
                                                 NOTE: For nested folders only the folder that the VM is in is
                                                       matched. Parent folders are not matched. In other words
                                                       a folder containinig subfolders will only backup the VMs
                                                       in the folder selected, not any of the subfolders.
 --resourcegroup=<ResourceGroupQuery> [optional] A regexp query to select the Resource Group that the VM is in.  
                                                 Can be used in conjunction with all other queries.
                                                 NOTE: If the resource group that the VM is in is called "Resoruces"
                                                       this script will not match it.
 --excludefile=<ExcludeFile>          [optional] A file that lists spcific VMs to exclude from the backups.
                                                 The default file is VMsToExclude.txt in the same directory as
                                                 this script.

 NOTE: All queries are case sensitive, regex format.

=head1 DESCRIPTION 

 B<AVVMDiscover.pl> will query Avamar for the vcenter specificed and add VMs to it based on the query options that are
 specified. The script can add VMs based soly on what vCenter Datacenter that they reside in. It can also be
 retricted to VMs that are part of a host or cluster, full or partial name of the VM, in a specfic vCenter folder,
 or part of a Resource Group. The filters are additive, meaning that adding  a filter will make the VMs that are
 selected more specific. 

 An exclude file can also be specified. This file contains the names of any VMs that shoudl be excluded from 
 the VMs being added and not backed up. One VM is listed per line in the exclude file.

=cut

#my $vcenter = "brs-sjc-vcenter-1";
#my $datacenter = "BRS SJC SE Lab";
#my $hostorcluster = "BRS SJC CLUSTER 1 - Physical";
#my $policy = "VM Backups";
#my $policydomain="/$vcenter/VirtualMachines";
my $mcclicmd = "/usr/local/avamar/bin/mccli";
my $hcfilename = "hc.xml";
my $vmtempfilename = "vmtemp.xml";
my $policyfilename = "policy.xml";
use vars qw( $hcdoc $vmtempdoc $policydoc $hcstat $vmtempstat $policystat $esxhost $hcstatcmd);

#print "HostOrCluster before if is $hostorcluster\n";
print "Gathering Host and Clusters view from Avamar server on vCenter ", $vcenter, "...\n";
if ($cache) { } else {
  our $hcstatcmd = "$mcclicmd vcenter browse --name=/$vcenter  --datacenter=\"$datacenter\" --vsphere-hosts-clusters-view=true  --recursive=true --xml=true";
  if ($hostorcluster eq "") {
#   print "HostOrCluseter is $hostorcluster\n";
  } else { 
    $hcstatcmd = "$hcstatcmd --esx-host=\"$hostorcluster\""; 
  } 
#  print "$hcstatcmd\n";
  our $hcstat = `$hcstatcmd`;
}
if ($? ne 0) {
  my $RC=$?;
  print "\n";
  print "ERROR: Failed to get Hosts and Clusters view from Aavamr.\n";
  print "ERROR: mccli exited with return code $RC\n";
  print "ERROR: mccli error message:\n";
  print $hcstat; 
  print "\n";
}

print "Gathering VM and Templates view from Avamar server on vCenter ", $vcenter, "...\n";
if ($cache) { } else {
  our $vmtempstat = `$mcclicmd vcenter browse --name=/$vcenter  --datacenter=\"$datacenter\"  --vsphere-hosts-clusters-view=false  --recursive=true --xml=true`;
}
if ($? ne 0) {
  my $RC=$?;
  print "\n";
  print "ERROR: Failed to get VM and Templates view from Aavamr.\n";
  print "ERROR: mccli exited with return code $RC\n";
  print "ERROR: mccli error message:\n";
  print $vmtempstat; 
  print "\n";
}

print "Gathering VMs that are already in policy ", $policy, "...\n";
if ($cache) { } else {
  our $policystat = `$mcclicmd group show-members --name=\"$policy\" --domain=\"$policydomain\" --xml=true`;
}
if ($? ne 0) {
  my $RC=$?;
  print "\n";
  print "ERROR: Failed to get Policy/Group members from Aavamr.\n";
  print "ERROR: mccli exited with return code $RC\n";
  print "ERROR: mccli error message:\n";
  print $policystat; 
  print "\n";
}

#print "Excludefile is $excludefile \n";
open(EXCLUDEFILE,"$excludefile") or die("ERROR: Could not open excludefile $excludefile.\n $!");
my @excludelist=<EXCLUDEFILE>; 

if ($genxmls) {
  print "Generating xml files and exiting\n";
  open my $hcfile , '>', "$hcfilename" or die("ERROR: Could not open hcfile $hcfilename.\n $!");
  print $hcfile $hcstat;
  close $hcfile;
  open my $vmtempfile , '>', "$vmtempfilename" or die("ERROR: Could not open vmtempfile $vmtempfilename.\n $!");
  print $vmtempfile $vmtempstat;
  close $vmtempfile;
  open my $policyfile , '>', "$policyfilename" or die("ERROR: Could not open hcfile $policyfilename.\n $!");
  print $policyfile $policystat;
  close $policyfile;
  exit;
}


my $hcparser = XML::LibXML->new();
my $vmtempparser = XML::LibXML->new();
my $policyparser = XML::LibXML->new();
if ($cache) {
  our $hcdoc = $hcparser->parse_file($hcfilename);
  our $vmtempdoc = $vmtempparser->parse_file($vmtempfilename);
  our $policydoc = $policyparser->parse_file($policyfilename);
} else {
  our $hcdoc = $hcparser->parse_string($hcstat);
  our $vmtempdoc = $vmtempparser->parse_string($vmtempstat);
  our $policydoc = $policyparser->parse_string($policystat);
}

CHECKEXCLUDE:
foreach my $vm ($hcdoc->findnodes('/CLIOutput/Data/Row')) {
  my($vmname) = $vm->findnodes('./Name')->to_literal;
#  print "Working on VM $vmname.\n";

# Decide if the VM has been excluded. Skip if it has.
  foreach my $vmtoexclude (@excludelist) {
    chomp $vmtoexclude;
#    print "Checking for $vmtoexclude against $vmname\n";
    if (grep /$vmtoexclude/, $vmname) {
      print "EXCLUDE: $vmname is on the exclude list. Skipping..\n";
      next CHECKEXCLUDE;
    }
  }

# Decide if the VM has been selected by name. Skip if it hasn't
  if ($vmnamequery ne "") {
#    print "vmnamequery has value.\n";
    if (grep (/$vmnamequery/,$vmname)) {
#      print "vmnamequery matches vmname.\n";
    } else {
      print "VM: $vmname not matched by --vmnamequery $vmnamequery skipping...\n";
      next;
    }
  }

# Figure out if the VM is already protected. Move to policy step if it is.
  my($vmprotected) = $vm->findnodes('./Protected')->to_literal;

# Decide if the VM matches the resoruce group
  my($location) = $vm->findnodes('./Location')->to_literal;
#  print "Location is $location\n";
  if ($location eq "null" && $resourcegroupquery ne "") {
    print "VM: $vmname is a template and cannot match --resourcegroup $resourcegroupquery. Skipping...\n";
    next;
  } elsif ($resourcegroupquery ne "") {
    my @locationfull = split (/\//, $location);
    my @vmresourcegroup = splice(@locationfull, -2, 1);
#  print "Resource group is @vmresourcegroup\n";
    if ($resourcegroupquery ne "" && @vmresourcegroup ne "Resources") {
#    print "resoeurcegroupqeury has value.\n";
      if (grep (/$resourcegroupquery/, @vmresourcegroup)) {
#      print "resourcegroupquery matches vmresourcegroup.\n";
      } else {
        print "VM: $vmname not matched by --resourcegroup $resourcegroupquery. Skipping...\n";
        next;
      }
    }
  }

# Decide if the VM matches the folder

  my $query  = "//Row[Name/text() = '$vmname']/Location/text()";
  my $folderraw = $vmtempdoc->findnodes($query);
#  print "Folderraw is $folderraw \n";
  my @folderfull = split (/\//, $folderraw);
#  print "Folderfull is @folderfull\n";
  my @folderpart = splice( @folderfull, 1 ,2 );
#  print "Folderpart is @folderpart\n";
#  print "Folderfull after splice is @folderfull\n"; 
  my @foldertrue = splice( @folderfull, -1);
#  print "Folderfull after 2nd splice is @folderfull\n"; 
#  print "Foldertrue is @foldertrue\n";
#  #my $folder = "/", join ( '/', @folderfull);
  my $folder = join ( '/', @folderfull);
  if ($folder eq "") { $folder = "/"; }
#  print "Folder is $folder\n";
  if ($folder eq "/" && $folderquery ne "") {
    print "VM: $vmname not matched by --folderquery $folderquery. Skipping...\n";
    next;
  }
  if ($folderquery ne "" && $recursive) {
#    print "folderquery has value and there is recursion\n";
    if (grep (/$folderquery/, $folder)) {
#      print "folderquery matches folder\n";
    } else { 
      print "VM: $vmname not matched by --folderquery $folderquery --recursive. Skipping...\n";
      next;
    }
  } elsif ($folderquery ne "") {
#    print "folderquery has value and there is no recursion\n"; 
    my @folderleaffull = split (/\//, $folder);
    my @folderleaf = splice( @folderleaffull, -1);
    if (grep /$folderquery/, @folderleaf) {
#      print "folder query matches folderleaf";
    } else { 
      print "VM: $vmname not matched by --folderquery $folderquery. Skipping...\n";
      next;
    }
  }

# Decide if VM is already protected or added to Avamar. If not add it to Avamar

#  print $vmprotected->to_literal, "\n";
  if ($vmprotected eq "Yes") {
    print "VM: ", $vmname->to_literal, " is already protected.\n";
  } elsif ($vmprotected->to_literal eq "No") {
    print "VM: ", $vmname->to_literal, " is not protected. Adding to avamar...\n";
#    system("$mcclicmd client add --type=vmachine --name=\"$vmname\" --domain=\"/$vcenter/VirtualMachines\" --datacenter=\"$datacenter\" --folder=\"$folder\" --changed-block-tracking=true --xml=true");
    my $mccliresult=`$mcclicmd client add --type=vmachine --name=\"$vmname\" --domain=\"/$vcenter/VirtualMachines\" --datacenter=\"$datacenter\" --folder=\"$folder\" --changed-block-tracking=true`;
    my $RC=$?;
    if ($RC ne 0) {
      print "\n";
      print "ERROR: Failed to add VM: $vmname.\n";
      print "ERROR: mccli exited with return code $RC\n";
      print "ERROR: mccli error message:\n";
      print $mccliresult; 
      print "\n";
    }
  } else {
    print "VM: ", $vmname->to_literal, " is questionable.\n";
  }

# Decide if VM is already in the policy/group. If not add it.
  my $vmfqdn = "/$vcenter/VirtualMachines/$vmname";
#  print "VMFQDN is $vmfqdn\n";
  my $querypolicy  = "//Row[Client/text() = '$vmfqdn']/ClientType/text()";
  my $policyprotected = $policydoc->findnodes($querypolicy)->to_literal;
#  print "Policyprotected $policyprotected \n";
  if ($policyprotected eq "") {
    print "POLICY: $vmname is not in policy $policy. Adding...\n";
    my $mccliresult = `$mcclicmd group add-client --client-name=\"$vmname\" --client-domain=\"/$vcenter/VirtualMachines\" --name=\"$policy\" --domain=\"$policydomain\"`;
    my $RC=$?;
    if ($RC ne 0) {
      print "\n";
      print "ERROR: Failed to add VM: $vmname to policy $policy.\n";
      print "ERROR: mccli exited with return code $RC\n";
      print "ERROR: mccli error message:\n";
      print $mccliresult;
      print "\n";
    } 
  } else {
    print "POLICY: $vmname is already in policy $policy.\n";
  }
}

print "End time: ";
system("date");
my $entime=time;
my $elapse = $entime - $sttime;
print "Elapsed time: ", $elapse, "s\n\n";
