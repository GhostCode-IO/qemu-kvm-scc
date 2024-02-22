#!/usr/bin/perl
#Location of PERL

#===================#
# About this Script #
#===================#
#This script is desinged to help control if specific VMs with related hardware are allowed to start given the status of another related VM.
#This script works off of defining family members (VMs) - of which only one is allowed to run at a time.
#This is designed to allow for shared hardware among VMs without causing corruption.
#The meachanim used to prevent a machine from starting is QM lock - in this case the clone lock.

#=======#
# Usage #
#=======#
#Make sure you have enabled the snippet content type within the applicable data store.
#You will need to set this script for each member VM with the qm command:
	# qm set <vmid> -hookscript <volume-id>:snippets/storage-collision-control.pl

#==================#
# Required Modules #
#==================#
use strict;
use warnings;

#=========================#
# Define Global Variables #
#=========================#
my ($VMID,$Phase)	=	@ARGV;		#Thank you Qemu/KVM/ProxMox for automatically adding these arguments...
my %Families	= (
	'Test'    =>	[101,102],
	'Gaming_UserA'	=>	[300,301],
	'Gaming_UserB'	=>	[400,401],
	'Gaming_Guest'	=>	[700,701]
);
my @Found_Families;
my @Family_Members;

#==============================#
# Primary Application Function #
#==============================#
VMID_Get_Families();
VMID_Get_Family_Members();
Check_Phase();

print ("Running for VMID:\t$VMID\n");
print ("Running for Phase:\t$Phase\n");
foreach (@Found_Families)
{
	print ("Discovered Family:\t$_\n");
}
print ("Family Members:\n");
foreach (@Family_Members)
{
	print ("\t$_\n");
}

QEMU_Actions();

exit(0);

#=======================#
# Operational Functions #
#=======================#
sub VMID_Get_Families
{
	@Found_Families	=	hash_search(\%Families,$VMID);
	VMID_Not_Family () if ($#Found_Families == -1);
}

sub VMID_Get_Family_Members
{
	foreach my $Family (keys %Families)
	{
		if (grep(/$Family/,@Found_Families))
		{
			push (@Family_Members,@{ $Families{$Family} });
		}
	}

	#Dedupe Array
	@Family_Members	=	dedupe_array(@Family_Members);

	#Remove active VMID from array
	my $VMID_Remove_Index	=	0;
	$VMID_Remove_Index++ until $Family_Members[$VMID_Remove_Index] == $VMID;
	splice(@Family_Members,$VMID_Remove_Index,1);
}

sub VMID_Not_Family
{
	print ("Virtual Machine Referenced by VMID is not a member of any configured family!\n");
	print ("\tExiting without configuration change.\n");
	exit();
}

sub Check_Phase
{
	unless ($Phase eq 'pre-start' or $Phase eq 'post-start' or $Phase eq 'pre-stop' or $Phase eq 'post-stop')
	{
		print ("Invalid Phase provided!\n");
		print ("\tExiting without configuration change.\n");
		exit();
	}
}

sub QEMU_Actions
{
	print ("\n\n");
	print ("+-------------------------------------+\n");
	print ("| QEMU/KVM/ProxMox Hookscript Actions |\n");
	print ("+-------------------------------------+\n");
	#VM Pre-Start Phase:
	if ($Phase eq 'pre-start')
	{
		print (" > Executing Pre-Start Routine for VM $VMID\n");
		#Do everything we need to do prior to starting the VM.
		foreach (@Family_Members)
		{
			print ("   + Locking VM $_ - For Storage Collision Prevention");
			print (" (qm set $_ --lock clone)\n");
			#system("qm set $_ --lock clone\n");
			
		}
		print (" > Starting VM:\t $VMID\n");
	}
	#VM Post-Start Phase:
	elsif ($Phase eq 'post-start')
	{
		print (" > VM $VMID Started\n");
		print (" > Executing Post-Start Routine for VM $VMID\n");
		#Do everything we need to do after starting the VM.
		
	}
	#VM Pre-Stop Phase:
	elsif ($Phase eq 'pre-stop')
	{
		print (" > Executing Pre-Stop Routine for VM $VMID\n");
		#Do everything we need to do prior to stopping the VM.
		
		print (" > Stopping VM:\t $VMID\n");
	}
	#VM Post-Stop Phase:
	elsif ($Phase eq 'post-stop')
	{
		print (" > VM $VMID Stopped\n");
		print (" > Executing Post-Stop Routine for VM $VMID\n");
		#Do everything we need to do after starting the VM.
		foreach (@Family_Members)
		{
			print ("   + Unlocking VM $_ - For Storage Collision Prevention");
			print (" (qm unlock $_)\n");
			#system("qm unlock $_\n");
			
		}
		print (" > Starting VM:\t $VMID\n");
	}
}


#========================#
# Suplementary Functions #
#========================#
sub hash_search
{
	my ($hash,$query)	=	@_;
	my @results;
	for my $key (keys %$hash)
	{
		if (ref $hash->{$key} eq 'ARRAY')
		{
			for (@{$hash->{$key}})
			{
				push (@results, $key) if /^$query$/i;
			}
		}
		else
		{
			push (@results, $key) if $hash->{$key} == $query;
		}
	}
	return @results;
}

sub dedupe_array
{
	my %seen;
	grep !$seen{$_}++, @_;
}
