# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use Apache::Filter;
$loaded = 1;
&report(1);

######################### End of black magic.

&report(tie *FH, 'Apache::Filter');

print FH "line1\n";
&report(<FH> eq "line1\n");

print FH "line1\n", "line2";
&report(<FH> eq "line1\n");
&report(<FH> eq "line2");

sub report {
   my $ok = shift;
   $TEST_NUM++;
   print "not "x(!$ok), "ok $TEST_NUM\n";
}
