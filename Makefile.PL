use ExtUtils::MakeMaker;
use lib 't/lib';  # distributed here until changes are incorporated into the real version
use Apache::test;

my %params = Apache::test->get_test_params();
chomp (my $cwd = `pwd`);
Apache::test->write_httpd_conf
    (%params,
     include => do {local $/; <DATA>});
*MY::test = sub { Apache::test->MM_test(%params) };

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
               PREOP=>('rm -f Changes README; '.
                       "cvs log $name | \$(PERL) -MCVS::Parse -e prettylog > Changes; ".
                       "pod2text -80 < $name > README; ".
                       "cp -f Changes README $dir-\$(VERSION); "
                      ),
             },
   'clean' => {FILES => "t/httpd t/httpd.conf t/error_log"},
   'PREREQ_PM' => {
                   'mod_perl' => '1.24_01',
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

<FilesMatch "\.h$">
 SetHandler perl-script
 PerlHandler Apache::ChangeHeader
</FilesMatch>

<FilesMatch "\.pl$">
 SetHandler perl-script
 PerlSetVar Filter on
 PerlHandler Apache::RegistryFilter Apache::UC
</FilesMatch>

