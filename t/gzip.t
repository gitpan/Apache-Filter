#!/usr/bin/perl

$|=1;
use strict;
use lib 't/lib';  # Until my changes are merged into the main distro
use Apache::test qw(skip_test have_httpd test);
BEGIN {
  skip_test unless have_httpd;
  skip_test unless eval{require Apache::Compress};
}
use Compress::Zlib;


my %requests = 
  (
   3  => '/docs/compress.cp',
   4  => {uri=>'/docs/compress.cp',
          headers=>{'Accept-Encoding' => 'gzip'},
         },
  );

my %special_tests = 
  (
   3  => { 'test' => sub { !defined($_[1]->header('Content-Encoding')) } },
   4  => { 'test' => sub { $_[1]->header('Content-Encoding') =~ /gzip/ } },
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
