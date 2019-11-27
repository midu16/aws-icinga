#!/appl/nagios/perl/bin/perl
# created by Thomas Perr 04.10.2007
# adapted by Mariella Majewsky 23.08.2018
use Getopt::Long;
use Config::IniFiles;
use lib '/appl/icinga/plugins/libexec/';
use FNO;

###########################################################################################################################################################################
# execution example:
###########################################################################################################################################################################
# ./check_processes -f file_to_monitor.cfg [OPTIONAL] -t 150
# -h for help
# -f <value> for config file
# -t <value> for timeout of the script

###########################################################################################################################################################################
# variables
###########################################################################################################################################################################
my $debug=0;

###########################################################################################################################################################################
# evaluate options
###########################################################################################################################################################################
Getopt::Long::Configure('bundling');
        GetOptions(
                "h|help"                   => \$opt_h,
                "f|config_file=s"          => \$opt_f,
                "t|timeout=i"              => \$opt_t);

if ($opt_h){
        &print_usage();
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

&ps;
$proc_count=0;


# Getting Data from Config File
my $cfg = new Config::IniFiles( -file => "$cfg_file", -nocase => 1);
my @sect=$cfg->Sections;
foreach $section (@sect) {
         $type=$cfg->val( "$section", 'type');
         $monitor=$cfg->val( "$section", 'monitor');
         $MsgG=$cfg->val( "$section", 'MsgG','OSS' );
         $App=$cfg->val( "$section", 'App','not_defined' );
         $Text=$cfg->val( "$section", 'Text');
         $graph=$cfg->val( "$section", 'graph');
         $info_thresh=$cfg->val( "$section", 'info','not_defined');
         $warn_thresh=$cfg->val( "$section", 'warning','not_defined');
         $crit_thresh=$cfg->val( "$section", 'critical','not_defined');
         $zone=$cfg->val( "$section", 'zone', '.*');

	if ( $type eq 'pidfile' ) {
		if ( -r "$monitor") {
			$pidfile="$monitor";
        		open(PIDFILE,"$pidfile");
        		chomp($monitor= <PIDFILE>);
        		close(PIDFILE);
			FNO::add({ Summary => "Pidfile '$pidfile' with PID '$monitor' exists.",
				   Severity => "Normal",
				   AlertGroup => $App,
				   AlertKey => $pidfile . "_exists",
				   MsgGroup => $MsgG
                        });
			($proc_count)=&get_proc_count($monitor,$type);
        	} else { 
		        FNO::add({ Summary => "Pidfile '$monitor' does not exists!!",
				   Severity => "Warning",
				   AlertGroup => $App,
				   AlertKey => $monitor . "_exists",
				   MsgGroup => $MsgG
        		});
			next;
		} 
	} else { 
		($proc_count)=&get_proc_count($monitor,$type);
	}

	#subroutine will check the logic of the thresholds and if at least one threshold is defined
	&validation_check($crit_thresh,$warn_thresh,$info_thresh,$section);
	
	if ( $crit_thresh ne 'not_defined' ) {
		&check_alarm_level('Critical',$proc_count,$crit_thresh,$type,$monitor,$MsgG,$pidfile,$App,$Text,$graph);
        }
	if ( $warn_thresh ne 'not_defined' ) {
		&check_alarm_level('Warning',$proc_count,$warn_thresh,$type,$monitor,$MsgG,$pidfile,$App,$Text,$graph);
        }
	if ( $info_thresh ne 'not_defined' ) {
		&check_alarm_level('Info',$proc_count,$info_thresh,$type,$monitor,$MsgG,$pidfile,$App,$Text,$graph);
        }
	
	if ($debug eq '1' ) {
		print "Section: $section \tType: $type \tMonitor: $monitor \tMsgG: $MsgG \tInfo_thresh: $info_thresh \tWarn_thresh: $warn_thresh \tCrit_thresh: $crit_thresh\n";  
		print "-----------------------------------------------------------------------------------------------------------------------------\n";
	}

	$proc_count=0;
}

my $returnCode = &FNO::print();
exit $returnCode;

###########################################################################################################################################################################
# subroutines
###########################################################################################################################################################################

sub print_usage () {
        print "Copyright (c) 07.09.2017 by Thomas Perr\n\n";
        print "Usage:\n";
        print "  $0 -f <config file> [OPTIONAL] -t <timeout in sec> \n";
        print "\n\nOptions:\n";
        print "  -h, --help\n";
        print "     Print detailed help screen\n";
        print "  -f, --config_file\n";
        print "     Config file defines the process,the type of the check, the MsgGroup and the thresholds.\n";
        print "     Possible types:\n";
        print "     proc_name  -> checks the process name\n";
        print "     pid        -> checks the pid\n";
        print "     pidfile    -> checks the pidfile\n";
        print "     argument   -> checks the argument \n";
        print "     -------------------------------------------------------------------------------------------------------------------------------\n";
        print "     Example for proc_name.\n";
        print "     -------------------------------------------------------------------------------------------------------------------------------\n";
        print "     [syslogd]\n";
        print "     type=proc_name\n";
        print "     monitor=syslogd\n";
        print "     MsgG=OPS-Unix\n";
        print "     App=System\n";
        print "     critical=1,30\n";
        print "     -------------------------------------------------------------------------------------------------------------------------------\n";
	print "  -t, --timeout\n";
        print "     Default timeout is 120 seconds. New one can be set, but has to be lower 300 seconds as this is the timeout value for nrpe.\n";
}

sub validation_check {
$crit_thresh=shift; $warn_thresh=shift; $info_thresh=shift; $section=shift;

        if($crit_thresh ne 'not_defined'){
                ($min_crit_thresh,$max_crit_thresh)=split/,/,$crit_thresh;
        }
        if($warn_thresh ne 'not_defined'){
                ($min_warn_thresh,$max_warn_thresh)=split/,/,$warn_thresh;
        }
        if($info_thresh ne 'not_defined'){
                ($min_info_thresh,$max_info_thresh)=split/,/,$info_thresh;
        }

        if ( $crit_thresh eq 'not_defined' and $warn_thresh eq 'not_defined' and $info_thresh eq 'not_defined' ) {
                FNO::add({ Summary => "No threshold defined in config file in section $section!",
                           Severity => "Warning",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.cfg_file",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
                my $returnCode = &FNO::print();
                exit $returnCode;
        }
        if ( $info_thresh ne 'not_defined' and $warn_thresh ne 'not_defined' and $min_info_thresh < $min_warn_thresh ) {
                FNO::add({ Summary => "Info value for minimum is lower than warning value for minimum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$min_info_thresh._lower_.$min_warn_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }
        if ( $info_thresh ne 'not_defined' and $warn_thresh ne 'not_defined' and $max_info_thresh > $max_warn_thresh ) {
                FNO::add({ Summary => "Info value for maximum is greater than warning value for maximum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$max_info_thresh._greater_.$max_warn_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }

        if ( $info_thresh ne 'not_defined' and $crit_thresh ne 'not_defined' and $min_info_thresh < $min_crit_thresh ) {
                FNO::add({ Summary => "Info value for minimum is lower than critical value for minimum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$min_info_thresh._lower_.$min_crit_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }

        if ( $info_thresh ne 'not_defined' and $crit_thresh ne 'not_defined' and $max_info_thresh > $max_crit_thresh ) {
                FNO::add({ Summary => "Info value for maximum is greater than critical value for maximum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$max_info_thresh._greater_.$max_crit_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }

        if ( $warn_thresh ne 'not_defined' and $crit_thresh ne 'not_defined' and $min_warn_thresh < $min_crit_thresh ) {
                FNO::add({ Summary => "Warning value for minimum is lower than critical value for minimum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$min_warn_thresh._lower_.$min_warn_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }

        if ( $warn_thresh ne 'not_defined' and $crit_thresh ne 'not_defined' and $max_warn_thresh > $max_crit_thresh ) {
                FNO::add({ Summary => "Warning value for maximum is greater than critical value for maximum in section $section",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => "$section._.$max_warn_thresh._greater_.$max_crit_thresh",
                           MsgGroup => "OSS",
                           Type => "NAA"
                });
        }

}

sub get_proc_count {
	$monitor = shift;
	$type= shift;
	if ( $type eq 'proc_name' ) {
		for $i ( 0 .. $#PROCNAME ) {
			# Change for Solaris Systems with "Zones". If configuration "zone" is defined, only processes for corresponding zone are of relevance.
			# second part of if operator only applies if there is a zone anyways
			if ( $PROCNAME[$i]=~m/$monitor.*/i && $ZONE[$i]=~m/$zone/i ) {
				$cpu+=$CPU[$i]; $mem+=$MEM[$i]; $proc_count++;
				if ( $debug == 1 ) {
					print "Monitor=$monitor \t PROC_COUNT: $proc_count \t Used CPU: $cpu \t Used MEM: $mem\n";
				}
			}
		}
	} elsif ( $type eq 'pid' ) {
		for $i ( 0 .. $#PROCNAME ) {
			if ( $PID[$i]=~m/^$monitor$/i  ) {
				$cpu+=$CPU[$i]; $mem+=$MEM[$i]; $proc_count++;
				if ( $debug == 1 ) {
					print "Monitor=$monitor \t PROC_COUNT: $proc_count \t Used CPU: $cpu \t Used MEM: $mem\n";
				}
			}   		
		}
	} elsif ( $type eq 'pidfile' ) {
		for $i ( 0 .. $#PROCNAME ) {
			if ( $PID[$i]=~m/^$monitor$/i  ) {
				$cpu+=$CPU[$i]; $mem+=$MEM[$i]; $proc_count++;
				if ( $debug == 1 ) {
					print "Monitor=$monitor \t PROC_COUNT: $proc_count \t Used CPU: $cpu \t Used MEM: $mem\n";
				}
			}
		}
	} elsif ( $type eq 'argument' ) {
		#escape regex characters
		$monitor=~s/\+/\\+/;
		for $i ( 0 .. $#PROCNAME ) {
			if ( $ARGS[$i]=~m/$monitor/i  ) {
				$cpu+=$CPU[$i]; $mem+=$MEM[$i]; $proc_count++;
				if ( $debug == 1 ) {
					print "Monitor=$monitor \t PROC_COUNT: $proc_count \t Used CPU: $cpu \t Used MEM: $mem\n";
				}
			}
		}
	} else {
		FNO::add({ Summary => "Critical - config error type=$type!! Should be proc_name|pid|pidfile|arguments! MsgG=OSS",
                	   Severity => "Critical",
                	   AlertGroup => "NAGIOS",
			   AlertKey => $pidfile,
			   MsgGroup => "OSS",
			   Type => "NAA"
		});
	}
	return ($proc_count);
}

# Checking running process
sub ps {
	$osname =`uname -a | cut -d " " -f 1`;
	chomp $osname;
	if ( $osname eq 'SunOS' ) {
                ### Change for Solaris Systems with "Zones" (5.10 and above). Last column added: zone-name.
		$OSVersion = `uname -r`;
		if ( $OSVersion=~/5.(8|9)/ ) {
			$PS='/usr/ucb/ps wwaux';
		} else {
			@AllArguments=`/usr/ucb/ps wwaux`;
                	$PS='ps -efZ -o user -o pid -o pcpu -o pmem -o vsz -o rss -o tty -o s -o stime -o time -o args -o zone';
		}
	} elsif ( $osname eq 'Linux' ) {
      		$PS='ps wwaux';
	} elsif ( $osname eq 'AIX' ) {
                $PS='ps wwaux';
	} else {
      		$PS='ps -xef';
	}
	$PS=$PS . ' | grep -v "\ Z\ "'; # bugfix not to show Zombie processes
	@running_procs=`$PS`;
		foreach $line (@running_procs) {
    			if ( $osname eq 'HP-UX' ) {
				next if $line=~/(UID\s+PID\s+)/i;
				if ( $line=~/(\S+)\s+(\d+).*?\s+(\d+\:\d+)\s+(\S+)/ ) {
                			my $user=$1; my $pid=$2; my $proc=$4 . $'; my $args=$';
                			push(@USER,$user);push(@PID,$pid);push(@PROCNAME,$proc);push(@ARGS,$args);
                        			if ( $debug == 1 ) {
                        				print "Debug:: USER: $user PID: $pid CPU: $cpu MEM: $mem PROC: $proc ARGSs: $args\n";
                        				print "Debug: Max index of Arrays: $#PROCNAME $#USER $#PID $#CPU $#MEM $#ARGS \n";
                        			}
                        	} else { 
					FNO::add({ Summary => "Can not parse procs for $osname MsgG=OSS",
                                        	   Severity => "Warning",
                                        	   AlertGroup => "NAGIOS",
                                        	   AlertKey => "parsing error",
                                        	   MsgGroup => "OSS",
                                        	   Type => "NAA"
                                 	});
				}
			} elsif (( $osname eq 'SunOS' ) && ( $OSVersion=~/5.(8|9)/ )) {
				next if $line=~/(USER\s+PID\s+%CPU\s+%MEM)/i;
  				if ( $line=~/(\S+)\s+(\d+)\s+(\d+\.?\d)\s+(\d+\.\d)(.*?\d+\:\d+)\s+(\S+)/ ) {
                			my $user=$1; my $pid=$2; my $cpu=$3; my $mem=$4; my $proc=$6 . $';
                			push(@USER,$user);push(@PID,$pid);push(@CPU,$cpu);push(@MEM,$mem);push(@PROCNAME,$proc);push(@ARGS,$args);push(@ZONE,$zone);
                        	} else { 
					FNO::add({ Summary => "Can not parse procs for $osname MsgG=OSS",
						   Severity => "Warning",
						   AlertGroup => "NAGIOS",
						   AlertKey => "parsing error",
						   MsgGroup => "OSS",
						   Type => "NAA"
					});
				}
			} elsif ( $osname eq 'SunOS' ) {
				next if $line=~/(USER\s+PID\s+%CPU\s+%MEM)/i;
				if ( $line=~/(\S+)\s+(\d+)\s+(\d+\.\d+)\s+.*?((\sO\s)|(\sS\s)|(\sT\s)|(\s0\s)|(\sR\s)|(\sW\s))\s*((\d\d:\d\d:\d\d)|(\w\w\w \d+)|(\w\w\w\w\d+)|(\w\w\w\d+))\s+\S+\s+(\S+)/) {
                			my $user=$1; my $pid=$2; my $cpu=$3; my $mem=$4; my $p=$16; my $zone=$line; $a=$';
						if ( $OSVersion=~/5.(8|9)/ ) {
							$proc=$p . $a; $zone="dummy";
						} else {
							$zone=~s/.*\s(\S+)$/$1/; chomp $zone;
                                                	@temp=grep(m/^\S+\s+$pid\s+/i, @AllArguments );
                                                	$args=@temp[0];$args=~s/.*?$p\s+(.*)/$1/; chomp $args;
							$proc=$p . $args;
						}
						chomp($proc);
                				push(@USER,$user);push(@PID,$pid);push(@CPU,$cpu);push(@MEM,$mem);push(@PROCNAME,$proc);push(@ARGS,$args);push(@ZONE,$zone);
                        	} else { 
					FNO::add({ Summary => "Can not parse procs for $osname MsgG=OSS",
						   Severity => "Warning",
						   AlertGroup => "NAGIOS",
						   AlertKey => "parsing error",
						   MsgGroup => "OSS",
						   Type => "NAA"
					});
				}
			} elsif ( $osname eq 'Linux' ) {
        			chomp $line;
        			next if ($line =~ m/^USER/);
        			($usr,$pid,$cpu,$mem,$VSZ,$RSS,$TT,$STAT,$START,$TIME,$proc) =
            			split(" ", $line, 11);
                		push(@USER,$user);push(@PID,$pid);push(@CPU,$cpu);push(@MEM,$mem);push(@PROCNAME,$proc);push(@ARGS,$args);push(@ZONE,$zone);
                    		if ( $debug == 1 ) {
                        		print "Debug:: USER: $user PID: $pid CPU: $cpu MEM: $mem PROC: $proc ARGSs: $args\n";
                        		print "Debug: Max index of Arrays: $#PROCNAME $#USER $#PID $#CPU $#MEM $#ARGS \n";
                        	}
                	} elsif ( $osname eq 'AIX' ) {
                                chomp $line;
                                next if ($line =~ m/^USER/);
                                ($usr,$pid,$cpu,$mem,$VSZ,$RSS,$TT,$STAT,$START,$TIME,$proc) =
                                split(" ", $line, 11);
                                push(@USER,$user);push(@PID,$pid);push(@CPU,$cpu);push(@MEM,$mem);push(@PROCNAME,$proc);push(@ARGS,$args);push(@ZONE,$zone);
                                if ( $debug == 1 ) {
                                	print "Debug:: USER: $user PID: $pid CPU: $cpu MEM: $mem PROC: $proc ARGSs: $args\n";
                                	print "Debug: Max index of Arrays: $#PROCNAME $#USER $#PID $#CPU $#MEM $#ARGS \n";
                                }
			}

        	}
}

sub check_alarm_level { 
	$severity=shift; $proc_count=shift; $threshold=shift; $type=shift;
	$monitor=shift; $MsgG=shift; $pidfile=shift; $App=shift; $Text=shift; $graph=shift;

	if ( defined $pidfile ) {
	        $monitor="$pidfile";
	        $pidfile=();
	}

	# handle scenario where we use pipe to monitor multiple processes
	$monitor=~s/\|/ or /g;
	$monitor=~s/\(//g;
	$monitor=~s/\)//g;

	($min_thresh,$max_thresh)=split/,/,$threshold;

	if ( $proc_count > $max_thresh ) {
	        if ( $graph == 1 ) {
	                $graph_name=$monitor;
	                $graph_name=~s/(\w+).*/$1/;
	                $perfdata.="${graph_name}_availability=0 ";
			FNO::addPerfdata({ Name => "${graph_name}_availability",
                     			   Value => 0
			});
		}
        	FNO::add({ Summary => "$type: \'$monitor\' Number of processes ($proc_count) more than max! $Text (threshold max:$max_thresh)",
        	           Severity => $severity,
        	           AlertGroup => $App,
       		           AlertKey => $monitor.$severity,
                	   MsgGroup => $MsgG
        	});

	} elsif ( $proc_count < $min_thresh ) {
	        if ( $graph == 1 ) {
	                $graph_name=$monitor;
	                $graph_name=~s/(\w+).*/$1/;
	                $perfdata.="${graph_name}_availability=0 ";
	                FNO::addPerfdata({ Name => "${graph_name}_availability",
	                                   Value => 0
	                });
	        }
	        FNO::add({ Summary => "$type: \'$monitor\' Number of processes ($proc_count) less than min! $Text (threshold min:$min_thresh)",
	                   Severity => $severity,
	                   AlertGroup => $App,
	                   AlertKey => $monitor.$severity,
	                   MsgGroup => $MsgG
	        });

	} else {
	        if ( $graph == 1 ) {
	               $graph_name=$monitor;
	               $graph_name=~s/(\w+).*/$1/;
	               $perfdata.="${graph_name}_availability=1 ";
 	               FNO::addPerfdata({ Name => "${graph_name}_availability",
 	                                  Value => 1
 	               });
                       FNO::addPerfdata( { Name => "${graph_name}_MEM_usage",
                       Value => $mem,
                       Unit => "%"
                       });
                       FNO::addPerfdata( { Name => "${graph_name}_CPU_usage",
                       Value => $cpu,
                       Unit => "%"
                       });
	        }
		FNO::add({ Summary => "$type: $monitor is running $proc_count times. Used CPU: $cpu. Used MEM: $mem. (Thresholds for $severity alarm - min:$min_thresh max:$max_thresh);",
	                   Severity => "Normal",
	                   AlertGroup => $App,
	                   AlertKey => $monitor.$severity,
	                   MsgGroup => $MsgG
	        });
	}
}

sub GetPS {
	open (FH, "ps wwaux |") or die "Could not open ps pipe!\n";
	while($Line = <FH>) {
		chomp $Line;
		# Skip the title line.
		next if ($Line =~ m/\s*USER/);
		($Owner,$Pid,$CPU,$MEM,$VSZ,$RSS,$TT,$STAT,$START,$TIME,$CMD)=split(" ", $Line, 11);
		print "$CMD\n";
		$TotalCPU += $CPU;
		$TotalMEM += $MEM;
	}
	close (FH);
}
