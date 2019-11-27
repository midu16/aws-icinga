#!/usr/bin/perl 
# created by Thomas Perr
# validation check added by Mariella Majewsky
use Getopt::Long;
use Config::IniFiles;
use lib '/appl/icinga/plugins/libexec/';
use FNO;

###########################################################################################################################################################################
# execution example:
###########################################################################################################################################################################
# ./check_filesystem -f BASE_filesystems.cfg -m OPS-Unix -t 150
# -h for help
# -f <value> for config file
# -m <value> for default message group -> script errors
# -t <value> for timeout of the script

###########################################################################################################################################################################
# variables
###########################################################################################################################################################################
  my @df_output; 
  my $line;
# variable for debugging
  my $debug=0;
# variables for config sections
  my $section; 
  my @cfg_disk; 
  my @MsgG; 
  my @Instr; 
  my @info; 
  my @warning; 
  my @critical; 
# variables for performance data
  my $capacity; 
  my $used; 
  my $free; 
  my $usage;
  my $disk;
  my $perfout="| "; 

###########################################################################################################################################################################
# evaluate options
###########################################################################################################################################################################
Getopt::Long::Configure('bundling');
	GetOptions(
        	"h|help"                   => \$opt_h,
        	"f|config_file=s"          => \$opt_f,
        	"m|default_messagegroup=s" => \$opt_m,
        	"t|timeout=i"              => \$opt_t);

if ($opt_h){
	&print_usage();
}

if (! $opt_m) {
	FNO::add({ Summary => "No default message group has been defined",
		   Severity => "Warning",
                   AlertGroup => "NAGIOS",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
	});
        my $returnCode = &FNO::print();
        exit $returnCode;
}

if ( $opt_f=~m/\.cfg/ ) {
       $cfg_file="/appl/icinga/plugins/etc/" . $opt_f;
} else {
        FNO::add({ Summary => "Wrong config file option for plugin $0 <config_file.cfg>",
                   Severity => "Warning",
                   AlertGroup => "NAGIOS",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
}

if ( ! -r  "$cfg_file" ) {
        FNO::add({ Summary => "No $cfg_file file found",
                   Severity => "Warning",
                   AlertGroup => "NAGIOS",
                   AlertKey => "cfg_file",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
}

if ($opt_t) {
	if ($opt_t >= 300){
		FNO::add({ Summary => "Timeout is set to $opt_t seconds, but needs to be lower 300 seconds",
			   Severity => "Warning",
                   	   AlertGroup => "NAGIOS",
                   	   AlertKey => "service_config",
                   	   MsgGroup => "OSS",
                   	   Type => "NAA"
		});
        my $returnCode = &FNO::print();
        exit $returnCode;
	} else {
		$TIMEOUT=$opt_t;
	}
} else {
	$TIMEOUT=120;
}

alarm($TIMEOUT);
$SIG{'ALRM'} = sub {
        FNO::add({ Summary => "Plugin $0 timedout after $TIMEOUT seconds",
                   Severity => "Info",
                   AlertGroup => "NAGIOS",
                   AlertKey => "timeout",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
};

###########################################################################################################################################################################
# main part
###########################################################################################################################################################################

# get exclude list from h3g_FS_exclude.cfg
my $h3g_FS_exclude="/appl/icinga/plugins/etc/h3g_FS_exclude.cfg";

# check OS version and define df command;
my $osname =`uname -a | cut -d " " -f 1`;
chomp $osname;

if ( $osname eq 'SunOS' ) {
	# Solaris grep
	$GREP="| /usr/xpg4/bin/grep -v -f $h3g_FS_exclude | grep -v '^Filesystem'";
        $DF = "df -k -F vxfs $GREP; df -k -F samfs $GREP; df -k -F zfs $GREP; df -k -F ufs $GREP; df -k /tmp | /usr/xpg4/bin/grep /tmp $GREP ; df -k /var/run | /usr/xpg4/bin/grep /var/run $GREP"; 

} elsif ( $osname eq 'Linux' ) {
        @dmesg=process_command("dmesg");
	$pattern_dmesg=0;		
	foreach $line (@dmesg) {
		if ($line=~/Remounting filesystem read-only/) {
			$pattern_dmesg=1;
		}
	}
	if ($pattern_dmesg) {
		FNO::add({ Summary => "found pattern 'Remounting filesystem read-only' in dmesg output",
        		   Severity => "Critical",
        		   AlertGroup => "System",
        		   AlertKey => "dmesg",
        		   MsgGroup => $opt_m 
		});
	} else {
		FNO::add({ Summary => "Pattern 'Remounting filesystem read-only' not found in dmesg output",
        		   Severity => "Normal",
        		   AlertGroup => "System",
        		   AlertKey => "dmesg",
        		   MsgGroup => $opt_m
		});
	}
	$GREP="| grep -v -f $h3g_FS_exclude | grep -v '^Filesystem'";
        $DF = "df -k -P -t xfs $GREP; df -k -P -t tmpfs $GREP;";
                           
} elsif ( $osname eq 'HP-UX' ) {
	$GREP="| grep -v -f $h3g_FS_exclude | grep -v '^Filesystem'";
	$DF= "bdf | awk '{ if(NF>5) {print} if(NF==1) {k1=\$1} if(NF==5) {print k1, \$0 } } '$GREP";
				   
} elsif ( $osname eq 'AIX' ) {
	$GREP="| grep -v -f $h3g_FS_exclude | grep -v '^Filesystem' | grep -v '^/proc' | awk '{ print \$1\" \"\$2\" \"\$2-\$3\" \"\$3\" \"\$4\" \"\$7}'";
        $DF = "df -k $GREP";
				   
}

@df_output=`$DF`;
if ( $debug == 1 ) {
        print @df_output;
}

# getting data from config file
my $cfg = new Config::IniFiles( -file => "$cfg_file", -nocase => 1);
my @sect=$cfg->Sections;
foreach $section (@sect) {
         push(@cfg_disk,$cfg->val( "$section", 'filesystem','novalue' ));
         push(@MsgG,$cfg->val( "$section", 'MsgG', $opt_m ));
         push(@Instr,$cfg->val( "$section", 'Instruction','not_defined' ));
         push(@App,$cfg->val( "$section", 'App','not_defined' ));
         push(@info,$cfg->val( "$section", 'Info','not_defined' ));
         push(@warning,$cfg->val( "$section", 'Warning','not_defined' ));
         push(@critical,$cfg->val( "$section", 'Critical','not_defined' ));

         #subroutine will check the logic of the thresholds and if at least one threshold is defined
         &validation_check($cfg->val( "$section", 'Info','not_defined' ),$cfg->val( "$section", 'Warning','not_defined' ),$cfg->val( "$section", 'Critical','not_defined' ),$section);
}

foreach $line (@df_output) {
	next if ( $line=~/^Filesystem/i );
	next if ( $line=~/.*?\s+(-)\s+(-)\s+(-)\s+(-).*/ );
		if ( $line  =~/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+/ ) {
			$capacity=$1; $used=$2; $free=$3; $usage=$4; $disk=$'; chomp $disk;
			push(@CAPACITY,$capacity);push(@USED,$used);push(@FREE,$free);push(@USAGE,$usage); push(@DISK,$disk);
			if ( $debug == 1 ) {
				print "Capacity: $capacity kB\n"; print "Used: $used kB\n"; print "Free: $free kB\n"; print "Usage: $usage %\n"; print "Disk: $disk \n";
			}
		} else {
                        FNO::add({ Summary => "DF command cannot be parsed.",
                                   Severity => "Warning",
                                   AlertGroup => "NAGIOS",
                                   AlertKey => "command_error",
                                   MsgGroup => "OSS",
                                   Type => "NAA"
                        });
                        my $returnCode = &FNO::print();
                        exit $returnCode;
		}
}

for my $i ( 0 .. $#DISK ) {
	for my $o ( 0 .. $#cfg_disk ) {
		$DISK[$i]=~s/\+//g;
		if ( $DISK[$i] =~ m/^$cfg_disk[$o]$/ ) {
			$cfgflag=1;
			&process_output($DISK[$i],$USAGE[$i],$info[$o],$warning[$o],$critical[$o],$MsgG[$o],$App[$o]);
			&process_perfdata($CAPACITY[$i],$USED[$i],$warning[$o],$critical[$o],$DISK[$i]);
		}
	}

	if ( $cfgflag == 0 ) {
		# ORACLE Defaults 
		# if a mount includes /ora or if a mount ends with u00 and maybe followd by more 0
		if ( $DISK[$i] =~ m/(\/ora|\/u000*$)/ ) { 
			&process_output($DISK[$i],$USAGE[$i],'90','95','98','OPS-Database','System');
	        	&process_perfdata($CAPACITY[$i],$USED[$i],$warning[$o],$critical[$o],$DISK[$i]);
		} else {
			&process_output($DISK[$i],$USAGE[$i],'not_defined','95','98',$opt_m,'System');
	        	&process_perfdata($CAPACITY[$i],$USED[$i],$warning[$o],$critical[$o],$DISK[$i]);
		}
	}
	$cfgflag=0;
}

###########################################################################################################################################################################
# compares if section from config is also in the DF command
###########################################################################################################################################################################
#my $disk_count = scalar(@DISK);
#my $disk_found_flag=0;
#
#for my $j ( 0 .. $#cfg_disk ) {
#	for my $k ( 0 .. $#DISK ) {
#		$DISK[$k]=~s/\+//g;
#		if ( $cfg_disk[$j] =~ m/^$DISK[$k]$/ ) {
#			$disk_found_flag=1;
#		}
#		$disk_count=$disk_count-1;
#                #print "DISK: $DISK[$k] and CFG_DISK: $cfg_disk[$j] DISK_count: $disk_count\n";
#                if($disk_count == 0 and $disk_found_flag == 0){
#                        FNO::add({ Summary => "$cfg_disk[$j] not found in DF command",
#                                   Severity => "Warning",
#                                   AlertGroup => "NAGIOS",
#                                   AlertKey => "command_error",
#                                   MsgGroup => "ENG-OSS",
#                                   Type => "NAA"
#                        });
#                        my $returnCode = &FNO::print();
#                        exit $returnCode;
#                }
#	}
#	$disk_found_flag=0;
#	$disk_count = scalar(@DISK);
#}
###########################################################################################################################################################################

my $returnCode = &FNO::print();
exit $returnCode;

###########################################################################################################################################################################
# subroutines
###########################################################################################################################################################################

sub print_usage () {
        print "Copyright (c) 07.09.2017 by Thomas Perr\n\n";
        print "Usage:\n";
        print "  $0 -f <config file> -d <default MsgGroup> [OPTIONAL] -t <timeout in sec> \n";
        print "\n\nOptions:\n";
        print "  -h, --help\n";
        print "     Print detailed help screen\n";
        print "  -f, --config_file\n";
        print "     Config file can be defined to set MsgGroup and thresholds for mountpoints. Otherwise default values will be used.\n";
        print "     Example with default thresholds.\n";
        print "     -------------------------------------------------------\n";
        print "     [/appl/nagios]\n";
        print "     filesystem=/appl/nagios\n";
        print "     MsgG=OSS\n";
        print "     App=NAGIOS\n";
        print "     Warning=95\n";
        print "     Critical=98\n";
        print "     -------------------------------------------------------\n";
        print "  -m, --default_messagegroup\n";
        print "     Default MsgGroup if script has errors etc.\n";
        print "  -t, --timeout\n";
        print "     Default timeout is 120 seconds. New one can be set, but has to be lower 300 seconds as this is the timeout value for nrpe.\n";
}

sub validation_check {
$info=shift; $warning=shift; $critical=shift; $section=shift;

        if ( $critical eq 'not_defined' and $warning eq 'not_defined' and $info eq 'not_defined' ) {
                FNO::add({ Summary => "No threshold defined in config file in section $section!",
                           Severity => "Warning",
                           AlertGroup => "NAGIOS",
                           AlertKey => "cfg_file",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
                my $returnCode = &FNO::print();
                exit $returnCode;
        }

        if ( $info ne 'not_defined' and $warning ne 'not_defined' and $info > $warning ) {
                FNO::add({ Summary => "Info value is greater than warning value in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$info._greater_.$warning",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }
        if ( $info ne 'not_defined' and $critical ne 'not_defined' and $info > $critical ) {
                FNO::add({ Summary => "Info value is greater than critical value in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$info._greater_.$critical",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }
        if ( $warning ne 'not_defined' and $critical ne 'not_defined' and $warning > $critical ) {
                FNO::add({ Summary => "Warning value is greater than critical value in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$warning._greater_.$critical",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }
}

sub process_output {
$disk=shift; $usage=shift; 
$info=shift; $warning=shift; $critical=shift; 
$msgg=shift; $App=shift;

        if ( $critical ne 'not_defined' and $usage >= $critical ) {
                FNO::add({ Summary => "space utilization on $disk high ($usage% used) (Threshold: $critical%)",
                           Severity => "Critical",
                           AlertGroup => $App,
                           AlertKey => $disk,
                           MsgGroup => $msgg,
                });
        } elsif ( $warning ne 'not_defined' and $usage >= $warning ) {
                FNO::add({ Summary => "space utilization on $disk high ($usage% used) (Threshold: $warning%)",
                           Severity => "Warning",
                           AlertGroup => $App,
                           AlertKey => $disk,
                           MsgGroup => $msgg,
                });
        } elsif ( $info ne 'not_defined' and $usage >= $info ) {
                FNO::add({ Summary => "space utilization on $disk high ($usage% used) (Threshold: $info%)",
                           Severity => "Info",
                           AlertGroup => $App,
                           AlertKey => $disk,
                           MsgGroup => $msgg,
                });
        } else {
                if ($info ne 'not_defined') {
                        $thresh = $info;
                        $severity = "INFO";

                } elsif ($warning ne 'not_defined') {
                        $thresh = $warning;
                        $severity = "WARNING";

                } else {
                        $thresh = $critical;
                        $severity = "CRITICAL";
                }

                FNO::add({ Summary => "space utilization on $disk normal ($usage% used) (Threshold: $thresh% for $severity alarm)",
                           Severity => "Normal",
                           AlertGroup => $App,
                           AlertKey => $disk,
                           MsgGroup => $msgg
                });
        }

}

sub process_perfdata {
	 # Calculate Value in MB for performance Data
	 $capacity=shift; $used=shift; $warning=shift; $critical=shift; $disk=shift;
         if ($warning eq 'not_defined'){
                $warning=95;
         }
         $perfwarn=($capacity * ($warning / 100)) / 1024;
         $perfwarn=sprintf("%.2f", $perfwarn);
         if ($critical eq 'not_defined'){
                $critical=98;
         }
         $perfcrit=($capacity * ($critical / 100))/ 1024;
         $perfcrit=sprintf("%.2f", $perfcrit);

	 $used=$used / 1024 ;
         $used=sprintf("%.2f", $used);
         $capacity=$capacity / 1024;
         $capacity=sprintf("%.0f", $capacity);
	 #$perfout="$disk=$used\MB;$perfwarn;$perfcrit;0;$capacity";
	 #$perfout=~s/\+//g;
	 #push (@perfout,$perfout);
	 FNO::addPerfdata( { Name => $disk,
                     Value => $used,
                     Unit => "MB",
                     PerfWarn => $perfwarn,
                     PerfCrit => $perfcrit,
                     PerfMin => 0,
                     PerfMax => $capacity
	});
}

sub process_command {
    my $cmd = shift;
    my $retV = '';
    `$cmd 2>&1`;
    if ($? == 0) {
      $retV = `$cmd`;
    }
    return $retV;
}

