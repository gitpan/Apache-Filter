package Apache::UC;

# This is just a proof-of-concept, an example of a module
# that uses the Apache::Filter features.

use strict;
use Apache::Constants qw(:common OPT_EXECCGI);


sub handler {
	my $r = shift;

	$r->content_type("text/html");
	my $fh = $r->filter_input();

	print uc() while <$fh>;

	return OK;
}
1;

