#!/appl/nagios/perl/bin/perl
# Written by perrth to get performance information 
# for Linux Servers
use Sys::Statistics::Linux;
# use Data::Dumper qw(Dumper);
$found_flag=0;
$found_flag1=0;
$count=0;
$count_proc_sleep=0;
$count_proc_running=0;
$count_proc_zombie=0;
$count_proc_iowait=0;
use lib '/appl/icinga/plugins/libexec/';
use FNO;

$debug=0;

$TIMEOUT=120;
alarm($TIMEOUT);
$SIG{'ALRM'} = sub {
        FNO::add({ Summary => "Plugin check_linux_performance.pl timed out after $TIMEOUT sec",
                        Severity => "Info",
                        AlertGroup => "NAGIOS",
                        AlertKey => "timeout",
                        MsgGroup => "OSS",
                        Type => "NAA"
        });
        my $returnCode = &FNO::print();
        exit $returnCode;
};

$msgg="OPS-Unix";

&cpu_usage_monitoring;

# Net Statistc Part
@data=`cat /proc/net/dev`;
$max_32bit=4294967296;

#27.12.2016 oleinial: Use this argument to exclude packet_received_errors and packet_reassembles_failed by using the following argument:
#exlcude_packet_errors
my $exclude_option = $ARGV[1];

#print @data;

$TMP_file='/appl/icinga/plugins/var/traffic.tmp';

# Read old data from traffic.tmp file
if ( -w  "$TMP_file" ) {
        @TMP_data=`cat $TMP_file`;
                foreach $line (@TMP_data) {
                        if ( $line=~m/time=(\d+)/ ) {$time_old=$1 };
                }
}
else {
#print "Seems to be the first polling of interface traffic. No data available\n";
FNO::addText("Seems to be the first polling of interface traffic. No data available");
}

open(FILE, ">$TMP_file");

$count_perfvalues=0;
# Writing new traffic data into traffic.tmp file
foreach $line (@data) {
        next if $line=~/lo|sit/;
        if ( $line=~/(\S+):/ ) {
        $interface=$1; push(@interface,$interface);
        @b = split(/[:\s]+/, `grep $interface /proc/net/dev`);
        $Rbytes{$interface}=$b[2]; $Tbytes{$interface}=$b[10]; $Rxerrs{$interface}=$b[4]; $Txerrs{$interface}=$b[12]; $Txcolls{$interface}=$b[15];
        # Overide $TMP_file with new data
        #print FILE "${interface}_Rbytes=$Rbytes{$1}\n${interface}_Tbytes=$Tbytes{$1}\n${interface}_Rxerrs=$Rxerrs{$1}\n${interface}_Txerrs=$Txerrs{$1}\n${interface}_Txcolls=$Txcolls{$1}\n";
	}
}
$time=time;
#print FILE "time=$time\n";

$diff_time=$time - $time_old;

foreach $line (@TMP_data) {
        foreach $interface (@interface) {
            if ( $line=~m/${interface}_Rbytes=(\d+)/ ) {
                $Rbytes_old{$interface}=$1;
                $value=&diff($Rbytes_old{$interface},$Rbytes{$interface});
                #push(@perf_output,"${interface}_Rbytes=${value}");
        #       print "${interface}_Rbytes Old: $Rbytes_old{$interface}  New: $Rbytes{$interface}\n";
        	FNO::addPerfdata( { Name => "${interface}_Rbytes", Value => ${value} });
		$count_perfvalues++;
		}
            if ( $line=~m/${interface}_Tbytes=(\d+)/ ) {
                $Tbytes_old{$interface}=$1;
                $value=&diff($Tbytes_old{$interface},$Tbytes{$interface});
                #push(@perf_output,"${interface}_Tbytes=${value}");
        #       print "${interface}_Tbytes Old: $Tbytes_old{$interface}  New: $Tbytes{$interface}\n";
       		FNO::addPerfdata( { Name => "${interface}_Tbytes", Value => ${value} });
		$count_perfvalues++;
                }
            if ( $line=~m/${interface}_Rxerrs=(\d+)/ ) {
                $Rxerrs_old{$interface}=$1;
                $value=&diff($Rxerrs_old{$interface},$Rxerrs{$interface});
                #push(@perf_output,"${interface}_Rxerrs=${value}");
        #       print "${interface}_Rxerrs Old: $Rxerrs_old{$interface}  New: $Rxerrs{$interface}\n";
        	FNO::addPerfdata( { Name => "${interface}_Rxerrs", Value => ${value} });
		$count_perfvalues++;
                }
            if ( $line=~m/${interface}_Txerrs=(\d+)/ ) {
                $Txerrs_old{$interface}=$1;
                $value=&diff($Txerrs_old{$interface},$Txerrs{$interface});
                #push(@perf_output,"${interface}_Txerrs=${value}");
        #       print "${interface}_Txerrs Old: $Txerrs_old{$interface}  New: $Txerrs{$interface}\n";
        	FNO::addPerfdata( { Name => "${interface}_Txerrs", Value => ${value} });
		$count_perfvalues++;
                }
            if ( $line=~m/${interface}_Txcolls=(\d+)/ ) {
                $Txcolls_old{$interface}=$1;
                $value=&diff($Txcolls_old{$interface},$Txcolls{$interface});
                #push(@perf_output,"${interface}_Txcolls=${value}");
         #      print "${interface}_Txcolls Old: $Txcolls_old{$interface}  New: $Txcolls{$interface}\n";
        	FNO::addPerfdata( { Name => "${interface}_Txcolls", Value => ${value} });
		$count_perfvalues++;
                }
        }
}
sub diff {
$old=shift; $new=shift;
        if ( $old > $new ) {
                $diff=($max_32bit - $old) + $new;
                } else {
                $diff=$new - $old;
                }
        $value=$diff/$diff_time;
        $value=sprintf("%.2f",($value));
        return($value);
}



# mem section
$lxs = Sys::Statistics::Linux->new( memstats => 1 );
$stats = $lxs->get;
$mem = $stats->{memstats};
	if ( $debug == 1 ) {
		print "------------------------\n";
		print "MEM Statistic\n";	
		print "  MemTotal:  $mem->{memtotal}\n";
		print "  MemFree:   $mem->{memfree}\n";
		print "  Buffers:   $mem->{buffers}\n";
		print "  Cached:    $mem->{cached}\n";
		print "  SwapUsed:  $mem->{swapusedper}%\n";
		}
#push(@perf_output,"MemTotal="."$mem->{memtotal}","MemFree="."$mem->{memfree}","MemBuffers="."$mem->{buffers}","MemCached="."$mem->{cached}","SwapUsed="."$mem->{swapusedper}%");
        FNO::addPerfdata( { Name => "MemTotal", Value => $mem->{memtotal} });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "MemFree", Value => $mem->{memfree} });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "MemBuffers", Value => $mem->{buffers} });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "MemCached", Value => $mem->{cached} });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "SwapUsed", Value => $mem->{swapusedper}, Unit => "%" });
		$count_perfvalues++;

# cpu section
my @cpudata=`mpstat -P ALL 1 10 | grep "^Average"`;
# Example
#Average:     CPU   %user   %nice    %sys %iowait    %irq   %soft  %steal   %idle    intr/s
#Average:     all   13.12    0.00    2.12    0.88    0.00    0.00    0.00   83.88   1198.51
#Average:       0   14.93    0.00    1.00    1.49    0.00    0.00    0.00   82.59    260.70
#Average:       1   27.86    0.00    1.99    1.99    0.00    0.00    0.00   67.66    261.19
#Average:       2    7.46    0.00    1.99    0.50    0.00    0.00    0.00   89.55    259.70
#Average:       3    1.99    0.00    2.99    0.00    0.00    0.00    0.00   94.03    416.42

foreach $line (@cpudata) {
	my $cpuname='cpu';
        chomp $line;
	my @words = split /  */, $line;
        my @headers = split /  */, $cpudata[0];
        my $count_elements=scalar @words-1;

	foreach my $i (0 .. $count_elements) {
                #print "$headers[$i] => $words[$i]\n";
        	
		if($headers[$i] eq "CPU" and  $words[$i] eq "all") {
			$cpuname=$cpuname."_all";
			$i++;
			my $j = $i;			

			foreach $j (2 .. $count_elements) {
				$headers[$j] =~ s/^.//;
				FNO::addPerfdata( { Name => "${cpuname}_$headers[$j]", Value => $words[$j], Unit => "%" });
                		$count_perfvalues++;
			}
		} elsif ($headers[$i] eq "CPU" and $words[$i] ne "CPU"){
			$cpuname=$cpuname.$words[$i];
			my $j = $i;

			foreach $j (2 .. $count_elements) {
                              
				if ($headers[$j] eq "%idle") {
					$headers[$j] =~ s/^.//;
                                	FNO::addPerfdata( { Name => "${cpuname}_$headers[$j]", Value => $words[$j], Unit => "%" });
                                	$count_perfvalues++;
				}
                        }
		}else{
		}
	}
	#if ( $1=~/\d+/ ) {
        #	FNO::addPerfdata( { Name => "${cpuname}_idle", Value => $idle, Unit => "%" });
	#	$count_perfvalues++;
	
	if ( $debug == 1 ) {
          	print "------------------------\n";
               	print "Statistics for $cpuname\n";
               	print "  user      $user\n";
               	print "  nice      $nice\n";
               	print "  sys	   $sys\n";
                print "  idle      $idle\n";
               	print "  ioWait    $iowait\n";
                print "  soft      $soft\n";
                print "  steal     $steal\n";
                print "  irq       $irq\n";
       	}
	

}

# disk statistc
$lxs = Sys::Statistics::Linux->new( diskstats => 1 );
$lxs->init;
sleep 1;
my $stats = $lxs->get;
$disk = $stats->{diskstats};
	if ( $debug == 1 ) {
                print "------------------------\n";
                print "Statistics for disk\n";
		print "  ReadByt    $disk->{rdbyt}\n";
	}   

# Logged in users
if ( -x '/usr/bin/who' ) {
	@users=`/usr/bin/who -q`; 
	foreach $line (@users) {
		if ( $line=~m/users=(\d+)/i ) { $user_count=$1;}
	}
	if ( $debug == 1 ) {
                print "------------------------\n";
                print "Logged in users on system\n";
                print "  users    $user_count\n";
                }
	#push(@perf_output,"logged_in_users="."$user_count");
        FNO::addPerfdata( { Name => "logged_in_users", Value => $user_count });
		$count_perfvalues++;
} else {
#push(@nagios_output,"Warning - command '/usr/bin/who' does not exists on system MsgG=OSS <!-- Obj=check_linux_performance MsgG=OSS Sev=Warning -->\n");
FNO::add({ Summary => "command '/usr/bin/who' does not exists on system",
                        Severity => "Warning",
                        AlertGroup => "NAGIOS",
                        AlertKey => "check_linux_performance",
                        MsgGroup => "OSS",
			Type => "NAA"
        });
}
# Sleeping, Zombies and running procs
if ( -x '/bin/ps' ) {
	@ps=`/bin/ps -efl`;
		foreach $line (@ps) {
			next if ( $line=~/^F/i );
			if ( $line=~/\d+\s+R/i ) { $count_proc_running++;}
			if ( $line=~/\d+\s+S/i ) { $count_proc_sleep++;}
			if ( $line=~/\d+\s+D/i ) { $count_proc_iowait++;}
			if ( $line=~/\d+\s+Z/i ) { $count_proc_zombie++;}
		}
	if ( $debug == 1 ) {
		print "------------------------\n";
		print "Process Statistic\n";
		print "  Running        $count_proc_running\n";
		print "  Sleeping       $count_proc_sleep\n";
		print "  IO_Wait        $count_proc_iowait\n";
		print "  Zombies        $count_proc_zombie\n";
		}
	#push(@perf_output,"procs_running="."$count_proc_running","procs_sleeping="."$count_proc_sleep","procs_IOwait="."$count_proc_iowait","procs_zombies="."$count_proc_zombie");
        FNO::addPerfdata( { Name => "procs_running", Value => $count_proc_running });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "procs_sleeping", Value => $count_proc_sleep });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "procs_IOwait", Value => $count_proc_iowait });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "procs_zombies", Value => $count_proc_zombie });
		$count_perfvalues++;
} else {
#push(@nagios_output,"Warning - command '/bin/ps' does not exists on system MsgG=OSS <!-- Obj=check_linux_performance MsgG=OSS Sev=Warning -->\n");
	FNO::add({ Summary => "command '/bin/ps' does not exists on system",
                        Severity => "Warning",
                        AlertGroup => "NAGIOS",
                        AlertKey => "check_linux_performance",
                        MsgGroup => "OSS",
                        Type => "NAA"
        });
}

# Monitroing for packet errors
# 27.12.2016 oleinial, adaptation to exclude the packet_received_errors and packet_reassembles_failed by using exlcude_packet_errors command
if ( $exclude_option=~/exlcude_packet_errors/ ) {
    } else {
	$packet_reassembles_failed=`/bin/netstat -s |grep "packet reassembles failed"`; chomp $packet_reassables_failed;
	$packet_received_errors=`/bin/netstat -s |grep "packet receive errors"`; chomp $packet_received_errors;
	$TMP_error_file='/appl/nagios/var/packet_errors.tmp';

	if ($packet_reassembles_failed=~/(\d+)/ ) {
        $packet_reassembles_failed=$1;
	} else {
        $packet_reassembles_failed=0;
	}

	if ($packet_received_errors=~/(\d+)/ ) {
        $packet_received_errors=$1;
	} else {
        $packet_received_errors=0;
	}

	# Read old data from packet_errors.tmp file
	if ( -w  "$TMP_error_file" ) {
        @TMP_data=`cat $TMP_error_file`;
                foreach $line (@TMP_data) {
                        if ( $line=~m/time=(\d+)/ ) {$time_old=$1 };
                        if ( $line=~m/(\d+)\s::\s(\d+)/ ) {$file_packet_reassembles_failed=$1;$file_packet_received_errors=$2 };
                }
	}
	else {
#	print "Seems to be the first polling of packet errors. No data available\n";
	}

	open(FILE, ">$TMP_error_file");
	$time=time;
	print FILE "time=$time\n";
	print FILE "# packet reassembles failed::packet receive errors\n";
	print FILE "$packet_reassembles_failed :: $packet_received_errors\n";

	$diff_time=$time - $time_old;

	$diff_packet_received_errors=$packet_received_errors-$file_packet_received_errors;
	$diff_packet_reassembles_failed=$packet_reassembles_failed-$file_packet_reassembles_failed;
	#push(@perf_output,"packet_received_errors="."$diff_packet_received_errors","packet_reassembles_failed="."$diff_packet_reassembles_failed");
        FNO::addPerfdata( { Name => "packet_received_errors", Value => $diff_packet_received_errors });
		$count_perfvalues++;
        FNO::addPerfdata( { Name => "packet_reassembles_failed", Value => $diff_packet_reassembles_failed });
		$count_perfvalues++;

	#if ( $diff_packet_received_errors > 0 ) {
	##push(@nagios_output,"Warning - Found $diff_packet_received_errors packet_received_errors within $diff_time seconds MsgG=$msgg <!-- Obj=packet_received_errors MsgG=$msgg Sev=Warning Type=NAA -->\n");
	#FNO::add({   Summary => "Found $diff_packet_received_errors packet_received_errors within $diff_time seconds",
        #        Severity => "Warning",
        #        AlertGroup => "NAGIOS",
        #        AlertKey => "packet_received_errors",
        #        MsgGroup => $msgg,
        #        Type => "NAA"
        #});
	#} 

	if ( $diff_packet_reassembles_failed > 0 ) {
	#push(@nagios_output,"Critical - Found $diff_packet_reassembles_failed  packet_reassembles_failed  within $diff_time seconds MsgG=$msgg <!-- Obj=packet_reassembles_failed MsgG=$msgg Sev=Critical Type=NAA -->\n");
	FNO::add({   Summary => "Found $diff_packet_reassembles_failed  packet_reassembles_failed within $diff_time seconds",
                Severity => "Critical",
                AlertGroup => "NAGIOS",
                AlertKey => "packet_reassembles_failed",
                MsgGroup => $msgg,
                Type => "NAA"
        });
	}
}

sub cpu_usage_monitoring {
	my $start_time=`date -d '1 hour ago' "+%H:%M:%S"`;
	chomp($start_time);
	my $end_time=`date +"%T"`;
	chomp($end_time);
	my $idle_threshold = 5;

	my @perfdata=`sar -s $start_time -e $end_time | sed "1,2 d"`;
	#my @perfdata=`sar -s 07:00:00 -e 08:00:00 | sed "1,2 d"`;
	my $flag=0;
	my $count_idle=0;

	foreach $entry (@perfdata) {
	        chomp $entry;
	        my @data = split /  */, $entry;
	        my @headline = split /  */, $perfdata[0];
	        my $counter = scalar @data-1;
	
	        foreach my $k (0 .. $counter) {
	                #print "$headline[$k] => $data[$k]\n";
	                if ($headline[$k] eq "%idle"){
	                        $count_idle++;
	                        if ($data[$k] < $idle_threshold ) {
	                                $flag++;
	                        }else{
	                        }
	                }else {
	                }
	        }
	}
	
	if($count_idle > 3) {
        	my $cpu_usage = (100 - $idle_threshold);
        	if ($flag == $count_idle) {
        	        FNO::add({ Summary => "CPU usage was over $cpu_usage% within the last 60 minutes!",
        	                   Severity => "Warning",
        	                   AlertGroup => "System",
        	                   AlertKey => "meltdown",
        	                   MsgGroup => $msgg
        	        });
        	}else {
        	        FNO::add({ Summary => "CPU usage is below $cpu_usage% within the last 60 minutes!",
        	                   Severity => "Normal",
        	                   AlertGroup => "System",
        	                   AlertKey => "meltdown",
        	                   MsgGroup => $msgg
        	        });
        	}
	} else {
        	FNO::addText("Minimum 1 hour of data is required!");
	}
}

#print "Checked $count_perfvalues performance values\n"; print @nagios_output; print "|";
#print "@perf_output\n";
if ( $output=~m/Sev=Critical/i ) { exit 2; }
if ( $output=~m/Sev=Warning/i ) { exit 1; }
if ( $output=~m/Sev=Info/i ) { exit 4; }

FNO::set('printCustomHeader',"Checked $count_perfvalues performance values");
my $returnCode = &FNO::print();
&FNO::printPerfdata;
exit $returnCode;
# If all is ok exit with OK status
exit 0;
