#!/usr/bin/perl

$|=1;

# This test will start up a real httpd server with Apache::Filter loaded in
# it, and make several requests on that server.

# You shouldn't have to change any of these, but you can if you want:
$ACONF = "/dev/null";
$CONF = "t/httpd.conf";
$SRM = "/dev/null";
$LOCK = "t/httpd.lock";
$PID = "t/httpd.pid";
$ELOG = "t/error_log";

######################################################################
################ Don't change anything below here ####################
######################################################################

#line 20 real.t

use vars qw(
     $ACONF   $CONF   $SRM   $LOCK   $PID   $ELOG
   $D_ACONF $D_CONF $D_SRM $D_LOCK $D_PID $D_ELOG
);
my $DIR = `pwd`;
chomp $DIR;
&dirify(qw(ACONF CONF SRM LOCK PID ELOG));
&read_httpd_loc();

use strict;
use vars qw($TEST_NUM $BAD %CONF);
use LWP::UserAgent;
use Carp;

my %requests = 
  (
   3  => 'simple.u',
   4  => 'dir/',  # A directory
   5  => 'determ.p',
   6  => 'perlfirst.pl',
   7  => 'own_handle.fh/t/docs.check/7',
   8  => 'change_headers.h',
   9  => 'send_headers.pl',
  );

my %special_tests = 
  (
   4  => sub { $_[0]->content =~ /index of/i },
   8  => sub { $_[0]->header('X-Test') eq 'success' },
  );

print "1.." . (2 + keys %requests) . "\n";

&report( &create_conf() );
my $result = &start_httpd;
&report( $result );

if ($result) {
  local $SIG{'__DIE__'} = \&kill_httpd;
  
  foreach my $testnum (sort {$a<=>$b} keys %requests) {
    my $ua = new LWP::UserAgent;
    my $req = new HTTP::Request('GET', "http://localhost:$CONF{port}/t/docs/$requests{$testnum}");
    my $response = $ua->request($req);
    
    &test_outcome($response, $testnum);
  }
  
  &kill_httpd();
  warn "\nSee $ELOG for failure details\n" if $BAD;
} else {
  warn "Aborting real.t";
}

&cleanup();

#############################

sub read_httpd_loc {
  open LOC, "t/httpd.loc" or die "t/httpd.loc: $!";
  while (<LOC>) {
    $CONF{$1} = $2 if /^(\w+)=(.*)/;
  }
}

sub start_httpd {
  print STDERR "Starting http server... ";
  unless (-x $CONF{httpd}) {
    warn("$CONF{httpd} doesn't exist or isn't executable.  Edit real.t if you want to test with a real apache server.\n");
    return;
  }
  &do_system("cp /dev/null $ELOG");
  &do_system("$CONF{httpd} -f $D_CONF") == 0
    or die "Can't start httpd: $!";
## Wait for server to start.
#  while (!-e $PID) { sleep 1 }
  print STDERR "ready. ";
  return 1;
}

sub kill_httpd {
# Need PID file to kill.
  return 1 if !-e $PID;

  &do_system("kill `cat $PID`");
  sleep 1;
  if (-e $PID) { &do_system("kill -TERM `cat $PID`") }
  &do_eval("unlink '$ELOG'") unless $BAD;
  return 1;
}

sub cleanup {
  &do_eval("unlink '$CONF'");
  return 1;
}

sub test_outcome {
  my $response = shift;
  my $i = shift;
  
  my ($text, $expected);
  my $ok = ($special_tests{$i} ?
            $special_tests{$i}->($response) :
            (($text = $response->content) eq ($expected = `cat t/docs.check/$i`)) );
  &report($ok);
  my $headers = $response->headers_as_string();
  print "Result: $headers\n$text\nExpected: $expected\n" if ($ENV{TEST_VERBOSE} and not $ok);
}

sub report {
  my $ok = shift;
  $TEST_NUM++;
  print "not "x(!$ok), "ok $TEST_NUM\n";
  $BAD++ unless $ok;
}

sub do_system {
  my $cmd = shift;
  print "$cmd\n";
  return system $cmd;
}

sub do_eval {
  my $code = shift;
  print "$code\n";
  my $result = eval $code;
  if ($@ or !$result) { carp "WARNING: $@" }
  return $result;
}

sub dirify {
  no strict('refs');
  foreach (@_) {
    # Turn $VAR into $D_VAR, which has an absolute path
    ${"D_$_"} = (${$_} =~ m,^/, ? ${$_} : "$DIR/${$_}");
  }
}

sub create_conf {
  my $file = $CONF;
  open (CONF, ">$file") or die "Can't create $file: $!" && return;

  # Figure out if modules need to be loaded.
  my $server_conf;
  for (`$CONF{httpd} -V`) {
  	if (/SERVER_CONFIG_FILE="(.*)"/) {
		$server_conf = $1;
		last;
	}
  }

  my @lines;
  if (open (SERVER_CONF, $server_conf)) { @lines = <SERVER_CONF>; close SERVER_CONF; }
  my @modules       =   grep /^\s*(Add|Load)Module/, @lines;
  my ($server_root) = (map /^\s*ServerRoot\s*(\S+)/, @lines);

  # Rewrite all modules to load from an absolute path.
  for (@modules) {
    s!(\s[^/\s][\S]+/)!$server_root/$1!;
  }

  # Directories where apache DSOs live.
  my (@module_dirs) = (map m!(/\S*/)!, @modules);

  # Have to make sure that dir, autoindex and perl are loaded.
  my @required  = qw(dir autoindex perl);

  my @l = `$CONF{httpd} -l`;
  my @compiled_in = map /^\s*(\S+)/, @l[1..@l-2];

  my @load;
  for my $module (@required) {
    if (!grep /$module/i, @compiled_in and !grep /$module/i, @modules) {
      push @load, $module;
    }
  }

  # Finally compute the directives to load modules that need to be loaded.
 MODULE: for my $module (@load) {
    for my $module_dir (@module_dirs) {
      if (-e "$module_dir/mod_$module.so") {
        push @modules, "LoadModule ${module}_module $module_dir/mod_$module.so\n"; next MODULE;
      } elsif (-e "$module_dir/lib$module.so") {
        push @modules, "LoadModule ${module}_module $module_dir/lib$module.so\n"; next MODULE;
      } elsif (-e "$module_dir/ApacheModule\u$module.dll") {
        push @modules, "LoadModule ${module}_module $module_dir/ApacheModule\u$module.dll\n"; next MODULE;
      }
    }
  }

  print CONF <<EOF;

#This file is created by the $0 script.

ServerType standalone
Port $CONF{port}
User $CONF{user}
Group $CONF{group}
ServerName localhost
DocumentRoot $DIR

@{[join '', @modules]}

ErrorLog $D_ELOG
PidFile $D_PID
AccessConfig $D_ACONF
ResourceConfig $D_SRM
LockFile $D_LOCK

DirectoryIndex index.html

<IfModule mod_log_config.c>
TransferLog /dev/null
</IfModule>

ScoreBoardFile /dev/null

TypesConfig /dev/null
AddType text/html .html

PerlRequire $DIR/Filter.pm
PerlRequire $DIR/lib/Apache/RegistryFilter.pm
PerlRequire $DIR/t/UC.pm
PerlRequire $DIR/t/Reverse.pm
PerlRequire $DIR/t/CacheTest.pm
PerlRequire $DIR/t/FHandle.pm
PerlRequire $DIR/t/ChangeHeader.pm


# Default - this includes directories too
SetHandler perl-script
PerlHandler Apache::UC Apache::Reverse


<Files ~ "\\.ur\$">
 SetHandler perl-script
 PerlHandler Apache::UC Apache::Reverse
</Files>

<Files ~ "\\.r\$">
 SetHandler perl-script
 PerlHandler Apache::Reverse
</Files>

<Files ~ "\\.p\$">
 SetHandler perl-script
 PerlHandler Apache::UC Apache::CacheTest
</Files>

<Files ~ "\\.fh\$">
 SetHandler perl-script
 PerlHandler Apache::FHandle
</Files>

<Files ~ "\\.h\$">
 SetHandler perl-script
 PerlHandler Apache::ChangeHeader
</Files>

<Files ~ "\\.pl\$">
 SetHandler perl-script
 PerlSetVar Filter on
 PerlHandler Apache::RegistryFilter Apache::UC
</Files>


<Location /perl-status>
 SetHandler perl-script
 PerlHandler Apache::Status
</Location>

EOF
	
  close CONF;
  
  chmod 0644, $file or warn "Couldn't 'chmod 0644 $file': $!";
  return 1;
}
