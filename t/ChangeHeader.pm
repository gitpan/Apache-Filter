package Apache::ChangeHeader;

use strict;
use Apache::Constants qw(:common);

sub handler {
  my $r = shift;
  $r = shift unless ref $r;
  
  $r->content_type("text/html");
  my ($fh, $status) = $r->filter_input();

  return $status unless $status == OK;

  $r->header_out('X-Test', 'success');
  
  print "Blah blah\n";
  return OK;
}
1;

