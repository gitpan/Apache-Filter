package Apache::PerlRunFilter;

use strict;
use Apache::PerlRun;
use Apache::Constants qw(:common);
use Symbol;
use vars qw($Debug @ISA);

@ISA = qw(Apache::PerlRun);


sub readscript {
  my $pr = shift;
  
  my $fh = $pr->{'fh'};
  local $/;
  return $pr->{'code'} = \(scalar <$fh>);
}

sub handler {
    my ($package, $r) = @_;
    ($package, $r) = (__PACKAGE__, $package) unless $r;
    my $pr = $package->new($r);
    my $rc = $pr->can_compile;
    return $rc unless $rc == OK;

    # Get a filehandle to the Perl code
    if (lc $r->dir_config('Filter') eq 'on') {
      my ($fh, $status) = $r->filter_input();
      return $status unless $status == OK;
      $pr->{'fh'} = $fh;
    } else {
      $pr->{'fh'} = gensym;
      open $pr->{'fh'}, $r->filename or die $!;
    }

    # After here is the same as PerlRun.pm...

    my $package = $pr->namespace;
    my $code = $pr->readscript;
    $pr->parse_cmdline($code);

    $pr->set_script_name;
    $pr->chdir_file;
    my $line = $pr->mark_line;
    my %orig_inc = %INC;
    my $eval = join '',
		    'package ',
		    $package,
		    ';use Apache qw(exit);',
                    $line,
		    $$code,
                    "\n";
    $rc = $pr->compile(\$eval);

    $pr->chdir_file("$Apache::Server::CWD/");
    #in case .pl files do not declare package ...;
    for (keys %INC) {
	next if $orig_inc{$_};
	next if /\.pm$/;
	delete $INC{$_};
    }

    if(my $opt = $r->dir_config("PerlRunOnce")) {
	$r->child_terminate if lc($opt) eq "on";
    }

    {   #flush the namespace
	no strict;
	my $tab = \%{$package.'::'};
        foreach (keys %$tab) {
	    if(defined &{$tab->{$_}}) {
		undef_cv_if_owner($package, \&{$tab->{$_}});
	    } 
	}
	%$tab = ();
    }

    return $rc;
}

sub undef_cv_if_owner {
    return unless $INC{'B.pm'};
    my($package, $cv) = @_;
    my $obj    = B::svref_2object($cv);
    my $stash  = $obj->GV->STASH->NAME;
    return unless $package eq $stash;
    undef &$cv;
}


1;

__END__

=head1 NAME

Apache::PerlRun - Run unaltered CGI scripts under mod_perl

=head1 SYNOPSIS

 #in httpd.conf

 Alias /cgi-perl/ /perl/apache/scripts/ 
 PerlModule Apache::PerlRun

 <Location /cgi-perl>
 SetHandler perl-script
 PerlHandler Apache::PerlRun
 Options +ExecCGI 
 #optional
 PerlSendHeader On
 ...
 </Location>

=head1 DESCRIPTION

This module's B<handler> emulates the CGI environment,
allowing programmers to write scripts that run under CGI or
mod_perl without change.  Unlike B<Apache::Registry>, the
B<Apache::PerlRun> handler does not cache the script inside of a
subroutine.  Scripts will be "compiled" every request.  After the
script has run, it's namespace is flushed of all variables and
subroutines.

The B<Apache::Registry> handler is much faster than
B<Apache::PerlRun>.  However, B<Apache::PerlRun> is much faster than
CGI as the fork is still avoided and scripts can use modules which
have been pre-loaded at server startup time.  This module is meant for
"Dirty" CGI Perl scripts which relied on the single request lifetime
of CGI and cannot run under B<Apache::Registry> without cleanup.

=head1 CAVEATS

If your scripts still have problems running under the I<Apache::PerlRun>
handler, the I<PerlRunOnce> option can be used so that the process running
the script will be shutdown.  Add this to your httpd.conf:

 <Location ...>
 PerlSetVar PerlRunOnce On
 ...
 </Location>

=head1 SEE ALSO

perl(1), mod_perl(3), Apache::Registry(3)

=head1 AUTHOR

Doug MacEachern

=cut
