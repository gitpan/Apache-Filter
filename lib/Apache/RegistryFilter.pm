package Apache::RegistryFilter;

use strict;
use Apache::RegistryNG;
use Apache::Constants qw(:common);
use Symbol;
use vars qw($Debug @ISA);

@ISA = qw(Apache::RegistryNG);


sub readscript {
  my $pr = shift;
  
  # Get a filehandle to the Perl code
  my $fh;
  if (lc $pr->dir_config('Filter') eq 'on') {
    my $status;
    ($fh, $status) = $pr->filter_input();
    return $status unless $status == OK;
  } else {
    $fh = gensym;
    open $fh, $pr->filename or die $!;
  }
  
  local $/;
  return $pr->{'code'} = \(scalar <$fh>);
}

1;

__END__

=head1 NAME

Apache::RegistryFilter - run Perl scripts in an Apache::Filter chain

=head1 SYNOPSIS

 #in httpd.conf

 PerlModule Apache::RegistryFilter

 # Run the output of scripts through Apache::SSI
 <Files ~ "\.pl$">
  PerlSetVar Filter on
  SetHandler perl-script
  PerlHandler Apache::RegistryFilter Apache::SSI
 </Files>

 # Generate some Perl code using templates, then execute it
 <Files ~ "\.tmpl$">
  PerlSetVar Filter on
  SetHandler perl-script
  PerlHandler YourModule::GenCode Apache::RegistryFilter
 </Files>

=head1 DESCRIPTION

This module is a subclass of Apache::RegistryNG, and contains all of its
functionality.  The only difference between the two is that this
module can be used in conjunction with the Apache::Filter module,
whereas Apache::RegistryNG cannot.

It only takes a tiny little bit of code to make the filtering stuff
work, so perhaps it would be more appropriate for the code to be
integrated right into Apache::RegistryNG.

For information on how to set up filters, please see the codumentation
for Apache::Filter.

=head1 CAVEATS

This is a subclass of Apache::RegistryNG, not Apache::Registry (which
is not easily subclassible).  Apache::RegistryNG is supposed to be
functionally equivalent to Apache::Registry, but it's a little less
well-tested.

=head1 SEE ALSO

perl(1), mod_perl(3), Apache::Filter(3)

=head1 AUTHOR

Ken Williams <ken@forum.swarthmore.edu>

=cut
