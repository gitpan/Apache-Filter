# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..8\n"; }
END {print "not ok 1\n" unless $loaded;}
use Apache::Filter;
$loaded = 1;
&report(1);

######################### End of black magic.

&report(tie *FH, 'Apache::Filter');

print FH "line1\n";
&report(<FH> eq "line1\n");

print FH "line1", "\n", "line2";
&report(<FH> eq "line1\n");
&report(<FH> eq "line2");

print FH "line1\nline2\n";
my $result = join('', <FH>);
print STDERR $result if $ENV{'TEST_VERBOSE'};
&report($result eq "line1\nline2\n");


{
	# Test the read() function
	my $buf = '';
	print FH "123456789";
	read(FH, $buf, 2);
	&report($buf eq '12', $buf);
	read(FH, $buf, 10, 2);
	&report($buf eq '123456789', $buf);
}

sub report {
   my $ok = shift;
   $TEST_NUM++;
   print "not "x(!$ok), "ok $TEST_NUM\n";
	print STDERR $_[0] if (!$ok and $ENV{'TEST_VERBOSE'});
}
