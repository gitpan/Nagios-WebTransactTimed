use Test;
use vars qw($tests);

BEGIN {$tests = 4; plan tests => $tests}

$cmd = "perl -Mblib t/check_inter_perf.pl -h";
$str = `$cmd`;
print "Test was: $cmd\n" if ($?);
$t += ok $str, '/^check_inter_perf/';

@nosuchsites = qw(www.cia.gov.au www.cia.gov.nz) ;
@slowsites = qw(www.chinatelecom.com.cn www.oxford.ac.uk) ;

require 't/Nagios_WebTransactTimed_cache.pl' ;

if ( $proxy && $account && $proxy_pass ) {
  $cmd = "perl -Mblib t/check_inter_perf.pl -P $proxy -A $account -p $proxy_pass" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance Ok:/' ;
  print "Test was: $cmd\n" if ($?);
  $cmd = "perl -Mblib t/check_inter_perf.pl -P $proxy -A $account -p $proxy_pass @nosuchsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
  $cmd = "perl -Mblib t/check_inter_perf.pl -T 1 -P $proxy -A $account -p $proxy_pass @slowsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
} elsif ( $proxy ) {
  $cmd = "perl -Mblib t/check_inter_perf.pl -P $proxy" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance Ok:/' ;
  print "Test was: $cmd\n" if ($?);
  $cmd = "perl -Mblib t/check_inter_perf.pl -P $proxy @nosuchsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
  $cmd = "perl -Mblib t/check_inter_perf.pl -T 1 -P $proxy @slowsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
} else {
  $cmd = "perl -Mblib t/check_inter_perf.pl" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance Ok:/' ;
  print "Test was: $cmd\n" if ($?);
  $cmd = "perl -Mblib t/check_inter_perf.pl @nosuchsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
  $cmd = "perl -Mblib t/check_inter_perf.pl -T 1 @slowsites" ;
  $str = `$cmd` ;
  $t += ok $str, '/^Internet performance b0rked:/' ;
}

exit(0) if defined($Test::Harness::VERSION);
exit($tests - $t);
