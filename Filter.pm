package Apache::Filter;

use strict;
use Symbol;
use Carp;
use Apache::Constants(':common');
use vars qw(%INFO $VERSION);
$VERSION = '0.07';

sub _out { wantarray ? @_ : $_[0] }

# %INFO object works like member data of $r, but since $r is a non-perl
# object, we can't store data in it.
# 
# $INFO{'fh_in'} is a Apache::Filter filehandle containing the output of the previous filter
# $INFO{'is_dir'} is true if $r->filename() is a directory
# $INFO{'count'} is incremented every time $r->filter_input() is called, so it contains
#                the position of the current filter in the handler stack.
# $INFO{'determ'}{$i} contains a true value if handler number $i has declared that it
#                     is deterministic (see docs).

sub Apache::filter_input {
    my $r = shift;
    my $debug = 0;
    
    my $status = OK;
    $INFO{'fh_in'} = gensym;
    my $count_in = $INFO{'count'}++; # Yuck - I don't like counting invocations.
    
    if (!$count_in and -d $r->filename()) {
        # Let mod_dir handle it - does this work?
        $INFO{'is_dir'} = 1;
    }
    if ($INFO{'is_dir'}) {
        return _out undef, DECLINED;
    }
        
    if ($count_in) {
        # A previous filter has written to STDOUT.
        # We'll assume it's done writing.
        # Thus we should turn STDOUT into fh_in.
        
        tie *{$INFO{'fh_in'}}, 'Apache::Filter', tied *STDOUT;
        
    } else {
        # This is the first filter in the chain.  We just open $r->filename.
        
        unless (-e $r->filename()) {
            $r->log_error($r->filename() . " not found");
            return _out undef, NOT_FOUND;
        }
        unless ( open (*{$INFO{'fh_in'}}, $r->filename()) ) {
            $r->log_error("Can't open " . $r->filename() . ": $!");
            return _out undef, FORBIDDEN;
        }
        
        $r->register_cleanup(sub {%Apache::Filter::INFO=()});
        untie *STDOUT;
    }
    
    if (@{$r->get_handlers('PerlHandler')} == $INFO{'count'}) {  #YUCK!
        # This is the last filter in the chain, so let STDOUT go to the browser.
        tie *STDOUT, ref($r), $r;
        $r->send_http_header();
    } else {
        # There are more filters after this one.
        # Capture the output so we can feed it to the next filter.
        tie *STDOUT, __PACKAGE__;
    }
    
    return _out $INFO{'fh_in'}, $status;
}

sub Apache::changed_since {
    
    # If any previous handlers are non-deterministic, then the content is 
    # volatile, so tell them it's changed.
    if ($INFO{'count'} > 1) {
        return 1 if grep {not $INFO{'determ'}{$_}} (1..$INFO{'count'}-1);
    }
    
    # Okay, only deterministic handlers have touched this.  If the file has
    # changed since the given time, return true.  Otherwise, return false.
    my $r = shift;
    return 1 if ((stat $r->filename)[9] > shift);
    return 0;
}

sub Apache::deterministic {
    shift;  # Don't need $r
    if (@_) {
        $INFO{'determ'}{$INFO{'count'}} = shift;
    }
    return $INFO{'determ'}{$INFO{'count'}};
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
    # It's kind of a mess.  Beautiful code is welcome.
 
    my $self = shift;
    my $debug = 0;
    warn "reading line, content is $self->{'content'}" if $debug;
    return unless length $self->{'content'};
        
    if (wantarray) {
        # This handles list context, i.e. @list = <FILEHANDLE> .
        # Wish Perl did this for me by repeated calls to READLINE.
        my @lines;
        while (length $self->{'content'}) {
            push @lines, scalar $self->READLINE();
        }
        return @lines;
    }
    
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

=head1 NAME

Apache::Filter - Alter the output of previous handlers

=head1 SYNOPSIS

  #### In httpd.conf:
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
  
  #### or, alternatively:
  my ($fh, $status) = $r->filter_input();
  return $status unless $status == OK;  # The Apache::Constants OK
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

=head1 METHODS

This module doesn't create an Apache handler class of its own - rather, it adds some
methods to the Apache:: class.  Thus, it's really a mix-in package
that just adds functionality to the $r request object.

=over 4

=item * $r->filter_input()

This method will give you a filehandle that contains either the file 
requested by the user ($r->filename), or the output of a previous filter.
If called in a scalar context, that filehandle is all you'll get back.  If
called in a list context, you'll also get an Apache status code (OK, 
NOT_FOUND, or FORBIDDEN) that tells you whether $r->filename was successfully
found and opened.


=item * $r->changed_since($time)

Returns true or false based on whether the current input seems like it 
has changed since C<$time>.  Currently the criteria to figure this out
is this: if the file pointed to by C<$r-E<gt>filename> hasn't changed since
the time given, and if all previous filters in the chain are deterministic
(see below), then we return false.  Otherwise we return true.

A caution: always call the C<changed_since()> and C<deterministic()> methods
B<AFTER> the C<filter_input()> method.  This is because Apache::Filter uses a 
crude counting method to figure out which handler in the chain is currently 
executing, and calling these routines out of order messes up the counting.

=item * $r->deterministic(1|0);

As of version 0.07, the concept of a "deterministic" filter is supported.  A
deterministic filter is one whose output is entirely determined by the contents
of its input file (whether the $r->filename file or the output of another filter),
and doesn't depend at all on outside factors.  For example, a filter that translates
all its output to upper-case is deterministic, but a filter that adds a date
stamp to a page, or looks things up in a database which may vary over time, is not.

Why is this a big deal?  Let's say you have the following setup:

 <Files ~ "\.boffo$">
  SetHandler perl-script
  PerlHandler Apache::FormatNumbers Apache::DoBigCalculation
  # The above are fake modules, you get the idea
 </Files>

Suppose the FormatNumbers module is deterministic, and the DoBigCalculation module
takes a long time to run.  The DoBigCalculation module can now cache its results,
so that when an input file is unchanged on disk, its results will remain known
when passed through the FormatNumbers module, and the DoBigCalculation module
will be able to used cached results from a previous run.

The guts of the modules would look something like this:

 sub Apache::FormatNumbers::handler {
    my $r = shift;
    $r->content_type("text/html");
    my ($fh, $status) = $r->filter_input();
    return $status unless $status == OK;
    $r->deterministic(1); # Set to true; default is false
    
    # ... do some formatting, print to STDOUT
    return OK;
 }
 
 sub Apache::DoBigCalculation::handler {
    my $r = shift;
    $r->content_type("text/html");
    my ($fh, $status) = $r->filter_input();
    return $status unless $status == OK;
    
    # This module implements a caching scheme by using the 
    # %cache_time and %cache_content hashes.
    my $time = $cache_time{$r->filename};
    my $output;
    if ($r->changed_since($time)) {
        # Read from <$fh>, perform a big calculation on it, and print to STDOUT
    } else {
        print $cache_content{$r->filename};
    }
    
    return OK;
 }

A caution: always call the C<changed_since()> and C<deterministic()> methods
B<AFTER> the C<filter_input()> method.  This is because Apache::Filter uses a 
crude counting method to figure out which handler in the chain is currently 
executing, and calling these routines out of order messes up the counting.


=back


=head1 HEADERS

In order to make a decent web page, each of the filters shouldn't
call $r->send_http_header() or you'll get lots of headers all over 
your page.  This is so obvious that the previous sentence should be
a lot shorter.

So the current solution is to have _none_ of the filters send the headers,
and this module will send them for you when the last filter calls
$r->filter_input().  You should still set up the content-type (using
$r->content_type), and any other headers you want to send, before calling
$r->filter_input().  filter_input will simply call $r->send_http_header()
with no arguments to send whatever headers you have set.

One downside of this is that all the filters in the stack will probably
call $r->content_type, most of them for no reason, but say la vee.  
If anyone's got better ideas, don't hold them back.

=head1 NOTES

VERY IMPORTANT: if one handler in a stacked handler chain uses 
C<Apache::Filter>, then THEY ALL MUST USE IT.  This means they all must
call $r->filter_input exactly once.  Otherwise C<Apache::Filter> couldn't
capture the output of the handlers properly, and it wouldn't know when
to release the output to the browser.

The output of each filter is accumulated in memory before it's passed
to the next filter, so memory requirements might be large for large pages.
I'm not sure whether Apache::OutputChain is subject to this same behavior,
but I think it's not.  In future versions I might find a way around this, 
or cache large pages to disk so memory requirements don't get out of hand.  
We'll see whether it's a problem.

My usual alpha disclaimer: the interface here isn't stable.  So far this
should be treated as a proof-of-concept.

A couple examples of filters are provided with this distribution in the t/
subdirectory: UC.pm converts all its input to upper-case, and Reverse.pm
prints the lines of its input reversed.

I tried using $r->finfo for file-test operators, but they didn't seem to
work.  If they start working or I figure out what's going on, I'll replace
$r->filename with $r->finfo.  This is pretty bizzarre.

=head1 TO DO

I'd like to implement the "deterministic" feature mentioned above.  
Philippe Chiasson has convinced me that it's a good idea.

=head1 BUGS

This uses some funny stuff to figure out when the currently executing
handler is the last handler in the chain.  As a result, code that
manipulates the handler list at runtime (using push_handlers and the
like) might produce mayhem.  Poke around a bit in the code before you 
try anything.

This will automatically return DECLINED when $r->filename points to a
directory.  This is just because in most cases this is what you want
(so that mod_dir can take care of the request), and because figuring
out the "right" way to handle directories seems pretty tough - the
right way would allow a directory indexing handler to be a filter, which
isn't possible now.  Suggestions are welcome.

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
