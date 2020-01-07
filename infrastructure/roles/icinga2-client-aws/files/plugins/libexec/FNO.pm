#!/appl/nagios/perl/bin/perl
package FNO; # Module FNP Formated Nagios Output
use strict;
use Exporter;
use Digest::MD5 qw(md5_hex);;
use Time::HiRes;
use File::Basename;

######## List of global constants ########
use constant {
        NORMAL          => 0,
        WARNING         => 2,
        MINOR           => 3,
        MAJOR           => 4,
        CRITICAL        => 5,
        LOG_CRIT        => 1,
        LOG_ERR         => 2,
        LOG_WARN        => 3,
        LOG_NOTICE      => 4,
        LOG_INFO        => 5,
        LOG_DEBUG       => 6
};

######## List of global variables ########
use vars qw(
	%DEFAULTS
	%DEFAULTS_CORE
	%DEFAULTS_VERSION_0
	%DEFAULTS_VERSION_2
	%PERFDATA
	%G_LONGOUTPUT
	%G_PERFDATA
	%OPTIONS
	$pid
	%convert
	@exitCode
	@LOG_ERRORS
	$basename
	$eventId
	$outputOrderNr
	$perfdataId
	$eventCount
	$error
	$isLogFileOpen
	$errMsgText
	$pluginExecutionTime
	$VERSION @ISA @EXPORT @EXPORT_OK 
);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(add addLine addPerfdata addText set print printPerfdata maxSeverity minReturnCode changeDefault addMsgGroups setSortOption setErrMsgGroup setLogging defaults);
@EXPORT_OK   = qw(add addLine addPerfdata addText set print printPerfdata maxSeverity minReturnCode changeDefault addMsgGroups setSortOption setErrMsgGroup setLogging defaults);
$pid         = $$;
$basename    = basename($0);

#START TIMER for plugin execution time measurement counter
$pluginExecutionTime = [ Time::HiRes::gettimeofday() ];

#Lookup definitions
my %SEVERITY = ( 0  => 'Normal',
              2  => 'Warning',
              3  => 'Minor',
              4  => 'Major',
              5  => 'Critical'
            );

my %LOG_ERRORS=( 1=>'Critical',
          2=>'Error',
          3=>'Warning',
          4=>'Notice',
          5=>'Info',
          6=>'Debug'
);

%OPTIONS = (
	OutputVersion => 	{ default => 2, 		current => 2, allowedValues => [qw(0 1 2)] },
	printOrder => 		{ default => 'bySeverity', 	current => 'bySeverity', allowedValues => [qw(bySeverity byOrderNumber byOccurrence)] },
	printHashCalcMethod => 	{ default => 'complete', 	current => 'complete', allowedValues => [qw(complete onHiddenFields)] },
	printFormat => 		{ default => 'short', 		current => 'short', allowedValues => [qw(short long original)] },
	printCustomHeader => 	{ default => '', 		current => '', allowedValues => [qw(ANYSTRING)] },
	printPerfdata => 	{ default => 'yes', 		current => 'yes', allowedValues => [qw(yes no)] },
	ErrorMessageGroup => 	{ default => 'ENG-OSS', 	current => 'ENG-OSS', allowedValues => [qw(ANYSTRING)] },
	LogLevel => 		{ default => 0, 		current => 0, allowedValues => [qw(0 1 2 3 4 5 6)] },
	LogDestination => 	{ default => 'STDERR', 		current => 'STDERR', allowedValues => [qw(STDERR ANYSTRING)] },
	MaxSeverity =>  	{ default => 5, 		current => 5, allowedValues => [qw(0 2 3 4 5)] },
	MinReturnCode => 	{ default => 0, 		current => 0, allowedValues => [qw(0 1 2)] },
	ignoreDuplicates => 	{ default => 'false', 		current => 'false', allowedValues => [qw(true false)] },
	Graph_PluginExecutionTime => { default => 'no', 	current => 'no', allowedValues => [qw(yes no)] },
	Graph_Name => 		{ default => 'PET_<PLUGINNAME>',current => 'PET_<PLUGINNAME>', allowedValues => [qw(ANYSTRING <PLUGINNAME>)] },
	Graph_Unit => 		{ default => 'sec', 		current => 'sec', allowedValues => [qw(sec)] }
);

%DEFAULTS_VERSION_0 = (
	"AlertGroup|ag|Application|App" => { mandatory => 'yes', validateLength => 'yes', maxLength => 255},
	"AlertKey|ak|Object|Obj" => { mandatory => 'yes', validateLength => 'yes', maxLength => 255 },
	"MsgGroup|mg|MESSAGE_GROUP|MsgG" => { mandatory => 'yes', validateLength => 'yes', maxLength => 64, validateValues => 'no', 0 => 'ENG-OSS' },
	"Node|n|Node" => { mandatory => 'no', validateLength => 'yes', maxLength => 128 },
	"Command" => {mandatory => 'no', maxLength => 255 },
	"Dup" => {mandatory => 'no', maxLength => 255 },
	"Email|em|Email" => { mandatory => 'no', maxLength => 2048 },
	"ForceResend|fr|ForceResend" => { mandatory => 'no', validateLength => 'no', validateValues => 'yes', maxLength => 'Integer', convertValueToNumber => 'no', 1 => 'true' },
	"HelpKey|hk|InstrId" => { mandatory => 'no', validateLength => 'yes', maxLength => 255 },
	"Key" => {mandatory => 'no', maxLength => 255 },
	"Pattern" => {mandatory => 'no', maxLength => 255 },
	"Pattern2" => {mandatory => 'no', maxLength => 255 },
	"Source" => {mandatory => 'no', maxLength => 255 },
	"Sn" => {mandatory => 'no', maxLength => 255 },
	"Text" => {mandatory => 'no', maxLength => 255 },
	"Text2" => {mandatory => 'no', maxLength => 255 },
	"Thresh" => {mandatory => 'no', maxLength => 255 },
	"Tresh" => {mandatory => 'no', maxLength => 255 },
        "Type|tp|Type" => { mandatory => 'no', validateValues => 'yes', convertValueToNumber => 'no',
                  0  => 'not defined',
                  1  => 'Problem',
                  2  => 'Resolution',
                  13  => 'Information',
                  14  => 'NAA'
                 }
);
%DEFAULTS_VERSION_2 = (
	"AlertGroup|App|Application|ag" => { mandatory => 'yes', validateLength => 'yes', maxLength => 255},
	"AlertKey|Obj|Object|ak" => { mandatory => 'yes', validateLength => 'yes', maxLength => 255 },
	"Email|em" => { mandatory => 'no', maxLength => 2048 },
	"MsgGroup|MsgG|MESSAGE_GROUP|mg" => { mandatory => 'yes', validateLength => 'yes', maxLength => 64, validateValues => 'no', 0 => 'ENG-OSS' },
	"Node|n" => { mandatory => 'no', validateLength => 'yes', maxLength => 128 },
	"ForceResend|fr" => { mandatory => 'no', validateLength => 'no', validateValues => 'yes', maxLength => 'Integer', convertValueToNumber => 'yes', 1 => 'true' },
	"HelpKey|InstrId|hk" => { mandatory => 'no', validateLength => 'yes', maxLength => 255 },
	"Key" => {mandatory => 'no', maxLength => 255 },
        "Type|tp" => {
		  validateValues => 'yes',
		  convertValueToNumber => 'yes',
                  0  => 'not defined',
                  1  => 'Problem',
                  2  => 'Resolution',
                  13  => 'Information',
                  14  => 'NAA'
                 }
);
%DEFAULTS_CORE = (
	"ARSGroup|asg" => { mandatory => 'no', maxLength => 256 },
	"ARSNotes|asn" => { mandatory => 'no', validateLength => 'yes', maxLength => 3000 },
	"ARSOpCat1|as1" => { mandatory => 'no', validateLength => 'yes', maxLength => 64 },
	"ARSOpCat2|as2" => { mandatory => 'no', validateLength => 'yes', maxLength => 64 },
	"ARSOpCat3|as3" => { mandatory => 'no', validateLength => 'yes', maxLength => 64 },
	"ARSSubmitter|ass" => { mandatory => 'no', validateLength => 'yes', maxLength => 64 },
	"ARSUrgency|asu" => { validateValues => 'yes', convertValueToNumber => 'yes', 1000 => 'Critical', 2000 => 'High', 4000 => 'Low', 3000 => 'Medium' },
	"CIId|ci" => { mandatory => 'no', validateLength => 'yes', maxLength => 128 },
	"Class|cl" => { 
		  validateValues => 'no',
		  300 => 'MTTrapd',
		  301 => 'general RAN Alarm',
		  302 => '2G',
		  303 => '3G',
		  304 => '4G',
		  305 => 'Repeater',
		  306 => 'Powerbox',
		  307 => 'Transmission link',
		  308 => 'DWDM',
		  309 => 'UPC Alarmboard',
		  310 => 'L3 Switch',
		  311 => 'RAD Converter',
		  312 => 'MTM Board',
		  313 => 'IT Server'
		},
	"Delay|dy" => { mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"EMSAlarmId|aid" => { mandatory => 'no', maxLength => 64 },
	"EventId|eid" => { mandatory => 'no', maxLength => 255 },
	"EquipmentType|eqt" => { mandatory => 'no', validateLength => 'yes', maxLength => 50 },
	"ExpireTime|et" => { mandatory => 'no', maxLength => 'Integer' },
	"ExtendedAttr|ea" => { mandatory => 'no', maxLength => 4096 },
	"ForceResend|fr" => { mandatory => 'no', validateLength => 'no', validateValues => 'yes', maxLength => 'Integer', convertValueToNumber => 'yes', 1 => 'true' },
	"Location|lo" => { mandatory => 'no', validateLength => 'yes', maxLength => 32 },
	"NEFirstOccurrence|nfo" => { mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"NEIPAddress|ne" => { mandatory => 'no', validateLength => 'yes', maxLength => '64' },
	"OnCall|oc" => { mandatory => 'no', validateLength => 'yes', maxLength => 32 },
	"Poll|po" => { mandatory => 'no', maxLength => 'Integer' },
	"ProcessReq|pr" => { mandatory => 'no', maxLength => 'Integer' },
	"Report|rep" => { mandatory => 'no', maxLength => 1024 },
        "Severity|Sev" => { mandatory => 'yes', validateValues => 'yes',
		  convertValueToNumber => 'yes',
                  0  => 'Normal',
                  2  => 'Warning',
                  3  => 'Minor',
                  4  => 'Major',
                  5  => 'Critical'
                 },
	SMS => { mandatory => 'no', maxLength => 1024 },
	"Summary|sum" => { mandatory => 'yes', maxLength => 1024 },
        "SuppressEscl|se" => {
		  validateValues => 'yes',
		  convertValueToNumber => 'yes',
                  0 => 'Normal',
                  20 => 'Hidden from NOC',
                  23 => 'LogOnly'
                 },
	"Technology|te" => { mandatory => 'no', validateLength => 'yes', maxLength => 32, 
		  validateValues => 'yes',
		  convertValueToNumber => 'no',
		  0 => '2G',
		  1 => '3G',
		  2 => 'LTE',
		  3 => '2G,3G',
		  4 => '2G,LTE',
		  5 => '3G,LTE',
		  6 => '2G,3G,LTE'
 		},
	URL => { mandatory => 'no', maxLength => 1024 },
	"Notification" => {mandatory => 'no', maxLength => 255 },
	"TextOnly" => {mandatory => 'no', maxLength => 2048 },
	"OutputOrderNr|oon" => { mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"ValueChangedEvent|vce" => { mandatory => 'no', validateLength => 'yes', maxLength => 128 },
	"Version|v" => { mandatory => 'no', validateValues => 'yes', maxLength => 'Integer' }
     );


%PERFDATA = (
	"Name|PERF_NAME" => { mandatory => 'yes', maxLength => 64},
	"Value|PERF_VALUE" => { mandatory => 'yes', validateLength => 'yes', maxLength => 'Integer' },
	"Unit|PERF_UNIT" => { mandatory => 'no', validateLength => 'yes', validateValues => 'no', maxLength => 32 },
	"PerfWarn|PERF_WARNING" => {mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"PerfCrit|PERF_CRITICAL" => {mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"PerfMin|PERF_MIN" => {mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' },
	"PerfMax|PERF_MAX" => {mandatory => 'no', validateLength => 'yes', maxLength => 'Integer' }
);

$eventId=10000;
$outputOrderNr=0;
$perfdataId=0;
$errMsgText="";

&set('OutputVersion',2);
sub setErrMsgGroup {
	my $param=shift;
	&set('ErrorMessageGroup',$param);
	$error++;
	my $text="The function 'setErrMsgGroup' is deprecated, use the 'set' function instead!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
}

sub setSortOption {
	my $param=shift;
	&set('printOrder',$param);
	$error++;
	my $text="The function 'setSortOption' is deprecated, use the 'set' function instead!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
}

sub set {
	my $option = shift;
	my $value = shift;
	#THIS DEUBUG MY NOT WORK BECAUSE PER DEFAULT THE LOGGING IS DISABLED. Either use a print or change the current within the plugin...
	log_msg(LOG_DEBUG,"Option Change Requested: Option: '$option' new value: '$value'. ");
	#print "\nOption Change Requested: Option: '$option' new value: '$value'. \n\n";
	
	#check if argument is a hash...
	if(ref($option) eq 'HASH') {
		my %newOptionHash=%{$option};
		foreach my $newOption ( keys %newOptionHash) {
			$option = $newOption;
			$value = $newOptionHash{$newOption};
			
			#call me again but not with a hash...
			&set($option,$value);
		}
	} else {
		my $optionFound=0;
		foreach my $opt (keys %OPTIONS) {
			# we don't care option can be also case insensitive
			#log_msg(LOG_DEBUG,"Given/Requested Option: '$option', available option: '$opt' ");
			#print "Given/Requested Option: '$option', available option: '$opt'\n";
			if ( $opt=~m/(?:^|\|)$option(?=\||$)/i ) {
				$optionFound=1;
				#validate values
				my $isOptionValid=0;
				foreach my $allowedValue (@{$OPTIONS{$opt}{'allowedValues'}}) {
					if ( $allowedValue eq 'ANYSTRING' ) {
						$isOptionValid=1;
					} elsif ( $allowedValue eq 'ANYNUMBER' && $value!~/^\d+$/ ) {
						$error++;
						my $text="Value of Option '$option' must be a number!; ";
						if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
					} elsif ( $allowedValue eq $value ) {
						$isOptionValid=1;
					}
				}
				if ( $value eq "reset_to_default" ) {
					$OPTIONS{$opt}{'current'} = $OPTIONS{$opt}{'default'};
				} elsif ( $isOptionValid == 0 ) {
					$error++;
					my $text="Value '$value' of Option '$option' is not supported!; ";
					if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
				} else {
					#set new Option
					$OPTIONS{$opt}{'current'} = $value;
				}
				log_msg(LOG_NOTICE,"The option '$opt' is set to '$OPTIONS{$opt}{'current'}' (Default is: '$OPTIONS{$opt}{'default'}'.");
			} 
		}
		if ( $optionFound == 0 ) {
			$error++;
			my $text="SetOption '$option' is not supported!; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
	}

	if ( $OPTIONS{'OutputVersion'}{'current'} == 0 ) {
		%DEFAULTS=(%DEFAULTS_CORE,%DEFAULTS_VERSION_0);
	}
	else {
		%DEFAULTS=(%DEFAULTS_CORE,%DEFAULTS_VERSION_2);
	}
	
}

sub defaults {
	print "\n\nDefault hidden field keys:\n";
	print "||'''Name (long) '''||'''Name (short) '''||'''Name (alternative) '''||'''Mandatory '''||'''maxLength '''||'''validateLength '''||'''validateValues '''||'''convertValueToNumber '''||'''allowedValues '''||\n";
	foreach my $defaultKey (sort keys %DEFAULTS) {
		my @KEYS=split (/\|/, $defaultKey);
		my $long=shift @KEYS;
		my $short=pop @KEYS;
		my $alternatives= join("|", @KEYS);
		my $allowedValues="''";
		foreach my $validKey (sort keys %{$DEFAULTS{$defaultKey}}) {
			if ( $validKey=~/\d+/ ) {
				$allowedValues.="$validKey|$DEFAULTS{$defaultKey}{$validKey}|";
			}
		}
		$allowedValues=~s/\|$/''/g;
		$allowedValues=~s/^''$//g;
		print "||$long ||$short ||$alternatives ||$DEFAULTS{$defaultKey}{mandatory} ||$DEFAULTS{$defaultKey}{maxLength} ||$DEFAULTS{$defaultKey}{validateLength} ||$DEFAULTS{$defaultKey}{validateValues} ||$DEFAULTS{$defaultKey}{convertValueToNumber} ||$allowedValues ||\n";
	}
	print "\n\nDefault perfdata keys:\n";
	print "||'''Name'''||'''Mandatory '''||'''maxLength '''||'''validateLength '''||'''validateValues '''||'''convertValueToNumber '''||'''allowedValues '''||\n";
	foreach my $defaultKey (sort keys %PERFDATA) {
		my @KEYS=split (/\|/, $defaultKey);
		my $long=shift @KEYS;
		my $short=pop @KEYS;
		my $alternatives= join("|", @KEYS);
		my $allowedValues="''";
		foreach my $validKey (sort keys %{$PERFDATA{$defaultKey}}) {
			if ( $validKey=~/\d+/ ) {
				$allowedValues.="$validKey|$PERFDATA{$defaultKey}{$validKey}|";
			}
		}
		$allowedValues=~s/\|$/''/g;
		$allowedValues=~s/^''$//g;
		print "||$long ||$PERFDATA{$defaultKey}{mandatory} ||$PERFDATA{$defaultKey}{maxLength} ||$PERFDATA{$defaultKey}{validateLength} ||$PERFDATA{$defaultKey}{validateValues} ||$PERFDATA{$defaultKey}{convertValueToNumber} ||$allowedValues ||\n";
	}
	print "\n\nSet Options:\n";
	print "||'''Option'''||'''Default'''||'''Current'''||'''Allowed Values'''||\n";
	foreach my $defaultKey (sort keys %OPTIONS) {
		my $allowedValues = join("|", @{$OPTIONS{$defaultKey}{'allowedValues'}} );
		print "||$defaultKey||$OPTIONS{$defaultKey}{'default'} ||$OPTIONS{$defaultKey}{'current'} ||\'\'$allowedValues\'\' ||\n";
	}
}
sub addMsgGroups {
	my $msgg = shift;
	my @groups = split ( /,/, $msgg);
	my $id=0;
	my $MsgGKey="";
	foreach my $defaultKey (keys %DEFAULTS) {
		if ( $defaultKey=~m/(?:^|\|)MsgGroup(?=\||$)/i ) {
			$MsgGKey=$defaultKey;
		}
	}
			
	foreach my $group (@groups) {
		chomp($group);
		$group=~s/\s+//g;
		$DEFAULTS{$MsgGKey}{$id}=$group;
		$id++
	}

	$DEFAULTS{$MsgGKey}{'validateValues'}='yes';
}
sub changeDefault {
	my $field=shift;
	my $option=shift;
	my $value=shift;
	foreach my $defaultKey (keys %DEFAULTS) {
		#if pluginKey is found
		if ( $defaultKey=~m/(?:^|\|)$field(?=\||$)/i ) {
			foreach my $validKey (keys %{$DEFAULTS{$defaultKey}}) {
				if ($validKey eq $option) {
					$DEFAULTS{$defaultKey}{$validKey}=$value;
				}
			}
		}
	}
}
sub minReturnCode {
	my $param=shift;
	&set('MinReturnCode',$param);
	$error++;
	my $text="The function 'maxSeverity' is deprecated, use the 'set' function instead!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
	
}
sub maxSeverity {
	my $param=shift;
	&set('MaxSeverity',$param);
	$error++;
	my $text="The function 'maxSeverity' is deprecated, use the 'set' function instead!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
}
sub setLogging {
	my $debuglevel=shift;
	my $logfile=shift;
	&set('LogLevel',$debuglevel);
	&set('LogDestination',$logfile);
	$error++;
	my $text="The function 'setLogging' is deprecated, use the 'set' function instead!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
}

sub addText {
	my $text=shift;
	my $oon=shift;

	log_msg(LOG_INFO,"Given Parameters: \$text: -$text- \$oon: -$oon-\n");
	if(ref($text) eq 'ARRAY') {
		foreach my $line (@{$text}) {
			log_msg(LOG_INFO,"Line of ARRAY: -$line-\n");
			&addText($line);
		}
	} else {
		$eventId++;
		if ($oon && $oon != 0 ) {
			if ($oon!~/^\d+$/ || $oon <= 0) {
				$error++;
				my $text="OutputOrderNr must be a number greater then 0!; ";
				if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
			}
			if (exists $G_LONGOUTPUT{$oon} ) {
				$error++;
				my $text="OutputOrderNr '$oon' already exists!; ";
				if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
			}
			$eventId = $oon;
		}
		$G_LONGOUTPUT{$eventId}{'TextOnly'}{'pluginKeyName'} = "TextOnly";
		$G_LONGOUTPUT{$eventId}{'TextOnly'}{'shortKeyName'} = "TextOnly";
		$G_LONGOUTPUT{$eventId}{'TextOnly'}{'value'} = $text;
	}
}
sub addLine {
	my $line=shift;
	my %alarmMessage=();
	#(<Sev> - )<Text> <!-- [<Key>=<Value>]... -->
	#Warning - %s (20times in 15min) <!-- AlertKey=$0 MsgGroup=ENG-OSS AlertGroup=NAGIOS Sev=Warning -->
	if ( $line=~/(.*)<!--(.*)-->/) {
		my $text=$1;
                my $hidden_line=$2;
		if ( $text=~/(\w+)\s+-\s+(.*)/ ) {
			$text=$2;
		}
		$alarmMessage{'Summary'}=$text;
		log_msg(LOG_INFO,"LINE: -$line-");
		my $text_qualifier="('|\")";
		#while ( $hidden_line =~ /(\w+)=('[^']+'|\S+)/g ) {
		while ( $hidden_line =~ /(\w+)=($text_qualifier[^$text_qualifier]+$text_qualifier|\S+)/g ) {
			my $key=$1;
			my $value=$2;
			$alarmMessage{$key}=$value;
			log_msg(LOG_DEBUG,"Key: $key Value: $value");
		}
	}
	&add(\%alarmMessage);
}

sub addPerfdata {
	my %hash = %{shift()};
	my @Duplicate=(); #Store Counter names 
	$perfdataId++;

	#check mandatory keys are missing....
	foreach my $defaultKey (keys %PERFDATA){
		my $mandatory=$PERFDATA{$defaultKey}{'mandatory'};
		my $keyexists=0;
		if ( $mandatory eq "yes") {
			#check all alternatives incasesensitive
			foreach my $key (keys %hash) { if ( $defaultKey=~m/(?:^|\|)$key(?=\||$)/i ) { $keyexists=1; } }
		}
		if ($keyexists == 0 && $mandatory eq "yes") {
			$error++;
			my $text="Mandatory perfdata field '$defaultKey' is missing; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
	}
	
	#check if perfdataKey is supported and valid....
    	while ( my ( $perfdataKey, $value ) = each %hash) {
		my @Duplicate=(); #Store perfdata names
		my $isSupported=1;
		my $isValid=1;
		my $ourKey=$perfdataKey; # is the first word of the perfdataKey as defined in the hash with "|" E.g. "Severity|Sev|Se" --> ourKey='Severity'
		foreach my $defaultKey (keys %PERFDATA) {
			#if perfdataKey is found
			if ( $defaultKey=~m/(?:^|\|)$perfdataKey(?=\||$)/i ) { 
				$isSupported=0; 
				$ourKey=$defaultKey;
				$ourKey=~s/^(\w+)(\||$).*/$1/g;
				if ( $ourKey eq 'Name' ) { $Duplicate[0]=$value; }
				if ( exists $PERFDATA{$defaultKey}{'validateValues'} and $PERFDATA{$defaultKey}{'validateValues'} eq "yes" ) {
					foreach my $validKey (keys %{$PERFDATA{$defaultKey}}) {
						if ( $validKey=~/^\d+$/ ) {
							if ( (lc($value) eq lc($validKey)) || (lc($value) eq lc($PERFDATA{$defaultKey}{$validKey}) ) ) { 
								$isValid=0; #yes it's valid
								#There is no need to have the full text in the hidden fields
								#E.g.: do Sev=Warning --> Sev=1
								if ( $PERFDATA{$defaultKey}{'convertValueToNumber'} eq 'yes' ) {
									$value=$validKey;
								}
							}
						}
					}	
				} else  {
					#if validateValues is not yes it's valid ;-)
					$isValid=0;
				}
				#Validate Length
				if ( exists $PERFDATA{$defaultKey}{'validateLength'} and $PERFDATA{$defaultKey}{'validateLength'} eq 'yes' ) {
					if ( $value!~/^-?(?:\d+(?:\.\d*)?|\.\d+)$/ and $PERFDATA{$defaultKey}{'maxLength'} eq 'Integer' ) {
						$error++;
						log_msg(LOG_WARN, "The perfdata key '$perfdataKey' must be a number!; ");
						log_msg(LOG_WARN, "Received Value (encapsulated in '-'): -$value- maxLength Setting: $PERFDATA{$defaultKey}{'maxLength'} ");

						my $text = "The perfdata key '$perfdataKey' must be a number. (Value='$value'); ";
						if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
					}
					if ( $PERFDATA{$defaultKey}{'maxLength'}=~/^\d+/ and length($value) > $PERFDATA{$defaultKey}{'maxLength'} ) {
						$error++;
						my $text = "Lenght of perfdata '$perfdataKey' is longer than $PERFDATA{$defaultKey}{'maxLength'}; ";
						if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
					}
				}
				
			}
		}
		if ( $isSupported == 1 ) {
			$error++;
			my $text = "Perfdata Key '$perfdataKey' is not supported; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
		#print validation errors only if field is supported...
		if ( $isValid == 1 && $isSupported == 0) {
			$error++;
			my $text = "Perfdata value '$value' of Key '$perfdataKey' is not supported; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
		#Check duplicate counter names
		if ($Duplicate[0] && $perfdataKey eq 'Name') {
			my $found=0;
			foreach my $counter (keys %G_PERFDATA) {
				if ( exists $G_PERFDATA{$counter}{'Name'}{'value'} and "$G_PERFDATA{$counter}{'Name'}{'value'}" eq "$Duplicate[0]" && $found == 0 ) {
					$found=1;
					log_msg(LOG_INFO, "new counter Name '$G_PERFDATA{$counter}{'Name'}{'KeyName'}' existing Name '$Duplicate[0]'");
					$error++;
					my $text = "Duplicate performance counter names are not supported; ";
					if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
				}
			}
		}
		$G_PERFDATA{$perfdataId}{$ourKey}{'KeyName'} = $ourKey;
		chomp($value); $value=~s/\n/ /g; $value=~s/\r/ /g; 
		$G_PERFDATA{$perfdataId}{$ourKey}{'value'} = $value;
	}
}

sub add {
	my %hash = %{shift()};
	my $returnValue;
	$eventId++;

	#override eventID in case the order is set handled in the plugin
	while ( my ( $pluginKey, $value ) = each %hash) {
		if ( $pluginKey=~/(OutputOrderNr|oon)/i ) {
			#override order setting
			&set('printOrder','byOrderNumber');
			if ($value!~/^\d+$/ || $value <= 0) {
				$error++;
				my $text="OutputOrderNr must be a number greater then 0!; ";
				if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
			}
			if (exists $G_LONGOUTPUT{$value} ) {
				$error++;
                        	my $text="OutputOrderNr '$value' already exists!; ";
                        	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
			}
			$eventId=$value;
		}
	}

	#check mandatory keys are missing....
	foreach my $defaultKey (keys %DEFAULTS){
		my $mandatory=$DEFAULTS{$defaultKey}{'mandatory'};
		my $keyexists=0;
		if (  $mandatory && $mandatory eq "yes") {
			#check all alternatives incasesensitive
			foreach my $key (keys %hash) { if ( $defaultKey=~m/(?:^|\|)$key(?=\||$)/i ) { $keyexists=1; } }
		}
		if ($mandatory && $keyexists == 0 && $mandatory eq "yes") {
			$error++;
			my $text="Mandatory field '$defaultKey' is missing; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
	}
	
	my @Duplicate=(); #Store AlertGroup and AlertKey values
	my $checked = 0;
	#check if pluginKey is supported and valid....
    	while ( my ( $pluginKey, $value ) = each %hash) {
		my $isSupported=1;
		my $isValid=1;
		my $ourKey=$pluginKey; # is the first word of the pluginKey as defined in the hash with "|" E.g. "Severity|Sev|Se" --> ourKey='Severity'
		my $shortKey=$pluginKey; # is the last word of the pluginKey as defined in the DEFAULTS hash. E.g. "Severity|Sev|Se" --> shortKey='Se'
		
		# fields with blanks are always enclosed with ". eg: AlertKey="One Key" (not supported: AlertKey='One Key')
		log_msg(LOG_DEBUG, "ORIGINAL: $pluginKey: -$value-");
		if ($OPTIONS{'OutputVersion'}{'current'} > 0 ) { 
			$value=~s/"/'/g; 						# 1. Replace all " with '
			if ( $value=~/(\s|')/ && ($value!~/^'/ || $value!~/'$/) ) {		# 2. if whitespace --> surround it with "
				$value='"' . $value . '"';
			} elsif ( $value=~/^'/ && $value=~/'$/ && $value!~/'.*(\s|').*'/ ) { # 3. no need to surround value if it doesn't contain whitespace,= or '
				$value=~s/^'//g;
				$value=~s/'$//;
			}
			$value=~s/^'/"/; $value=~s/'$/"/;				# 4. Replace the beginn and end "'" with """
		} else {
			$value=~s/'/"/g; 						# 1. Replace all " with '
			if ( $value=~/(\s|")/ && ($value!~/^"/ || $value!~/"$/) ) {		# 2. if whitespace --> surround it with "
				$value="'" . $value . "'";
			} elsif ( $value=~/^"/ && $value=~/"$/ && $value!~/".*(\s|").*"/ ) { # 3. no need to surround value if it doesn't contain whitespace,= or '
				$value=~s/^"//g;
				$value=~s/"$//;
			}
			$value=~s/^"/'/; $value=~s/"$/'/;				# 4. Replace the beginn and end "'" with """
		}
		log_msg(LOG_DEBUG, "CONVERTED: $pluginKey: -$value-");
		foreach my $defaultKey (keys %DEFAULTS) {
			#if pluginKey is found
			if ( $defaultKey=~m/(?:^|\|)$pluginKey(?=\||$)/i ) { 
				$isSupported=0; 
				$ourKey=$defaultKey;
				$ourKey=~s/^(\w+)(\||$).*/$1/g;
				if ( $ourKey eq 'AlertGroup' ) { $Duplicate[0]=$value; }
				if ( $ourKey eq 'AlertKey' ) { $Duplicate[1]=$value; }


				$shortKey=$defaultKey;
				$shortKey=~s/^.*?(\w+)$/$1/g;
				if ( exists $DEFAULTS{$defaultKey}{'validateValues'} && $DEFAULTS{$defaultKey}{'validateValues'} eq "yes" ) {
					foreach my $validKey (keys %{$DEFAULTS{$defaultKey}}) {
						if ( $validKey=~/^\d+$/ ) {
							if ( (lc($value) eq lc($validKey)) || (lc($value) eq lc($DEFAULTS{$defaultKey}{$validKey}) ) ) { 
								$isValid=0; #yes it's valid
								#There is no need to have the full text in the hidden fields
								#E.g.: do Sev=Warning --> Sev=1
								if ( $DEFAULTS{$defaultKey}{'convertValueToNumber'} eq 'yes' ) {
									$value=$validKey;
								}
							}
						}
					}	
				} else  {
					#if validateValues is not yes it's valid ;-)
					$isValid=0;
				}
				#Validate Length
				if ( exists $DEFAULTS{$defaultKey}{'validateLength'} &&  $DEFAULTS{$defaultKey}{'validateLength'} eq 'yes' ) {
					if ( $value!~/^\d+$/ && $DEFAULTS{$defaultKey}{'maxLength'} eq 'Integer' ) {
						$error++;
						my $text = "The key '$pluginKey=' must be a number!; ";
						if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
					}
					if ( $DEFAULTS{$defaultKey}{'maxLength'}=~/^\d+/ && length($value) > $DEFAULTS{$defaultKey}{'maxLength'} ) {
						$error++;
						my $text = "Lenght of '$pluginKey=' is longer than $DEFAULTS{$defaultKey}{'maxLength'}; ";
						if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
					}
				}
				
			}
		}
		if ( $isSupported == 1 ) {
			$error++;
			my $text = "Key '$pluginKey' is not supported; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
		#print validation errors only if field is supported...
		if ( $isValid == 1 && $isSupported == 0) {
			$error++;
			my $text = "Value '$value' of Key '$pluginKey' is not supported; ";
			$errMsgText=$text if ( !$errMsgText );
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		}
		#Check duplicate AlertGroup and AlertKey
		if ($Duplicate[0] && $Duplicate[1] && $checked == 0 && $OPTIONS{'ignoreDuplicates'}{'current'} eq 'false') {
			$checked = 1;
			foreach my $alarm (keys %G_LONGOUTPUT) {
				if ( exists $G_LONGOUTPUT{$alarm}{'AlertGroup'}{'value'} && exists $G_LONGOUTPUT{$alarm}{'AlertKey'}{'value'} ) {
				    if ( "$G_LONGOUTPUT{$alarm}{'AlertGroup'}{'value'}" eq "$Duplicate[0]" && "$G_LONGOUTPUT{$alarm}{'AlertKey'}{'value'}" eq "$Duplicate[1]" ) {
					log_msg(LOG_WARN, "new AlertGroup: $G_LONGOUTPUT{$alarm}{'AlertGroup'}{'value'} existing AlertGroup: $Duplicate[0]");
					log_msg(LOG_WARN, "new AlertKey: $G_LONGOUTPUT{$alarm}{'AlertKey'}{'value'} existing AlertKey: $Duplicate[1]");
					$error++;
					my $text = "Duplicate AlertGroup and AlertKey are not supported; ";
					$errMsgText=$text if ( !$errMsgText );
					if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
				    }
				}
			}
		} 
		if ( $ourKey eq 'Summary' ) {
			# no need to surround the summary field
			$value=~s/^("|')//g; 
			$value=~s/("|')$//;
			# if Summary is too long it will be cut after 970 characters. We need also a buffer for "[Delayed until DD/MM/YYYY HH:MI]"and "Review Required:"
			if ( length($value) > 950 ) {
				$value=substr( $value, 0, 950 );
				$value.="....(max len reached!)";
			}
		}
		if ( $ourKey eq 'URL' ) {
			$value=~s/=/%3D/g;
			$value=~s/&/%26/g;
		}
		

		log_msg(LOG_DEBUG, "Add new values to hash. (\$G_LONGOUTPUT{\$eventId}{\$ourKey}{'pluginKeyName'} = \$pluginKey --> \$G_LONGOUTPUT{$eventId}{$ourKey}{'pluginKeyName'} = $pluginKey)");
		log_msg(LOG_DEBUG, "Add new values to hash. (\$G_LONGOUTPUT{\$eventId}{\$ourKey}{'shortKeyName'} = \$shortKey   --> \$G_LONGOUTPUT{$eventId}{$ourKey}{'shortKeyName'} = $shortKey)");
		log_msg(LOG_DEBUG, "Add new values to hash. (\$G_LONGOUTPUT{\$eventId}{\$ourKey}{'value'} = \$value             --> \$G_LONGOUTPUT{$eventId}{$ourKey}{'value'} = $value)");
		chomp($value); 
		$value=~s/\r\n/ /g;
		$value=~s/\n/ /g;
		$value=~s/\s+$//g;
		$value=~s/\r/ /g; 
		$value=~s/\f//g; #Form
		$value=~s/\a//g; #Bell
		$value=~s/\b//g; #Backspace
		$value=~s/\|/,/g;
		if ($OPTIONS{'OutputVersion'}{'current'} > 0 and $ourKey=~/^(Dup|Pattern|Pattern2|Sn|Source|Text|Text2|TextOnly|Thresh|Tresh)$/ ) {
			$error++;
			my $text = "Field $1 is not supported with version 2. Pls replace with 'Report'; ";
			if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
		} 
		#ignore empty values (e.g. sms=" ")
		if ( $value!~/^('|")\s*('|")$/) {
			$G_LONGOUTPUT{$eventId}{$ourKey}{'pluginKeyName'} = $pluginKey;
			$G_LONGOUTPUT{$eventId}{$ourKey}{'shortKeyName'} = $shortKey;
			$G_LONGOUTPUT{$eventId}{$ourKey}{'value'} = $value;
		}
    	}
}

sub printPerfdata {
	$error++;
	my $text="The function 'printPerfdata' is deprecated, perfdata are printed by default! use 'set' if u don't want perfdata printed!; ";
	if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
}
sub print {
	my $method=shift;
	my $format=shift;
	my $header_line=shift;

	if ($method || $format || $header_line) {	
		$error++;
		my $text="The print arguments are deprecated, use the 'set' function instead!; ";
		if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
	}
	$header_line=$OPTIONS{'printCustomHeader'}{'current'};

	# Supported Methods
	# default - hashkey over whole alarms
	# calculated - hashkey on all AlertGroup, AlertKey and Severity fields
	
	if ( $OPTIONS{'OutputVersion'}{'current'} == 0 && ($OPTIONS{'printFormat'}{'current'} eq "long") ) {
		$error++;
		my $text = "Version 0 supports only printFormat short or orignial. long is not supported! ;";
		if ( $errMsgText!~/$text/){ $errMsgText.=$text; }
	}
	if ( $error && $error > 0 ) {
		if ( $errMsgText ) {
			$errMsgText=~s/\|/,/g;
			&add({ Summary => "${error} field errors(s) found: $errMsgText",
				Severity => "Minor",
				AlertGroup => "Plugin",
				AlertKey => "OutputError",
				SuppressEscl => 20,
				Type => "NAA",
				oon => 100000,
                		MsgGroup => $OPTIONS{'ErrorMessageGroup'}{'current'},
			});
		}
		$error = 0;
		$errMsgText = "";
	}

	if ( $OPTIONS{'printOrder'}{'current'} eq "bySeverity" ) {
		my %temp_G_LONGOUTPUT = %G_LONGOUTPUT;
		%G_LONGOUTPUT=();
		my $factor=5000;
		foreach my $id (sort { $a <=> $b } keys %temp_G_LONGOUTPUT) {
			if ( $temp_G_LONGOUTPUT{$id}{'Severity'}{'value'} == 5 ) { $factor = 1000 + $id };
			if ( $temp_G_LONGOUTPUT{$id}{'Severity'}{'value'} == 4 ) { $factor = 2000 + $id };
			if ( $temp_G_LONGOUTPUT{$id}{'Severity'}{'value'} == 3 ) { $factor = 3000 + $id };
			if ( $temp_G_LONGOUTPUT{$id}{'Severity'}{'value'} == 2 ) { $factor = 4000 + $id };
			if ( $temp_G_LONGOUTPUT{$id}{'Severity'}{'value'} == 0 ) { $factor = 5000 + $id };
			$G_LONGOUTPUT{$factor} = \%{$temp_G_LONGOUTPUT{$id}};
		}
		%temp_G_LONGOUTPUT=();
	}
			
	
	my $OutputLines="";
	my $hex_digest="";
	my $sevNum=3;
	my $outputMessage="";
	my $msgCount=0;
	my $HeaderLineError="";
	my $HeaderLineOK="";
	@exitCode=(0,0,0,0,0,0); #o,w,c,u,i  #o,x,w,m,m,c
	foreach my $id (sort { $a <=> $b } keys %G_LONGOUTPUT) {
		if ( exists $G_LONGOUTPUT{$id}{'TextOnly'}{'value'} ) {
			$OutputLines.= $G_LONGOUTPUT{$id}{'TextOnly'}{'value'};
			next;
		}
		$msgCount++;
		$sevNum=$G_LONGOUTPUT{$id}{'Severity'}{'value'};
		if ( $sevNum > $OPTIONS{'MaxSeverity'}{'current'} ) {
			$sevNum = $OPTIONS{'MaxSeverity'}{'current'}
		}
		my $sevName=$sevNum;
		if ( $sevNum=~/^\d$/ ) {
			$sevName=$SEVERITY{$sevNum};
		}
		if ( $sevName && $sevName eq "Normal" ) {
			$sevName = "OK";
		}
		$G_LONGOUTPUT{$id}{'Severity'}{'value'}=$sevNum;
		#count occurrences per severity. this is also used to find the correct exit code.
		$exitCode[$sevNum]++;
		$sevName = "UnKnOwN" if ( !$sevName); 
		$outputMessage="$sevName - $G_LONGOUTPUT{$id}{'Summary'}{'value'} [$G_LONGOUTPUT{$id}{'MsgGroup'}{'value'},$G_LONGOUTPUT{$id}{'AlertGroup'}{'value'}]";
		$HeaderLineOK = "$sevName - $G_LONGOUTPUT{$id}{'Summary'}{'value'} [$G_LONGOUTPUT{$id}{'MsgGroup'}{'value'},$G_LONGOUTPUT{$id}{'AlertGroup'}{'value'}]";
		$OutputLines.= "$outputMessage <!--";
		if ( $sevNum > 0 ) {
			$HeaderLineError = $outputMessage;
		}
		my $value="";
		foreach my $elem (sort keys %{$G_LONGOUTPUT{$id}}) {
			next if $elem eq 'Summary';
			next if $elem eq 'OutputOrderNr';
			$value=$G_LONGOUTPUT{$id}{$elem}{'value'} if ( exists $G_LONGOUTPUT{$id}{$elem}{'value'} );
			next if $value eq ""; # no need to print empty keys!
			next if ($elem eq 'SuppressEscl' and $value == 0); # no need to print SuppressEscl = Normal. That's the default
			if ( $OPTIONS{'OutputVersion'}{'current'}  == 0 && $elem eq 'Severity' ) {
				$value=$SEVERITY{$sevNum};
			}
			if ( $OPTIONS{'printHashCalcMethod'}{'current'} eq 'onHiddenFields' && ($elem eq 'MsgGroup' || $elem eq 'AlertGroup' || $elem eq 'AlertKey' || $elem eq 'ValueChangedEvent' || $elem eq 'Severity') ) {
				$hex_digest.=$value;
			}
			#print converted hidden fields
			if ( $OPTIONS{'printFormat'}{'current'} eq "short" ) {
				$OutputLines.= " $G_LONGOUTPUT{$id}{$elem}{'shortKeyName'}=$value" if ($G_LONGOUTPUT{$id}{$elem}{'shortKeyName'});
			} elsif ( $OPTIONS{'printFormat'}{'current'} eq "long" ) {
				$OutputLines.= " $elem=$value";
			} else {
				$OutputLines.= " $G_LONGOUTPUT{$id}{$elem}{'pluginKeyName'}=$value";
			}

		}
		if ( $OPTIONS{'OutputVersion'}{'current'} > 0 ) {
			$OutputLines.= " v=" . $OPTIONS{'OutputVersion'}{'current'};
		}
		$OutputLines.=  " -->\n";
	}
	my $ecode=0;
	my $errCount=0;
	if ( $exitCode[2] > 0 ) { $ecode=1;$errCount=$errCount+$exitCode[2];}
	if ( $exitCode[3] > 0 ) { $ecode=1;$errCount=$errCount+$exitCode[3];}
	if ( $exitCode[4] > 0 ) { $ecode=1;$errCount=$errCount+$exitCode[4];}
	if ( $exitCode[5] > 0 ) { $ecode=2;$errCount=$errCount+$exitCode[5];}
	
	if ( $OPTIONS{'printFormat'}{'current'} eq 'complete' ) {
		$hex_digest=md5_hex($OutputLines);
	} elsif ( $OPTIONS{'printHashCalcMethod'}{'current'} eq 'onHiddenFields' ) {
		$hex_digest="GrKeySevOnly" . md5_hex($hex_digest);
	} else {
		$hex_digest=md5_hex($OutputLines);
	}
	
	if ( length($header_line) > 3 ) {
		# Checked 4 Objects - 5 Ok , 0 Info, 0 Warn, 0 Crit. 
		$header_line=~s/<SUMMARY>/Checked $msgCount objects - $exitCode[0] OK, $exitCode[2] Warning, $exitCode[3] Minor, $exitCode[4] Major, $exitCode[5] Critical/g;
		$header_line=~s/<#ALL>/$msgCount/g;
		$header_line=~s/<#WARNING>/$exitCode[2]/g;
		$header_line=~s/<#MINOR>/$exitCode[3]/g;
		$header_line=~s/<#MAJOR>/$exitCode[4]/g;
		$header_line=~s/<#CRITICAL>/$exitCode[5]/g;
		$header_line=~s/<#OK>/$exitCode[0]/g;
		$header_line=~s/<#COUNTER>/$perfdataId/g;
		print "$header_line <!-- $hex_digest -->\n";
	} elsif ( $errCount == 1 ) {
		print "$HeaderLineError ($exitCode[0] OK, $exitCode[2] Warning, $exitCode[3] Minor, $exitCode[4] Major, $exitCode[5] Critical) <!-- $hex_digest -->\n";
	} elsif ( $msgCount == 1 ) {
		print "$HeaderLineOK <!-- $hex_digest -->\n";
	} else {
		print "Checked $msgCount objects - $exitCode[0] OK, $exitCode[2] Warning, $exitCode[3] Minor, $exitCode[4] Major, $exitCode[5] Critical <!-- $hex_digest -->\n";
	}
	print "$OutputLines";

	#END TIMER for plugin execution time measurement counter
	my $elapsed = Time::HiRes::tv_interval($pluginExecutionTime);

	if ( $OPTIONS{'Graph_PluginExecutionTime'}{'current'} eq 'yes' ) {
		my $countername=$OPTIONS{'Graph_Name'}{'current'};
		$countername=~s/<PLUGINNAME>/$basename/g;
		FNO::addPerfdata( { Name => $countername, Value => $elapsed, Unit => $OPTIONS{'Graph_Unit'}{'current'} });
	}

	if ( $OPTIONS{'printPerfdata'}{'current'} eq 'yes' && $perfdataId > 0 ) {
		print "|";
		foreach my $id (sort { $a <=> $b } keys %G_PERFDATA) {
			my $countername=$G_PERFDATA{$id}{'Name'}{'value'};
			$countername=~s/\+//g;
			my $p_value="";     $p_value = $G_PERFDATA{$id}{'Value'}{'value'} if ( exists $G_PERFDATA{$id}{'Value'}{'value'});
			my $p_unit="";      $p_unit  = $G_PERFDATA{$id}{'Unit'}{'value'} if (exists $G_PERFDATA{$id}{'Unit'}{'value'});
			my $p_warn="";      $p_warn  = $G_PERFDATA{$id}{'PerfWarn'}{'value'} if (exists $G_PERFDATA{$id}{'PerfWarn'}{'value'});
			my $p_crit="";      $p_crit  = $G_PERFDATA{$id}{'PerfCrit'}{'value'} if (exists $G_PERFDATA{$id}{'PerfCrit'}{'value'});
			my $p_min="";       $p_min   = $G_PERFDATA{$id}{'PerfMin'}{'value'} if (exists $G_PERFDATA{$id}{'PerfMin'}{'value'});
			my $p_max=""; 	    $p_max   = $G_PERFDATA{$id}{'PerfMax'}{'value'} if (exists $G_PERFDATA{$id}{'PerfMax'}{'value'});
			
			#print " $countername=$G_PERFDATA{$id}{'Value'}{'value'}$G_PERFDATA{$id}{'Unit'}{'value'};$G_PERFDATA{$id}{'PerfWarn'}{'value'};$G_PERFDATA{$id}{'PerfCrit'}{'value'};$G_PERFDATA{$id}{'PerfMin'}{'value'};$G_PERFDATA{$id}{'PerfMax'}{'value'}";
			print " $countername=$p_value$p_unit;$p_warn;$p_crit;$p_min;$p_max";
		}
		print "\n";
		%G_PERFDATA=();
	}
	# reset variables
	%G_LONGOUTPUT=();
	# check if we need a special return code. This is important for logfile or buffer messages. We need to make sure that clear alarms are notified!
	if ( $OPTIONS{'MinReturnCode'}{'current'} > $ecode && $ecode == 0 ) {
		close(LOGFILE);
		return($OPTIONS{'MinReturnCode'}{'current'});
	} else {
		close(LOGFILE);
		return($ecode);
	}
}

sub log_msg {
        my($level) = shift(@_);
        my($ltime, $msg);

	#open log file or change handle in case the 'LogDestination' has changed.
	if ( $isLogFileOpen && $isLogFileOpen ne $OPTIONS{'LogDestination'}{'current'} ) {
		close(LOGFILE);
		open_logfile($OPTIONS{'LogDestination'}{'current'});
		$isLogFileOpen=$OPTIONS{'LogDestination'}{'current'};
	}
		
        if ($OPTIONS{'LogLevel'}{'current'} < $level)  { return; }
        if (! $OPTIONS{'LogDestination'}{'current'} )  { return; }

        $msg = join(" ", @_);

        $ltime = localtime(time());
	if ( $OPTIONS{'LogDestination'}{'current'} eq "STDERR" ) {
		print STDERR "$ltime: $LOG_ERRORS{$level}: PID:$pid $msg\n";
	} elsif	( exists $OPTIONS{'LogDestination'}{'current'}) {
                print LOGFILE "$ltime: $LOG_ERRORS{$level}: PID:$pid $msg\n";
        }
}

sub formattedPrint{
        my $opt=shift;
        my $text=shift;
        #print "<h1><font color=\"$colors[$opt]\">$text</font></h1>\n";
        log_msg(LOG_INFO, "$text\n");
        print "$text\n";
}

sub open_logfile {
        my($logfile) = $_[0];
	if ( $logfile eq "STDERR" ) {
		return(0);
	} 
        if (open(LOGFILE, ">>$logfile")) {
                select LOGFILE;
                $| = 1;
                select STDOUT;
        } else {
                print "Can't open logfile $logfile ($!), exiting!";
                exit(1);
        }
}


1;
