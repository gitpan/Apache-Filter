package Apache::UC;

# This is just a proof-of-concept, an example of a module
# that uses the Apache::Filter features.

use strict;
use Apache::Constants qw(:common);


sub handler {
	my $r = shift;

	$r->content_type("text/html");
	my ($fh, $status) = $r->filter_input();
	return $status unless $status == OK;

	print uc() while <$fh>;

	return OK;
}
1;

