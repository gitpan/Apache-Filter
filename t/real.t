#!/usr/bin/perl

$|=1;
use strict;
use lib 't/lib';  # Until my changes are merged into the main distro
use Apache::test;

my %requests = 
  (
   3  => '/docs/simple.u',
   4  => '/docs/dir/',  # A directory
   5  => '/docs/determ.p',
   6  => '/docs/perlfirst.pl',
   7  => '/docs/own_handle.fh/docs.check/7',
   8  => '/docs/change_headers.h',
   9  => '/docs/send_headers.pl',
   10 => '/docs/perlfirst.pl',  # Make sure it can run twice.
   11 => '/docs/perlfirst.pl',  # Make sure it can run thrice.
   12 => '/docs/perlfirst.pl',  # Make sure it can run quice.
   13 => '/docs/simple.r',
   14 => '/docs/send_fd.pl',
   15 => '/docs/send_headers.pl',
  );

my %special_tests = 
  (
   4  => { 'test' => sub { $_[0] =~ /index of/i } },
   8  => { 'test' => sub { $_[1]->header('X-Test') eq 'success' } },
   15 => { 'test' => sub { $_[1]->header('Content-Type') eq 'ungulate/moose' } },
  );

use vars qw($TEST_NUM);
print "1.." . (2 + keys %requests) . "\n";
test ++$TEST_NUM, 1; # Loaded successfully
test ++$TEST_NUM, 1; # For backward numerical compatibility

foreach my $testnum (sort {$a<=>$b} keys %requests) {
  &test_outcome(Apache::test->fetch($requests{$testnum}), $testnum);
}

#############################

sub test_outcome {
  my ($response, $i) = @_;
  my $content = $response->content;
 
  $content = $special_tests{$i}{content}->($content, $response)
    if $special_tests{$i}{content};

  my $expected = '';
  my $ok = ($special_tests{$i}{'test'} ?
	    $special_tests{$i}{'test'}->($content, $response) :
	    $content eq ($expected = `cat t/docs.check/$i`));

  Apache::test->test(++$TEST_NUM, $ok);
  my $resp = $response->as_string;
  print "$i Result:\n$resp\n$i Expected: $expected\n" if ($ENV{TEST_VERBOSE} and not $ok);
}
