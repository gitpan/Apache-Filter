#!/usr/bin/perl

my $r = shift;
$r->send_http_header;
$r->send_cgi_header;

print "blah\n";
