#!/usr/bin/perl
#
# check_interfaces.pl by tperr
#
use Digest::MD5 qw(md5_hex);;
use Sys::Hostname;
use Config::IniFiles;
use lib '/appl/icinga/plugins/libexec/';
use FNO;

my $host = hostname();
my $debug=0; my $counter=0; my $ecode2=0;
my $netstattmpfile="/appl/home/icinga/netstat.txt";

$TIMEOUT=120;
alarm($TIMEOUT);
$SIG{'ALRM'} = sub {
        #print "Info - Nagios plugin timed out after $TIMEOUT sec\n";
        #print "Info - Plugin check_interface.pl timed out after $TIMEOUT sec MsgG=OSS <!-- App=NAGIOS Obj=timeout MsgG=OSS Sev=Info Type=NAA -->\n";
	FNO::add({   Summary => "Plugin $0 timedout after $TIMEOUT sec",
                Severity => "Warning",
                AlertGroup => "NAGIOS",
                AlertKey => "timeout",
                MsgGroup => "OSS",
                Type => "NAA"
        });
        exit 4;
};


if ( $ARGV[0]=~m/\.cfg/ ) {
       $cfg_file=shift @ARGV;
       $cfg_file="/appl/icinga/plugins/etc/" . $cfg_file;
        }
else { print "Wrong Argument\n" ;
        print "Example: check_interface.pl <config_file.cfg>\n" ;
        exit 3;
        }
#16.6.2016 aignerma: Use this argument to exclude TX or/and DX dropped packages by using for example the following argument2: exlcudeTX_DRP,exlcude_RX_DRP
my $exclude_option = $ARGV[0];

if ( ! -r  "$cfg_file" ) {
        #print "No $cfg_file found\n";
        #print "Warning - No $cfg_file file found MsgG=OSS <!-- Obj=interfaces App=NAGIOS MsgG=OSS Sev=Info Type=NAA -->\n";
	FNO::add({   Summary => "No $cfg_file file found MsgG=OSS",
                Severity => "Warning",
                AlertGroup => "NAGIOS",
                AlertKey => "interfaces",
                MsgGroup => "OSS",
                Type => "NAA"
        });
        exit 1;
        }

my $cfg = new Config::IniFiles( -file => "$cfg_file", -nocase => 1 );
my @sect=$cfg->Sections;

# Reading Config File
foreach $section (@sect) {
 push(@cfg_int,$cfg->val( "$section", 'interface','novalue' ));
 push(@MsgG,$cfg->val( "$section", 'MsgG','OSS' ));
 push(@severity,$cfg->val( "$section", 'Sev','not_defined' ));
 push(@App,$cfg->val( "$section", 'App','not_defined' ));
if ( $debug == 1 ) {
print "---------------------------------------------\n";
print "Reading data from ini file ($section)\n";
print "Interface: ".$cfg->val( "$section", 'interface','novalue' )."\n";
print "MsgG: ".$cfg->val( "$section", 'MsgG','OSS' )."\n";
print "Severity: ".$cfg->val( "$section", 'Sev','not_defined' )."\n";
print "---------------------------------------------\n";
}
}

# determine which OS version
my $osname =`uname -a | cut -d " " -f 1`; chomp $osname;
# Only root can execute this script

# $user=`/usr/bin/id | /usr/bin/cut -c1-5`; chomp $user;
# if ( $user ne 'uid=0' ) { print "UNKNOWN - You must be root to execute this script!\n"; exit 3 ; }

if ( $osname eq 'SunOS' ) {
	&ifconfig_solaris;
	}
elsif ( $osname eq 'Linux' ) {
	&ifconfig_linux;
	}
elsif ( $osname eq 'HP-UX' ) {
	&ifconfig_hp;
	}

%status = @interface;

foreach $interface (@cfg_int){
	if ( exists $status{$interface} ) {
		if ( $status{$interface} eq "UP" ) { 
			#push(@OK,"OK - Interface $interface $status{$interface} - MsgG=$MsgG[$counter] <!-- App=\'$App[$counter]\' Obj=$interface MsgG=$MsgG[$counter] Sev=Normal -->\n");
			FNO::add({   Summary => "Interface $interface $status{$interface} - MsgG=$MsgG[$counter]", Severity => "normal", AlertGroup => $App[$counter], AlertKey => $interface, MsgGroup => $MsgG[$counter] });
			$ecode=0;
			if ( $ecode > $ecode2 ) { $ecode2=$ecode; }
		}
		if ( $status{$interface} ne "UP"  &&  $severity[$counter] eq 'warning' ) {
			#push(@WARNING,"Warning - Interface $interface $status{$interface} $speed[$counter] $duplex[$counter] - MsgG=$MsgG[$counter] <!-- App=\'$App[$counter]\' Obj=$interface MsgG=$MsgG[$counter]  Sev=Warning-->\n");
			FNO::add({   Summary => "Interface $interface $status{$interface} $speed[$counter] $duplex[$counter] - MsgG=$MsgG[$counter]",
                        	Severity => "warning",
                        	AlertGroup => $App[$counter],
                        	AlertKey => $interface,
                        	MsgGroup => $MsgG[$counter]
                	});
			$ecode=1;
			if ( $ecode > $ecode2 ) { $ecode2=$ecode; }
		}
		if ( $status{$interface} ne "UP"  &&  $severity[$counter] eq 'critical' ) {
			#push(@CRITICAL,"CRITICAL - Interface $interface $status{$interface} $speed[$counter] $duplex[$counter] - MsgG=$MsgG[$counter] <!-- App=\'$App[$counter]\' Obj=$interface MsgG=$MsgG[$counter] Sev=Critical -->\n");
			FNO::add({   Summary => "Interface $interface $status{$interface} $speed[$counter] $duplex[$counter] - MsgG=$MsgG[$counter]",
                        	Severity => "critical",
                        	AlertGroup => $App[$counter],
                        	AlertKey => $interface,
                        	MsgGroup => $MsgG[$counter]
                	});
			$ecode=2;
			if ( $ecode > $ecode2 ) { $ecode2=$ecode; }
		}
		#counter to Get MsgG and Severity from @MSgG and @severity array
		$counter=++$counter;
	} else {
		#push(@WARNING,"Warning Interface $interface does not exists on $host\n");	
		FNO::add({   Summary => "Warning Interface $interface does not exists on $host", 
			Severity => warning, 
			AlertGroup => "Interface_not_exits", 
			AlertKey => $interface, 
			MsgGroup => "OSS", 
			Type => "NAA" 
		});
	}
}
my $returnCode = &FNO::print();
exit $returnCode;
# Count how many interfaces have been checked
$checked_all=$#cfg_int+1; 
$checked_ok=$#OK+1;
$checked_warn=$#WARNING+1;
$checked_crit=$#CRITICAL+1;
push(@nagios_output,@OK,@WARNING,@CRITICAL,@UNKOWN);
$hex_digest= md5_hex(@nagios_output);


print "Checked $checked_all interfaces - $checked_crit Critical, $checked_warn Warning, $checked_ok OK <!-- $hex_digest -->\n";  	
print @OK; print @WARNING; print @CRITICAL; print @UNKOWN;
exit $ecode2;



sub ifconfig_solaris {
# Getting IP, Status, and Interface Name from ifconfig command

$ENV{'PATH'}="$ENV{'PATH'}" .":/sbin:/usr/sbin";
foreach $interface ( @cfg_int ) {
	if ($interface=~/^bge/) {
       		### Fetch status
       		chomp($status  = `ndd /dev/$interface link_status 2> /dev/null`);
		if ( $status == 1 ) { $status='UP' ; } else { $status='DOWN';}	
       		#chomp($speed  = `ndd /dev/$interface link_speed 2> /dev/null`);

       		### Process status
       		#unless ($speed =~ /^(10|100|1000)$/) { $speed = "ERR"; }
   	}
	else {
		my ($dev, $ins) = $interface =~ /(.*)(.)/;
		chomp($status = `kstat -p -c net -m $dev -i $ins -s link_up`);  
		if ( $status =~ /1$/ ) { $status='UP' ; } else { $status='DOWN';}	
	}
       	push(@interface,$interface,$status);
        #push(@speed,"$speed Mb/s");
}
sub ifconfig_hp {
foreach $interface ( @cfg_int ) {
        $int_type=$1; 
	$instance=`/usr/sbin/lanscan -p -i | grep "^$interface " | awk '{ print \$NF}'`;
        @get_int=`/usr/sbin/lanadmin -g mibstats $instance`;
                foreach $get_int (@get_int) {
                        if ( $get_int=~/Operation.*=\s+(\w+)/ ) {
                        $status=$1 ;
                                if ( $status eq 'up' ) { $status='UP' ; } else { $status='DOWN';}
				push(@interface,$interface,$status);
                        }
                        if ( $get_int =~/^Speed.*=\s+(\d+)/ ) {
                        $speed=$1;
                        $speed=$speed / 1000000 ."Mb/s";
			push(@speed,$speed);
                        }
        }

   if ( $debug == 1 ) {
        print "---------------------------------------------\n";
        print "Getting Data from lanadmin tool\n";
        print "Interface: $int_type$instance\n";
        print "Speed: $speed\n";
        print "Link detected: $status\n";
        print "---------------------------------------------\n";
        }
}
}
}
sub ifconfig_linux {
# Getting Status from ethtool 
$ENV{'PATH'}="$ENV{'PATH'}" .":/sbin:/usr/sbin";
@netstat=`netstat -i`;
%OLDNETSTAT=();
if ( -r $netstattmpfile ) {
	if ( -M $netstattmpfile > 1 ) {
	 #push(@WARNING, "Warning - Temporary netstat file ($netstattmpfile) has not been updated within 24 hours. MsgG=OSS <!-- App=System Obj=check_interfaces.pl MsgG=OSS Type=NAA Sev=Warning-->\n"); 
	FNO::add({   Summary => "Temporary netstat file ($netstattmpfile) has not been updated within 24 hours.", 
                        Severity => "warning",
                        AlertGroup => "System",
                        AlertKey => "check_interfaces.pl",
                        MsgGroup => "OSS",
                        Type => "NAA"
        });
}

	@lastnetstat = `cat $netstattmpfile`;
	foreach $line (@lastnetstat) {
		@items=split ( /\s+/, $line );
		$NETSTAT{$items[0]} = {
			'RX_DRP' => "$items[5]",
			'TX_DRP' => "$items[9]",
		 };
	}
}
foreach $interface ( @cfg_int ) {
@get_int=`sudo ethtool $interface`; 
	foreach $get_int (@get_int) {
	if  ( $get_int=~/Speed:\s+(.*)/ ){
		$speed=$1;
		push(@speed,$speed);
		}
	if  ( $get_int =~/Duplex:\s+(.*)/ ) {
                $duplex=$1;
                push(@duplex,$duplex);
                }
        if  ( $get_int =~/Link detected:\s+(.*)/ ) {
		$status=$1;
			if ( $status eq 'yes' ) { $status='UP' ; } else { $status='DOWN';}
                push(@interface,$interface,$status);
	if ( $debug == 1 ) {
		print "---------------------------------------------\n";
		print "Getting Data from ethtool\n";
		print "Command: ethtool $interface\n";
		print "Speed: $speed $duplex\n";
		print "Link detected: $status\n";
		print "---------------------------------------------\n";
		}
                }
}
foreach $line (@netstat) {
	@items=split ( /\s+/, $line );
	if ( $items[0] eq $interface ) {
		if ( $exclude_option=~/exclude_RX_DRP/ ) {
		} else {
			$diff=$items[5] - $NETSTAT{$interface}{'RX_DRP'};
			if ( $diff > 0 ) {
				push(@WARNING,"Warning - Interface $interface has dropped packages! RX_DRP has increased by $diff since the last polling. Used command 'netstat -i' MsgG=$MsgG[$counter] <!-- App=System Obj=${interface}_RX-DRP MsgG=$MsgG[$counter] Type=NAA Sev=Warning-->\n");
				$ecode=1;
				FNO::add({   Summary => "Interface $interface has dropped packages! RX_DRP has increased by $diff since the last polling. Used command 'netstat -i'",
                        		Severity => "warning",
                        		AlertGroup => "System",
                        		AlertKey => "${interface}_RX-DRP",
                        		MsgGroup => "$MsgG[$counter]",
                        		Type => "NAA"
        				});
				if ( $ecode > $ecode2 ) { $ecode2=$ecode; }
			}
		}
		if ( $exclude_option=~/exclude_TX_DRP/ ) {
		} else {
			$diff=$items[9]-$NETSTAT{$interface}{'TX_DRP'};
			if (( $diff > 0 ) && (! $exclude_option=~/exclude_TX_DRP/ ) ) {
				push(@WARNING,"Warning - Interface $interface has dropped packages! TX_DRP has increased by $diff since the last polling. Used command 'netstat -i' MsgG=$MsgG[$counter] <!-- App=System Obj=${interface}_TX-DRP MsgG=$MsgG[$counter] Type=NAA Sev=Warning-->\n");
				$ecode=1;
				FNO::add({   Summary => "Warning - Interface $interface has dropped packages! TX_DRP has increased by $diff since the last polling. Used command 'netstat -i'",
                                        Severity => "warning",
                                        AlertGroup => "System",
                                        AlertKey => "${interface}_TX-DRP",
                                        MsgGroup => "$MsgG[$counter]",
                                        Type => "NAA"
                                });
				if ( $ecode > $ecode2 ) { $ecode2=$ecode; }
			}
		}
	}
}
}
open (NETSTATFILE, ">$netstattmpfile") or die "unable to open $netstattmpfile $!";
print NETSTATFILE @netstat;
close (NETSTATFILE);
}


