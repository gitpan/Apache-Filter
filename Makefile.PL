use strict;
use ExtUtils::MakeMaker;
use lib 't/lib';  # distributed here until changes are incorporated into the real version
use Apache::test qw(have_httpd);

my %params = Apache::test->get_test_params();
chomp (my $cwd = `pwd`);
Apache::test->write_httpd_conf
    (%params,
     include => do {local $/; <DATA>});
*MY::test = sub { Apache::test->MM_test(%params) } if have_httpd();

my $module = 'Apache::Filter';
my ($name, $dir);
($name = $module) =~ s/.*::(\w+)/$1.pm/;
($dir = $module) =~ s/::/-/g;

WriteMakefile
  (
   'NAME'	=> $module,
   'VERSION_FROM' => $name, # finds $VERSION
   'dist' => { COMPRESS=>"gzip", 
	       SUFFIX=>"gz", 
               PREOP=>('rm -f README; '.
                       "pod2text -80 < $name > README; ".
                       "cp -f README $dir-\$(VERSION); "
                      ),
             },
   'clean' => {FILES => "t/httpd t/httpd.conf t/error_log"},
   'PREREQ_PM' => {
                   have_httpd() ? ('mod_perl' => '1.24_01') : (),
		  },
  );

##################################################################
__DATA__

PerlModule Apache::Filter
PerlModule Apache::RegistryFilter
PerlModule Apache::UC
PerlModule Apache::Reverse
PerlModule Apache::CacheTest
PerlModule Apache::FHandle
PerlModule Apache::ChangeHeader

# Default - this includes directories too
SetHandler perl-script
PerlHandler Apache::UC Apache::Reverse

PerlSetVar Filter on

<FilesMatch "\.ur$">
 SetHandler perl-script
 PerlHandler Apache::UC Apache::Reverse
</FilesMatch>

<FilesMatch "\.r$">
 SetHandler perl-script
 PerlHandler Apache::Reverse
</FilesMatch>

<FilesMatch "\.p$">
 SetHandler perl-script
 PerlHandler Apache::UC Apache::CacheTest
</FilesMatch>

<FilesMatch "\.fh$">
 SetHandler perl-script
 PerlHandler Apache::FHandle
</FilesMatch>

<FilesMatch "\.cp$">
 SetHandler perl-script
 PerlHandler Apache::RegistryFilter Apache::Compress
</FilesMatch>

<FilesMatch "\.h$">
 SetHandler perl-script
 PerlHandler Apache::ChangeHeader
</FilesMatch>

<FilesMatch "\.pl$">
 SetHandler perl-script
 PerlHandler Apache::RegistryFilter Apache::UC
</FilesMatch>

<FilesMatch "\.plr$">
 SetHandler perl-script
 PerlHandler Apache::RegistryFilter
</FilesMatch>

