use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

$|=1;

my $default = $ENV{'APACHE'} || which('apache') || which('httpd') || '/usr/lib/httpd/httpd';

print("\nFor testing purposes, please give the full path to an httpd\n",
      "with mod_perl enabled.  The path defaults to \$ENV{APACHE}, if present.\n");

my %conf;

do {
  print "\n [$default]: ";
  chomp ($conf{httpd} = <STDIN>);
  $conf{httpd} ||= $default;
} until -e $conf{httpd} || !print("$conf{httpd} not found\n");


# Get default user (apache doesn't like to run as root, special-case it)
$default = ($< == 0 ? 'nobody' : getpwuid($<) || 'nobody');
print "User to run tests under [$default]: ";
chomp ($conf{user} = <STDIN>);
$conf{user} ||= $default;

$default = getgrgid((getpwnam($conf{user}))[3]) || "nobody";
print "Group to run tests under [$default]: ";
chomp ($conf{group} = <STDIN>);
$conf{group} ||= $default;

$default = 8228;
print "Port to run tests under [$default]: ";
chomp ($conf{port} = <STDIN>);
$conf{port} ||= $default;


open LOC, ">t/httpd.loc" or die "can't write t/httpd.loc: $!";
print LOC map {"$_=$conf{$_}\n"} keys %conf;
close LOC;

my $module = 'Apache::Filter';
my ($name, $dir);
($name = $module) =~ s/.*::(\w+)/$1.pm/;
($dir = $module) =~ s/::/-/g;

# Find an executable in the PATH.
sub which {
  foreach (map { "$_/$_[0]" } split /:/, $ENV{PATH}) {
    next unless m,^/,;
    return $_ if -x;
  }
}



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
   'clean' => {FILES => "t/httpd.loc"},
  );
