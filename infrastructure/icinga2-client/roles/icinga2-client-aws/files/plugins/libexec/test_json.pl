#!/usr/bin/perl
use JSON;
use Data::Dumper;

%rec_hash = ('a' => 1, 'b' => 2, 'c' => 3, 'd' => 4, 'e' => 5);
my $json = encode_json \%rec_hash;
print "$json\n";


$json = '{"eno1": {"interface": "eno1","App": "System","Sev": "warning","MsgG": "OPS-IS-CLOUD"},"eno2": {"MsgG": "OPS-IS-CLOUD","Sev": "warning","App": "System","interface": "eno2"}}';
$text = decode_json($json);
print  Dumper($text);
