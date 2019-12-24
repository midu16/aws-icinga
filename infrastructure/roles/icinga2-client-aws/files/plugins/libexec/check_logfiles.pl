#!/usr/bin/perl  
# This nagios plugin uses the Simple Event Correlator (sec.pl)
# tool for logfile monitoring
# by perrth 10.01.08
use Digest::MD5 qw(md5_hex);;
use Getopt::Long;
use lib '/appl/icinga/plugins/libexec/';
use FNO;
use Time::HiRes qw(gettimeofday);
#use strict;

Getopt::Long::Configure('bundling');
        GetOptions(
                "h|help"   	=> \$opt_h,
                "t|ticinga=s"	=> \$lastcheck,
                "s|service=s"	=> \$service_name,
                "m|monitored=s"	=> \$monitored);

if ($opt_h){
        &print_usage();
        exit 0
}
&check_param($lastcheck, $service_name, $monitored);

my ($logfile_name, $cfgfile_name, $cfgfile_name_tmp, $cfgfile_tmp, $outfile_name, $pid, $ps_output, $number, $line,$line_tmp, $ecode, $unix_time, $file,$logfile_count,$uid,$gid,$time_diff, $time_file, $restart_needed,$logfilecount,$count );
my ($i, $j, $argument, @argument ,@nagios_output, @nagios_output_tmp, @nagios_output_outfile, @nagios_output_info, @logfile_name, @cfgfile_name, @file, @file_attribute, @shell_name, my %freq);
my @line;
my @seek_position;
my $dup_bytes;
my $sec_bytes;
my $max_bytes=15300;

my $debug_file="/appl/icinga/plugins/var/debug_file";
my $seek_file="/appl/icinga/plugins/var/seek_position";
my $dupfile;
my $SECBIN="sudo /appl/icinga/plugins/libexec/h3g.sec.pl";
my $SECCFG="/appl/icinga/plugins/etc/";
my $SECVAR="/appl/icinga/plugins/var/"; 
my ($SECARG, $SECSTART, $SECPIDFILE);
my $crit_count=0,my $warn_count=0,my $info_count=0, $ok_count=0;
my $osname =`uname -a | cut -d " " -f 1`; chomp($osname);
my $debug=0;
FNO::set('ignoreDuplicates','true');


$TIMEOUT=120;
alarm($TIMEOUT);
$SIG{'ALRM'} = sub {
        FNO::add({ Summary => "Plugin check_logfiles.pl timed out after $TIMEOUT sec",
                        Severity => "Info",
                        AlertGroup => "NAGIOS",
                        AlertKey => "timeout",
                        MsgGroup => "OSS",
                        Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
};


if ( $debug == 1 ) {
	print "Started check_logfiles.pl in DEBUG mode\n"; 
	open(DEBUG_FILE, ">>$debug_file");
}

if ( $osname eq 'SunOS' ) {
        # Solaris grep
        $PS = "/usr/ucb/ps wwaux";
} elsif ( $osname eq 'Linux' ) {
        $PS = "ps wwaux";
} elsif ( $osname eq 'HP-UX' ) {
        $PS = "ps -efx";
}



# shift first two arguments 
#$lastcheck=shift @ARGV if $ARGV[0]=~m/\d+/;
#shift @ARGV if $ARGV[0]=~m/service_name/; 

#$service_name=shift @ARGV if $ARGV[0]=~m/\S/; 

log_msg("------> START NEW POLLING <--------");
log_msg("Used PS: $PS for $osname");
log_msg("Nagios service name: $service_name");

#&help_output if $#ARGV == -1;

my @tmpArg = split(/ /, $monitored);

foreach $argument (@tmpArg) { 
	if (  $argument=~m/^\S+,\S+.cfg(,file_exist)?$/ ) {
		log_msg("Got correct logfile/cfgfile parameter:  $argument");
	} else {
		&help_output();  	
	}
}

for $i (0 .. $#tmpArg ) {
	(@argument)=split(/,/, $tmpArg[$i]);

	if ( $argument[$#argument]=~/file_exist/ ) {
		$file_exist=pop @argument;
		log_msg("Check if logfile exist for this logfile/cfgfile parameter");
	} else { 
		$file_exist="";
	}

	$cfgfile_name=pop(@argument);
	# execute shell command to get logfile_name
	# Example ls -1 -t /appl/logs/psft/[IA][NP][TP]0[12]/LOGS/APPSRV_*.LOG|head -2
	if ( grep m/%.*%/, @argument ) {
		 foreach $logfile_name (@argument) {
                        $logfile_name=~s/^%//g;     # remove first %
                        $logfile_name=~s/%$//g;     # remove last %
			$logfile_name=~s/_b_/ /g;   # blank character
			$logfile_name=~s/_pp_/|/g;  # pipe character
			@shell_name=`$logfile_name`; chomp @shell_name;
			log_msg("Execute shell command $logfile_name to get logfile_name(s)");
			log_msg("Logfile name(s): @shell_name");
		}
		@argument=@shell_name;
	}

	$cfgfile_for_cluster=$cfgfile_name;
	$cfgfile_for_cluster=~s/\//_/g;
	$outfile_name=$SECVAR . $cfgfile_for_cluster; $outfile_name=~s/cfg/log/;
	$perffile_name=$SECVAR . $cfgfile_for_cluster; $perffile_name=~s/cfg/perf/;
	$dupfile="$outfile_name" . "_buffer";
	$cfgfile_name=$SECCFG . $cfgfile_name;

	log_msg("Cfgfile_name: $cfgfile_name");
	log_msg("Outfile_name: $outfile_name");
	log_msg("Context_name: $cfgfile_name");
	log_msg("LOGFILE(s):   @argument");
	log_msg("----------------------------------------");
	foreach $logfile_name (@argument) {
#		if ( ( ! -r $logfile_name ) && ( $file_exist=~m/file_exist/ ) ) {
#			log_msg("$logfile_name does not exist");
#			my $Sev='Warning';
#			if ( -r  $cfgfile_name ) {
#				open(CFG, "$cfgfile_name");
#				while(<CFG>){
# 					push (@MsgG,$1) if $_=~/MsgG=(\S+)/i;
#					$Sev='Critical' if $_=~/Sev=Critical/i;
#				}
#				close(CFG);
#				# only get unique Message Group
#				%hsh;
#				undef @hsh{@MsgG};
#				@MsgG_unique = keys %hsh;
#				$MsgG_all=join(",", @MsgG_unique);
#				FNO::add({ Summary => "$Sev - Logfile '$logfile_name' does not exist MsgG=$MsgG_all",
#                        		   Severity => $Sev,
#                        		   AlertGroup => "System",
#                        		   AlertKey => $logfile_name,
#                        		   MsgGroup => $MsgG_all,
#                        		   Type => "NAA"
#        			});
#			} 
#		}
#		if ( ! -r $logfile_name ) {
#			FNO::addText("Logfile $logfile_name does not exist");
#		} 
		$SECARG.="-input=$logfile_name=$cfgfile_name ";
		# Write $logfile_name to an array for nagios_output_info
        	push(@logfile_name,"$logfile_name uses cfg file: $cfgfile_name");
		log_msg("Logifle: $logfile_name uses cfg file: $cfgfile_name");
	}
	# Set cfgfile_name for logfiles 
	$SECARG.="-conf=$cfgfile_name ";

	# Write $cfgfile_name to an array to check modification time
	push(@cfgfile_name,$cfgfile_name);

	# Write outfile from SEC to an array and delete it
	# Needed to get alarms from SEC into nagios
	if (  -r "$outfile_name") {
        	
		open(OUTFILE, "$outfile_name");
		@nagios_output_tmp=<OUTFILE>;
	
		$max=$#nagios_output_tmp;
		for $j ( 0  .. $max ) {
			if ( $j+1 <= $max and $nagios_output_tmp[$j] eq $nagios_output_tmp[$j+1] ){ 
				$count++;
			}else{	
				$line=$nagios_output_tmp[$j];			
				$line=~s/"/'/g;
				if ($count > 0){
					$line=~s/<!--/ ($count duplicate entries) <!--/; #nur wenn count >0 ist brauch die zusatzinfo…
				}
				$count=0;	

				#add valueChangeEvent with milli seconds
				my ($sec,$milli) = gettimeofday;
				$milliseconds=$sec . $milli;
				$output_line_vce=$line;
				$output_line_vce=~s/-->/ vce=$milliseconds -->/;
				
				#20171006 aignerma: Changed default type to 'NAA'
				if ($line!~/<!--.*type=.*-->/i ) {
                        		$output_line_vce=~s/-->/ Type=NAA -->/;
                       		}
				
                        	push(@nagios_output_outfile,$output_line_vce);
			}
		}
		close(OUTFILE);
		unlink($outfile_name);
	}
	if (  -r "$perffile_name") {
	        open(PERFFILE, "$perffile_name");
		@nagios_perf=<PERFFILE>;
		close(PERFFILE);	
		unlink($perffile_name);
	}
	#################################################################
	#Creating Argument for starting SEC
	#$SECARG.="-input=$logfile_name=$cfgfile_name -conf=$cfgfile_name ";

	# set context and outputfile_name in cfgfile_name to string what we get from argument (cfgfilename)
	# this is needed that SEC knows where to write an alarm to outputfile_name
	if ( -r "$cfgfile_name") { 
		open(file, "<$cfgfile_name");    
		@file= <file>;
		close(datei);
		@file_attribute=stat("$cfgfile_name");
		$uid=$file_attribute[4]; $gid=$file_attribute[5];
	 	if ( grep m/CONTEXT_SET_BY_NAGIOS|OUTFILE_SET_BY_NAGIOS/, @file ) {
			log_msg("Set correct CONTEXT and OUTFILE in $cfgfile_name");
			unlink($cfgfile_name);
			open(file, ">$cfgfile_name");
			foreach $line (@file) {
				$line =~s/CONTEXT_SET_BY_NAGIOS/$cfgfile_name/;
				$line =~s/OUTFILE_SET_BY_NAGIOS/$outfile_name/;
				print file $line;
			}
		}
		close(datei);
		chown $uid, $gid, $cfgfile_name;
	} else {
		push(@nagios_output,"Info - Config error as $cfgfile_name does not exists on agent MsgG=OSS <!-- Obj=$cfgfile_name MsgG=OSS Sev=Info -->\n");
        	FNO::add({ Summary => "Info - Config error as $cfgfile_name does not exists on agent",
                           Severity => "Info",
                           AlertGroup => "NAGIOS",
                           AlertKey => $cfgfile_name,
                           MsgGroup => "OSS",
                           Type => "NAA"
        	});
		log_msg("Info - Conifg error as $cfgfile_name does not exists on agent MsgG=OSS <!-- Obj=$cfgfile_name MsgG=OSS Sev=Info -->");
	} 
}

# Calculate diff between time know and time of last file modificaton of @cfgfile_name 
# @cfgfile_names have been changed, restart SEC to get new rules

foreach $cfgfile_name (@cfgfile_name) { 
	# Get file attributes
	@file_attribute=stat("$cfgfile_name");
	$time_file=$file_attribute[9];
	$time_diff=time - $time_file;
	if ( $time_diff < 330 ) { $restart_needed='YES - SEC CFG FILES CHANGED'; log_msg("CFG file modified $time_diff ago"); }
}

# Creating name for pidfile
$SECPIDFILE=$SECVAR . $service_name . "_SEC.pid";


# add SEC arguments which are always the same
$SECARG.="-detach -pid=$SECPIDFILE -debug=4 -log=/appl/icinga/plugins/var/sec.log -reopen_timeout=5";
$SECSTART="$SECBIN $SECARG";
$START=$SECSTART;
$SECSTART=~s/\+/\\+/g;


@PID=`$PS | grep \"$SECSTART\" | grep -v grep | awk '{ print \$2 }'`; 
$sec_procs_running=$#PID + 1;
$ps_output=`$PS |  grep \"$SECSTART\" | grep -v grep`;  chomp $ps_output;
if ( $sec_procs_running > 1 ) {
        log_msg("INFO - SEC is running $sec_procs_running times");
}

$pidthresh=0;
$zoneadm=`/usr/sbin/zoneadm list 2>/dev/null | grep global 2>/dev/null`;
if ( ${zoneadm} ) {
        $pidthresh=50;
}

if ( $#PID  > $pidthresh ) {
	foreach $pid (@PID) {
	#`kill $pid`; chomp $pid;
	log_msg("INFO - Same SEC process were running $sec_procs_running times. Killed pid $pid! MsgG=OSS");
	$temp_pid.=$pid . ",";
	}
        `sudo /usr/bin/pkill h3g.sec.pl`;
	FNO::add({ Summary => "Same SEC process were running $sec_procs_running times. Killed pids \'$temp_pid\' and start SEC as it should!",
                        Severity => "Info",
                        AlertGroup => "NAGIOS",
                        AlertKey => "sec_restart",
                        MsgGroup => "OSS",
                        Type => "NAA"
        });
	log_msg("STARTING SEC as it should");
	`$START`;
}


if ( $ps_output=~m/$SECSTART$/ ) {
	$restart_needed.='NO - NAGIOS ARGS NOT CHANGED';
        } else {
	# Nagios arguments have been changed restart is needed or starting SEC the first time
	$restart_needed='YES - NAGIOS ARGS CHANGED';
        }

if ( $restart_needed=~m/YES - NAGIOS ARGS CHANGED/ ) {
	log_msg("SEC RESTARTED!! Nagios args have been changed or starting the first time");
	&sec_restart; 
	}
if ( $restart_needed=~m/YES - SEC CFG FILES CHANGED/ ) {
	log_msg("SEC RESTARTED!! cfg file(s) have been modified $time_diff  seconds ago");
	&sec_restart; 
	}
if ( $restart_needed=~m/^NO - NAGIOS ARGS NOT CHANGED$/ ) {
	log_msg("SEC RESTART Not needed"); 
}


$sec_bytes+=length for @nagios_output_outfile;
# output size of sec was ok, should be the normal behavior
if ( ($sec_bytes < $max_bytes) && (! -r $dupfile) ){
	log_msg("SEC outputfile is smaller then $max_bytes bytes -> Not needed to create buffer file");
	#@nagios_output_tmp = reverse(@nagios_output_tmp); 	
	foreach my $message (@nagios_output_outfile) {
		log_msg("\@nagios_output_outfile:$message");	
		if ($message=~/<!--.*?-->/) {
			FNO::set('MinReturnCode',4);
			FNO::addLine($message);
		} else {
			 FNO::add({ Summary => "There are not hiddenfields set in SEC config",
                        	Severity => "Warning",
                        	AlertGroup => "SEC_Config",
                        	AlertKey => $cfgfile_name,
                        	MsgGroup => "OSS",
				Type => "NAA"
        		});
		}
	}
	#push(@nagios_output,@nagios_output_tmp);

# output size of sec was ok, but there is still an $dupfile which should be processed
} elsif ( ( -r $dupfile ) && ( $sec_bytes < $max_bytes ) ){
        open (DUP_FILE,"+>>$dupfile");
        log_msg("SEC output_file is smaller then $max_bytes bytes -> append it to buffer file and process it");
	#unshift(@nagios_output_tmp,"Warning - Created buffer file and process it MsgG=OSS <!-- Obj=$cfgfile_name App=NAGIOS Type=NAA MsgG=OSS Sev=Warning -->\n");	
	FNO::add({ Summary => "Created buffer file and process it",                        
		   Severity => "Warning",
                   AlertGroup => "NAGIOS",
                   AlertKey => $cfgfile_name,
                   MsgGroup => "OSS",
		   Type => "NAA"
        });
        print DUP_FILE @nagios_output_outfile;
        close (DUP_FILE);
        &process_dupfile;

# output size of sec was more then max_bytes
# Create dupfile and process it
} elsif  ( $sec_bytes > $max_bytes )  {
        open (DUP_FILE,"+>>$dupfile");
        log_msg("SEC output_file is bigger then $max_bytes bytes -> create/append it to buffer file and process it");
	#unshift(@nagios_output_tmp,"Warning - Buffer file is getting bigger and bigger MsgG=OSS <!-- Obj=$cfgfile_name App=NAGIOS Type=NAA MsgG=OSS Sev=Warning -->\n");	
	FNO::add({ Summary => "Buffer file is getting bigger and bigger!",
                   Severity => "Warning",
                   AlertGroup => "NAGIOS",
                   AlertKey => $cfgfile_name,
                   MsgGroup => "OSS",
		   Type => "NAA"
        });
        print DUP_FILE @nagios_output_outfile;
        close (DUP_FILE);
        &process_dupfile;
}

# To get also OSS Alarms into nagios_output
&check_sec_log_errors;

foreach $file (@logfile_name) {
	FNO::addText("Monitored logfile: $file\n");
}

#FNO::set('printCustomHeader',"Checked $logfile_count logfile(s) - <#OK> Ok, <#INFO> Info, <#WARN> Warn, <#CRIT> Crit");
my $returnCode = &FNO::print();
exit $returnCode;

##############################################################################################################################################
# start of subroutines
##############################################################################################################################################

sub sec_restart {
	$pid=`cat $SECPIDFILE`; 
	chomp $pid;
	log_msg("Killed $pid");
	#`kill $pid`;
	`sudo /usr/bin/pkill h3g.sec.pl`;
	`rm -f $SECPIDFILE`; 
        `$START`;
}

sub process_dupfile {
	# Try to open log seek file.  If open fails, we seek from beginning of
	# file by default.
	if (open(SEEK_FILE,"$seek_file")) {
        	chomp(@seek_position = <SEEK_FILE>);
        	close(SEEK_FILE);
        	#print "SEEK position on byte: $seek_position[0]\n";
        	}

	open (DUP_FILE,"<$dupfile");
	seek(DUP_FILE, $seek_position[0], 0);
	while( my $line = <DUP_FILE> ){
       		#push(@nagios_output,"$line");
		if ($line=~/<!--.*?-->/) {
			FNO::addLine($line);
		} else {
			print "WRONG MESSAGE RECEIVED!!!! Message: -$line-\n";
		}
        	$dup_bytes+=length($line);
        		if ($dup_bytes > $max_bytes){
			#	print "DEBUG: Writing bytepostion: ";
			#	print tell(DUP_FILE);
          		#	print " to $seek_file\n";
                       		open(SEEK_FILE,">$seek_file");
                        	print SEEK_FILE tell(DUP_FILE);
                        	close(SEEK_FILE);
                        	close(DUP_FILE);
                        	break;
                		}
        	}
	# If all bytes in dupfile have been read it can be deleted 
	if ( ( $dup_bytes < $max_bytes ) && ($sec_bytes < $max_bytes) ) {
        	# push(@nagios_output,"Ok - Created buffer file have been deleted. Check with Systemowner if we can improve the SEC logic! MsgG=OSS <!-- Obj=$cfgfile_name Type=NAA MsgG=OSS Sev=Info key=monitoring -->\n");
	        FNO::add({ Summary => "Created buffer file have been deleted. Check with Systemowner if we can improve the SEC logic!",
                        Severity => "Info",
                        AlertGroup => "NAGIOS",
                        AlertKey => $cfgfile_name,
                        MsgGroup => "OSS",
        		Type => "NAA"
		});
        	close(SEEK_FILE);
        	close(DUP_FILE);
        	unlink($seek_file);
        	unlink($dupfile);
		log_msg("Read only $dup_bytes bytes from buffer file");
		log_msg("Deleted seek and buffer file as all data have been read and sent to nagios\n");
        	}
	}

sub log_msg {
  my($ltime, $msg);
  if ($debug != 1 )  { 
	return; 
  }
  $msg = shift @_;
  $ltime = localtime(time());
  print DEBUG_FILE "$ltime: $msg\n";

}

sub check_sec_log_errors {
	my $SEC_log="/appl/nagios/var/sec.log";
	if (  -r "$SEC_log") {
		@content=`cat /appl/nagios/var/sec.log`;
		foreach $line (@content) {
			if ( $line=~/Rule in/ ) {
				chomp $line;
			        FNO::add({ Summary => "SEC Config ERROR \'$line\'",
                        		Severity => "Warning",
                        		AlertGroup => "NAGIOS",
                        		AlertKey => $SEC_log,
                        		MsgGroup => "OSS",
                        		Type => "NAA"
        			});
			}
		}
	#`rm "$SEC_log"`;
	}
}
				
sub print_usage () {
        print "Usage:\n";
        print "  $0 -t <MACRO_\$TIMET\$> -s <service name> -m <monitored log files/associated configs> \n";
        print "\nOptions:\n";
        print "  -h, --help\n";
        print "     Print this help screen\n";
        print "  -t, --ticinga\n";
        print "     unix timestamp of icinga server\n";
        print "  -s, --service\n";
        print "     Service name associated with this plugin.\n";
        print "  -m, --monitored\n";
        print "     Format log_file1,configfile1 logfile2,configfile2 ... \n";
}


sub check_param {
$tnagios=shift; $serv=shift; $mon=shift;

     if (! $tnagios) {
        FNO::add({ Summary => "No icinga timestamp has been passed",
                   Severity => "Major",
                   AlertGroup => "Icinga",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
     }

     if (! $serv) {
        FNO::add({ Summary => "No associated service name has been defined",
                   Severity => "Major",
                   AlertGroup => "Icinga",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
     }

     if (!$mon) {
        FNO::add({ Summary => "No logfile/conffile has been defined",
                   Severity => "Major",
                   AlertGroup => "Icinga",
                   AlertKey => "service_config",
                   MsgGroup => "OSS",
                   Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
     }
}

