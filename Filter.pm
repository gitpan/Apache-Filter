package Apache::Filter;

use strict;
use Symbol;
use Carp;
use vars qw(%INFO $VERSION);
$VERSION = '0.01';

sub Apache::filter_input {
    my $r = shift;
    my $debug = 0;
    
    $INFO{'fh_in'} = gensym;
    
    if ($INFO{'count'}) {
        # A previous filter has written to STDOUT.
        # We'll assume it's done writing.
        # Thus we should turn STDOUT into fh_in.
        
        tie *{$INFO{'fh_in'}}, 'Apache::Filter', tied *STDOUT;
        
    } else {
        # This is the first filter in the chain.  We just open $r->filename.
        
        open (*{$INFO{'fh_in'}}, $r->filename());
    }
    
    unless ($INFO{'count'}) {
        $r->register_cleanup(sub {%Apache::Filter::INFO=()});
        $r->send_http_header();
        
        untie *STDOUT;
    }
        
    $INFO{'count'}++;  #YUCK!
    
    if (@{$r->get_handlers('PerlHandler')} == $INFO{'count'}) {  #YUCK!
        # This is the last filter in the chain, so let STDOUT go to the browser.
        tie *STDOUT, ref($r), $r;
    } else {
        # Capture the output so we can feed it to the next filter.
        tie *STDOUT, __PACKAGE__;
    }
    
    return $INFO{'fh_in'};
}

# This package is a TIEHANDLE package, so it can be used like this:
#  tie(*HANDLE, 'Apache::Filter');
# All it does is save strings that are written to the filehandle, and
# spits them back out again when you read from the filehandle.

sub TIEHANDLE {
    my $class = shift;
    my $self = (@_ ? shift : { content => '' });
    return bless $self, $class;
}

sub PRINT {
    my $self = shift;
    $self->{'content'} .= join "", @_;
}

sub PRINTF {
    my $self = shift;
    my $format = shift;
    $self->{'content'} .= sprintf($format, @_);
}

sub READLINE {
   # I've tried to replicate the behavior of real filehandles here
   # with respect to $/, but I might have screwed something up.
   # It's kind of a mess.

   my $self = shift;
   my $debug = 0;
   warn "reading line, content is $self->{'content'}" if $debug;
   return undef unless length $self->{'content'};

   if (defined $/) {
      if (my $l = length $/) {
         my $spot = index($self->{'content'}, $/);
         if ($spot > -1) {
            my $out = substr($self->{'content'}, 0, $spot + $l);
            substr($self->{'content'},0, $spot + $l) = '';
            return $out;
         } else {
            return delete $self->{'content'};
         }
      } else {
         return $1 if $self->{'content'} =~ s/^(.*?\n+)//;
         return delete $self->{'content'};
      }
   } else {
      return delete $self->{'content'};
   }
}

sub READ { croak "READ method is not implemented in ", __PACKAGE__ }
sub GETC { croak "GETC method is not implemented in ", __PACKAGE__ }

1;

__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Apache::Filter - Alter the output of previous handlers

=head1 SYNOPSIS

 ##### In httpd.conf:

  PerlModule Apache::Filter;
  # That's it - this isn't a handler.
  
  <Files ~ "*\.blah">
   SetHandler perl-script
   PerlHandler Filter1 Filter2 Filter3
  <\Files>
 
 #### In Filter1, Filter2, and Filter3:
  my $fh = $r->filter_input();
  while (<$fh>) {
    s/ something / something else /;
    print;
  }

=head1 DESCRIPTION

Each of the handlers Filter1, Filter2, and Filter3 will make a call
to $r->filter_input(), which will return a filehandle.  For Filter1,
the filehandle points to the requested file.  For Filter2, the filehandle
contains whatever Filter1 wrote to STDOUT.  For Filter3, it contains
whatever Filter3 wrote to STDOUT.  The output of Filter3 goes directly
to the browser.

Note that the modules Filter1, Filter2, and Filter3 are listed in
B<forward> order, in contrast to the reverse-order listing of
Apache::OutputChain.

When you've got this module, you can use the same handler both as
a stand-alone handler, and as an element in a chain.  Just make sure
that whenever you're chaining, B<all> the handlers in the chain
are "Filter-aware," i.e. they each call $r->filter_input() exactly
once, before they start printing to STDOUT.  There should be almost
no overhead for doing this when there's only one element in the chain.



=head1 HEADERS

In order to make a decent web page, each of the filters shouldn't
call $r->send_http_header() or you'll get lots of headers all over 
your page.  This is so obvious that the previous sentence should be
a lot shorter.

So the current solution is to have _none_ of the filters send the headers,
and this module will send them for you when the first filter calls
$r->filter_input().  You should still set up the content-type (using
$r->content_type), and any other headers you want to send, before calling
$r->filter_input().  filter_input will simply call $r->send_http_header()
with no arguments to send whatever headers you have set.

One downside of this is that subsequent filters in the stack will probably
call $r->content_type for no reason, but say la vee.  If anyone's got
better ideas, don't hold them back.

=head1 NOTES

It took all my gusto to figure out how to use tie a filehandle in such 
a way that it could be saved in a scalar.  I finally figured out how to
use the Symbol.pm module to do this, in what I think is a very neat and
efficient way.  But because I'm sort of stumbling in the dark on this, 
it would be great if someone could check my work.  (Astonishingly, 
L<perltie(1)> doesn't say what kinds of things are allowed as the first 
argument to tie() for tying a filehandle!)

The output of each filter is accumulated in memory before it's passed
to the next filter, so memory requirements might be large for large pages.
I'm not sure whether Apache::OutputChain is subject to this same behavior.
In future versions I might find a way around this, or cache large pages
to disk so memory requirements don't get out of hand.

My usual alpha disclaimer: the interface here isn't stable.  So far this
should be treated as a proof-of-concept.

=head1 BUGS

This uses some funny stuff to figure out when the currently executing
handler is the last handler in the chain.  As a result, code that
manipulates the handler list at runtime (using push_handlers and the
like) might produce mayhem.  Poke around a bit in the code before you 
try anything.

I haven't considered what will happen if you use this and you haven't
turned on PERL_STACKED_HANDLERS.

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

=head1 COPYRIGHT

Copyright 1998 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut
