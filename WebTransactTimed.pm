package Nagios::WebTransactTimed;

use strict;

use vars qw($VERSION @ISA) ;

$VERSION = '0.03';
@ISA = qw(Nagios::WebTransact) ;

use HTTP::Request::Common qw(GET POST) ;
use HTTP::Cookies ;
use LWP::UserAgent ;
use Time::HiRes qw(gettimeofday tv_interval) ;
use Carp ;

use Nagios::WebTransact ;

use constant FALSE			=> 0 ;
use constant TRUE			=> ! FALSE ;
use constant FAIL			=> FALSE ;
use constant OK				=> TRUE ;
					# ie Normal Perl semantics. 'Success' is TRUE (1).
					# Caller must map this to Unix/Nagios return codes.

use constant GET_TIME_THRESHOLD		=> 10 ;
use constant FAIL_RATIO_PERCENT		=> 50 ;

sub check {
  my ($self, $cgi_parm_vals_hr) = @_ ;

  my %defaults = ( cookies => TRUE, debug => TRUE, timeout => GET_TIME_THRESHOLD, agent => 'Mozilla/4.7', proxy => {},
                   fail_if_1 => FALSE, verbose => 1, fail_ratio_percent => FAIL_RATIO_PERCENT ) ;

					# check semantics.
					# $fail_if_1  	?	return FAIL if any URL fails
					# ! $fail_if_1	?	return FAIL if all URLs fail
					#                       (same as return OK if any URL ok)

  my %parms = (%defaults, @_) ;

  my ($res, $req, $url_r, $resp_string, $timeout) ;
  my ($cookie_jar, $ua, $debug, $t0, $elapsed, @get_times) ;
  my ($rounded_elapsed, @urls, $check_time, $verbose, $fail_ratio, $fail_ratio_percent ) ;
  
  $ua = new LWP::UserAgent ;
  $ua->agent($parms{agent}) ;

  $debug = $parms{debug} ;
  $verbose = $parms{verbose} ;
  $fail_ratio_percent = $parms{fail_ratio_percent}  || FAIL_RATIO_PERCENT ;
  croak("Expecting fail_ratio_percent as a percentage [0-100%], got \$fail_ratio:_percent $fail_ratio_percent\n") if $fail_ratio_percent < 0 or $fail_ratio_percent > 100 ;
  $fail_ratio = $fail_ratio_percent / 100 ;
  $timeout = $parms{timeout} ;
  croak("Expecting timeout as a natural number [0 ... not_too_big], got \$timeout: $timeout.\n") if $timeout < 0 ;

  $ua->timeout($timeout) ;
  $ua->cookie_jar(HTTP::Cookies->new) if $parms{cookies} ;

  $ua->proxy(['http', 'ftp'] => $parms{proxy}{server}) if exists $parms{proxy}{server} ;

  @urls = @{ $self->get_urls } ;

  my $Fault_Threshold = int( scalar @urls * $fail_ratio + 0.5 ) * $timeout ;

  $check_time = 0 ;
  @get_times = () ;
  foreach $url_r ( @urls ) {

    $req = $self->make_req( $url_r->{Method}, $url_r->{Url}, $url_r->{Qs_var}, $url_r->{Qs_fixed}, $cgi_parm_vals_hr ) ;

    $req->proxy_authorization_basic( $parms{proxy}{account}, $parms{proxy}{pass} ) if exists $parms{proxy}{account} ;

    print STDERR  "... " . $req->as_string . "\n" if $debug ;

    $t0 = [gettimeofday] ;
  
    $res = $ua->request($req) ;
  
    $elapsed = tv_interval ($t0) ;
    $rounded_elapsed = ( ($elapsed < GET_TIME_THRESHOLD and $res->is_success) ? sprintf("%3.2f",  $elapsed ) : GET_TIME_THRESHOLD ) ;
    push @get_times, $rounded_elapsed ;
    $check_time += $rounded_elapsed ;

    print STDERR  '... ' . $res->as_string . "\n" if $debug ;

    if ( $verbose ) {
      my $url_report = '--getting ' . $url_r->{Url} ;
      print STDERR  $url_report, ' ' x (50 - length($url_report)), "\t$rounded_elapsed\tTotal check time: $check_time\n" ;
    }
  
    unless ( $check_time <= $Fault_Threshold ) {
      my $i = 0 ;
      foreach (@urls) {
        $get_times[$i] = GET_TIME_THRESHOLD if not defined $get_times[$i] ;
        $i++ ;
      }
      return (FAIL, 'Transaction failed. Timeout', \@get_times) ;
    }
  
  }
  return (OK, 'Transaction completed Ok.', \@get_times) ;
}
  
1 ;


__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Nagios::WebTransactTimed - An object that provides a check method (usually called by a Nagios service check) to
determine if a sequence of URLs can be got inside a time threshold, returning the times for each.


=head1 SYNOPSIS

  use Nagios::WebTransactTimed;

  # Constructors
  $web_trx = Nagios::WebTransactTimed->new(\@url_set);

=head1 DESCRIPTION

WebTransactTimed is a subclass of WebTransact that checks web performance by downloading a sequence
of URLs.

The check is successfull if no more than B<fail_ratio> of the URLs fail ie a URL is downloaded
inside the timeout period with a successfull HTTP return code and no indications of invalid content.

Note that unlike WebTransact, this object only returns FAIL if all URLs fail or timeout.

=head1 CONSTRUCTOR

=over 4

=item Nagios::WebTransactTimed->new(ref_to_array_of_hash_refs)

E<10>

This is the constructor for a new Nagios::WebTransact object. C<ref_to_array_of_hash_refs
> is a reference to an array of records (anon hash refs) in the format :-

{ Method   => HEAD|GET|POST,
  Url      => 'http://foo/bar',
  Qs_fixed => [cgi_var_name_1 => val1, ... ]  NB that now square brackets refer to a Perl array ref
  Qs_var   => [cgi_var_name_1 => val_at_run_time],
  Exp      => blah,
  Exp_Fault=> blurb
}

Exp and Exp_Fault are normal Perl patterns without pattern match delimiters. Most often they are strings.

=item B<Exp> is the pattern that when matched against the respose to the URL (in the same hash) indicates
success.

=item B<Exp_Fault> is the pattern that indicates the response is a failure.

If these patterns contain parentheses eg 'match a lot (.*)', then the match is saved for use by 
Qs_var. Note that there should be only B<one> pattern per element of the Exp list. Nested patterns
( C<yada(blah(.+)blurble(x|y|zz(top.*))> ) will not work as expected.

Qs_fixed and Qs_var are used to generate a query string.

=item B<Qs_fixed> contains the name value pairs that are known at compile time whereas

=item B<Qs_var> contains placeholders for values that are not known until run time.

=back

In both cases, the format of these fields is a reference to an array containing alternating CGI
variable names and values eg \(name1, v1, name2, v2, ...) produces a query string name1=v1&name2=v2&..

=head1 METHODS

Unless otherwise stated all methods return either a I<true> or I<false>
value, with I<true> meaning that the check of the web transaction was a success.
I<false> is a zero (0).

=over 4

=item check( CGI_VALUES, OPTIONS )

Performs a check of the Web transaction by getting the sequence or URLs specified in 
the constructor argument.

<OPTIONS> are passed in a hash like fashion, using key and value pairs.
Possible options other than those specified by the super class are

B<timeout> specifies a timeout different to the default (10 seconds) for each URL. When a URL B<canno>t be fetched,
it is recorded as having taken B<10> (ten) seconds.

B<fail_ratio_percent> specifies that the check will return immediately (with a failure) if the proportion of failures
(ie if HTTP::Response::is_success says it is or a timeout) as a percentage, is greater than this threshold.
eg if fail_ratio_percent is 100, fetching all the URls must fail before the check returns false.

B<verbose> is meant for CLI use (or in a CGI). It reports the time taken for each URL on standard out.

check returns a boolean indication of success and a reference to an array containing the time taken for each URL.
If a URL cannot be download (invalid content, HTTP failure or timeout), the time is marked as 10. 

=back



=head1 EXAMPLE

see check_inter_perf.pl in t directory.

=head1 AUTHOR

S Hopcroft, Stanley.Hopcroft@IPAustralia.Gov.AU

=head1 SEE ALSO

  perl(1).
  Nagios::WebTransact
  Nagios   http://www.Nagios.ORG

=cut
