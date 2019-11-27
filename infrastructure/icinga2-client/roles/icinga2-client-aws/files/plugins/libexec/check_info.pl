#!/usr/bin/perl
# nagios info check by perrth
# adapted on 19.09.2017
use Digest::MD5 qw(md5_hex);;
use Getopt::Long;
use lib '/appl/icinga/plugins/libexec/';
use FNO;

Getopt::Long::Configure('bundling');
        GetOptions(
                "h|help"                   => \$opt_h,
                "t|ticinga=s"          => \$tnagios,
                "m|MsgG=s" => \$MsgG,
                "n|ntptimeout=s"              => \$ntptimeout);

if ($opt_h){
        &print_usage();
        exit 0
}

&check_param($tnagios, $MsgG, $ntptimeout);

$Uptime_bin="/usr/bin/uptime";

my $tnow = time();

$time_thresh=300;
$tdiff=abs($tnagios-$tnow);

my $hostname=`hostname`;
chomp $hostname;

#for solaris zones not ntp command available check
if ($hostname=~/avs/) {
  if ( $tdiff > $time_thresh ) {
         #push (@nagios_output,"Warning - Time difference $tdiff seconds is to high! (threshold $time_thresh seconds) MsgG=$MsgG <!-- Obj=time App=System MsgG=$MsgG Type=NAA Sev=Warning -->\n");
	 FNO::add({   Summary => "Time difference $tdiff seconds is to high! (threshold $time_thresh seconds)",
                Severity => "Warning",
                AlertGroup => "System",
                AlertKey => "time",
                MsgGroup => "$MsgG",
         });
  } else {
      #push (@nagios_output,"OK - Time difference $tdiff seconds is okay! (threshold $time_thresh seconds) MsgG=$MsgG<!-- Obj=time App=System MsgG=$MsgG Sev=Normal -->\n");
	  FNO::add({   Summary => "Time difference $tdiff seconds is okay! (threshold $time_thresh seconds)",
                Severity => "Normal",
                AlertGroup => "System",
                AlertKey => "time",
                MsgGroup => "$MsgG",
         });
  }
  
} else {
  &checkNtpTime;
}
$uptime=`$Uptime_bin`;
#1:17pm  up 71 days 21:09,  1 user,  load average: 0.00, 0.04, 0.01
if ( $uptime=~/(\d+) day.?.?.?,\s+(\d+) min.../ ) {
	$day=$1; $hour=0; $min=$2; 
}
elsif ( $uptime=~/(\d+) day.?.?.?,\s+(\d+) hr.../ ) {
        $day=$1; $hour=$2; $min=0; }
elsif ( $uptime=~/(\d+) day.?.?.?,\s+(\d+):(\d+)/ ) {
	$day=$1; $hour=$2; $min=$3; }
elsif ( $uptime=~/up\s+(\d+):(\d+)/ ) {
        $day=0; $hour=$1; $min=$2; }
elsif ( $uptime=~/up\s+(\d+) min/ ) {
        $day=0; $hour=0; $min=$1;}
elsif ( $uptime=~/up\s+(\d+)\s+day.?\s+(\d+):(\d+)/ ) {
        $day=$1; $hour=$2; $min=$3; }
elsif ( $uptime!~/up/ ) {
        $day=99999;
} else { #push (@nagios_output,"Warning - Can not parse uptime! MsgG=OSS <!-- Obj=nagios App=NAGIOS MsgG=OSS Sev=Warning Type=NAA -->\n"); 
	 FNO::add({   Summary => "Can not parse uptime in $0!",
                Severity => "Warning",
                AlertGroup => "Nagios",
                AlertKey => "parsing error",
                MsgGroup => "$MsgG",
		Type => "NAA"
         });
	}

$min_uptime=($day*24*60)+($hour*60)+$min;

if ($min_uptime < 30 ) {
	#push (@nagios_output,"Info - System has been restarted $min_uptime minutes ago! MsgG=$MsgG <!-- Obj=uptime App=System MsgG=$MsgG Type=NAA Sev=Info -->\n");
	FNO::add({   Summary => "System has been restarted $min_uptime minutes ago!",
                Severity => "WARNING",
                AlertGroup => "System",
                AlertKey => "uptime",
                MsgGroup => "$MsgG",
                Type => "NAA"
         });
} else {
	#push (@nagios_output,"OK - System is up since $day day(s) $hour hour(s) $min minute(s) MsgG=$MsgG\n");	
	FNO::addText("OK - System is up since $day day(s) $hour hour(s) $min minute(s)");
}

my $returnCode = &FNO::print();
exit $returnCode;

sub checkNtpTime {
    # remote           refid      st t when poll reach   delay   offset  jitter
#==============================================================================
#*av2l073p.it.int 131.130.250.250  2 u  422 1024  377    2.259    0.694   0.427
#+avel074p.it.int 193.171.23.164   2 u   15 1024  377    3.040    0.158   0.869

if ( -x "/usr/bin/chronyc" ) {
	@output=`/usr/bin/chronyc sources`;
} else {
	@output=`/usr/bin/chronyc sources`;
}
$host_count=0;

$exitcode=$?;
if ( $exitcode==0) {
#push (@nagios_output,"Ok - chronyd  daemon is installed. Command 'chronyc'  executeable  MsgG=$MsgG <!-- Obj=time App=ntp_server MsgG=$MsgG Sev=Normal -->\n");
FNO::add({   Summary => "chronyd daemon is installed. Command 'chronyc'  executeable.",
                Severity => "normal",
                AlertGroup => "System",
                AlertKey => "/usr/sbin/chronyc",
                MsgGroup => "$MsgG"
         });
        foreach $line (@output) {
                chomp $line;
                next if $line=~/^210/;
                next if $line=~/MS/;
                next if $line=~/^===/;

                ($prefix,$host,$refid,$st,$t,$when,$poll,$reach,$deliay,$offset,$jitter) =
                                split(" ", $line, 11);
                if ($line =~ /\[(.*)\]/)
                {
                        $offset = $1;
                }
                $offset = &get_valid_offset($offset);
                if ($prefix=~/^\*|\+|\*|\-|\?|\~/ ) {
			my ($ntpInfo,$ntpWarning,$ntpCritical) = split (/,/, $ntptimeout);
			if ($offset <= -$ntpCritical | $offset >= $ntpCritical ) {
				#push (@nagios_output,"Critical - Offset \'$offset\'ms on chronyd server \'$host\' is not okay MsgG=$MsgG <!-- Obj=ntp_${host_count}  App=System MsgG=$MsgG Sev=Critical -->\n");
				FNO::add({   Summary => "Offset \'$offset\'ms on chronyd server \'$host\' is not okay. (Threshold i:$ntpInfo, w:$ntpWarning, c:$ntpCritical)",
                			Severity => "critical",
                			AlertGroup => "System",
                			AlertKey => "ntp_${host_count}",
					Delay => 10800,
                			MsgGroup => "$MsgG"
         			});
			} elsif ( $offset <= -$ntpWarning | $offset >= $ntpWarning ) {
				#push (@nagios_output,"Warning - Offset \'$offset\'ms on chronyd server \'$host\' is not okay MsgG=$MsgG <!-- Obj=ntp_${host_count}  App=System MsgG=$MsgG Sev=Warning -->\n");
				FNO::add({   Summary => "Offset \'$offset\'ms on chronyd server \'$host\' is not okay. (Threshold i:$ntpInfo, w:$ntpWarning, c:$ntpCritical)",
                                        Severity => "warning",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_${host_count}",
					Delay => 10800,
                                        MsgGroup => "$MsgG"
                                });
			} elsif ( $offset <= -$ntpInfo | $offset >= $ntpInfo ) {
				#push (@nagios_output,"Warning - Offset \'$offset\'ms on chronyd server \'$host\' is not okay MsgG=$MsgG <!-- Obj=ntp_${host_count}  App=System MsgG=$MsgG Sev=Warning -->\n");
				FNO::add({   Summary => "Offset \'$offset\'ms on chronyd server \'$host\' is not okay. (Threshold i:$ntpInfo, w:$ntpWarning, c:$ntpCritical)",
                                        Severity => "Minor",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_${host_count}",
					Delay => 10800,
                                        MsgGroup => "$MsgG"
                                });
			} else {
				#push (@nagios_output,"Ok - Offset \'$offset\'ms on chronyd server \'$host\' is okay MsgG=$MsgG <!-- Obj=ntp_${host_count}  App=System MsgG=$MsgG Sev=Normal -->\n");
				FNO::add({   Summary => "Offset \'$offset\'ms on chronyd server \'$host\' is okay.",
                                        Severity => "normal",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_${host_count}",
                                        MsgGroup => "$MsgG"
                                });
			}
			$server.=" " .$host;
			$host_count++;
		}
	}
	#09.02.2016-oleinial ONLY ONE chronyd Server in sync available for ALU NMS *96s.utran.internal and *96m.utran.internal hosts.
	if (($hostname=~/96s/) || ($hostname=~/96m/) || ($hostname=~/SR5S/)) {
		if ($host_count>=1) {
			#push (@nagios_output,"Ok - There are $host_count chronyd server in sync:\'$server\'  MsgG=$MsgG <!-- Obj=ntp_server  App=System MsgG=$MsgG Sev=Normal -->\n");
			FNO::add({   Summary => "There are $host_count chronyd server in sync:\'$server\'",
                                        Severity => "normal",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server",
                                        MsgGroup => "$MsgG"
                       });
		} else {
			#push (@nagios_output,"Critical - There no chronyd server in sync!  MsgG=$MsgG <!-- Obj=ntp_server  App=System MsgG=$MsgG Sev=Critical -->\n");
			FNO::add({   Summary => "There no chronyd server in sync!",
                                        Severity => "critical",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server",
					Delay => 10800,
                                        MsgGroup => "$MsgG"
                       });
		}
	}
	#ALL OTHER HOSTS
	elsif ( $host_count>=2) {
		#push (@nagios_output,"Ok - There are $host_count chronyd server in sync:\'$server\'  MsgG=$MsgG <!-- Obj=ntp_server  App=System MsgG=$MsgG Sev=Normal -->\n");
		FNO::add({   Summary => "There are $host_count chronyd server in sync:\'$server\'",
                                        Severity => "normal",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server<*>",
                                        MsgGroup => "$MsgG"
                });
	} elsif ( $host_count==1) {
		#push (@nagios_output,"Warning - There is only one chronyd server in sync:\'$server\'  MsgG=$MsgG <!-- Obj=ntp_server  App=System MsgG=$MsgG Sev=Warning -->\n");
                FNO::add({   Summary => "At least one chronyd server in sync:\'$server\'",
                                        Severity => "normal",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server_all",
                                        MsgGroup => "$MsgG"
                });

		FNO::add({   Summary => "There is only one chronyd server in sync:\'$server\'",
                                        Severity => "warning",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server",
					Delay => 10800,
                                        MsgGroup => "$MsgG"
                });
	} else {
		#push (@nagios_output,"Critical - There no chronyd server in sync!  MsgG=$MsgG <!-- Obj=ntp_server  App=System MsgG=$MsgG Sev=Critical -->\n");
		FNO::add({   Summary => "There no chronyd server in sync!",
                                        Severity => "critical",
                                        AlertGroup => "System",
                                        AlertKey => "ntp_server_all",
					Delay => 10800,
                                        MsgGroup => "$MsgG"
                });
	}

} else {
	#push (@nagios_output,"Warning - Check if chronyd daemon is installed. Command 'ntpq -p' not executeable  MsgG=$MsgG <!-- Obj=time App=System MsgG=$MsgG Type=NAA Sev=Warning -->\n");
	FNO::add({   Summary => "Check if chronyd daemon is installed. Command 'chronyc' not executeable",
                                        Severity => "warning",
                                        AlertGroup => "System",
                                        AlertKey => "/usr/bin/chronyc",
                                        MsgGroup => "$MsgG"
       });

}

}

sub print_usage () {
        print "Usage:\n";
        print "  $0 -t <MACRO_\$TIMET\$> -m <default MsgGroup> [OPTIONAL] -n <ntp timeout thresholds> \n";
        print "\nOptions:\n";
        print "  -h, --help\n";
        print "     Print detailed help screen\n";
        print "  -t, --ticinga\n";
        print "     unix timestamp of icinga server\n";
        print "  -m, --MsgG\n";
        print "     Default MsgGroup if script has errors etc.\n";
        print "  -n, --ntptimeout\n";
        print "     [OPTIONAL] Minor, Major and Critical thresholds for chronyd (default 200,300,1000) \n";
}

sub check_param {
$tnagios=shift; $MsgG=shift; $ntpt=shift;

     if (! $tnagios) {
        FNO::add({ Summary => "No icinga timestamp has been passed",
                   Severity => "Major",
                   AlertGroup => "NAGIOS",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
     }

     if (! $MsgG) {
        FNO::add({ Summary => "No default message group has been defined",
                   Severity => "Major",
                   AlertGroup => "NAGIOS",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
     }

     if (!$ntpt) {
           $ntptimeout = "200,300,1000"
     }
}

sub get_valid_offset {
  my $entry = shift;
  my $unit;
  my $factor = 1;
  if ($entry =~ /ns/) {
    $unit = 'us';
    $factor = 0.000001;
  } elsif ($entry =~ /us/) {
    $unit = 'us';
    $factor = 0.001;
  } elsif ($entry =~ /ms/)  {
    $unit = 'us';
    $factor = 1;
  } else  {
    $unit = 's';
    $factor = 1000;
  }
  $entry =~ s/($unit)//;
  return int($entry) * $factor;

}

