#! perl

use Test2::Bundle::Extended;
use Test::Alien;

use Alien::XPA;
use Action::Retry 'retry';
use Child 'child';

# so we can catch segv's
plan(6);


# this modifies @PATH appropriately
alien_ok 'Alien::XPA';

my $run = run_ok( [ 'xpaaccess', '--version' ] );
$run->exit_is( 0 )
  or bail_out( "can't find xpaaccess. must stop now" );
my $version = $run->out;

my $xpamb_already_running = run_ok( [qw[ xpaaccess XPAMB:* ]] )->out eq 'yes';

our $child;
our $xpamb_started = 0;

unless ( $xpamb_already_running ) {

    if ( $^O eq 'MSWin32' ) {

        require Win32::Process;
        require File::Which;

        use subs
          qw( Win32::Process::NORMAL_PRIORITY_CLASS Win32::Process::CREATE_NO_WINDOW);

        Win32::Process::Create(
            $child,
            File::Which::which( "xpamb" ),
            "xpamb",
            0,
            Win32::Process::NORMAL_PRIORITY_CLASS
              | Win32::Process::CREATE_NO_WINDOW,
            "."
        ) || die $^E;

    }
    else {

        $child = child { exec( 'xpamb' ) };
    }

    retry {
        die
          unless $xpamb_started = qx/xpaaccess 'XPAMB:*'/ =~ 'yes';
    };

    bail_out( "unable to access launched xpamb" )
      unless $xpamb_started;
}

my $xs = do { local $/; <DATA> };
xs_ok $xs, with_subtest {
    my ( $module ) = @_;

    ok $module->connected, "connected to xpamb";

    $version = $module->version;

    is( $module->version, $version,
        "library version same as command line version" );
};

END {

    # try to shut xpamb down nicely
    if ( $xpamb_started ) {

        system( qw[ xpaset -p xpamb -exit ] );

        retry {
            die
              if qx/xpaaccess 'XPAMB:*'/ =~ 'yes';
        };
    }

    # be firm if necessary
    if ( $^O eq 'MSWin32' ) {

        use subs qw( Win32::Process::STILL_ACTIVE );

        $child->GetExitCode( my $exitcode );
        $child->Kill( 0 ) if $exitcode == Win32::Process::STILL_ACTIVE;
    }

    else {
        $child->kill( 9 ) unless $child->is_complete;
    }
}

__DATA__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <xpa.h>

const char *
connected(const char *class)
{
    char *names[1];
    char *messages[1];

    int found =
      XPAAccess( NULL,
                 "XPAMB:*",
                 NULL,
                 "g",
                 &names,
                 &messages,
                 1 );

    if ( found && names[0] && strcmp( names[0], "XPAMB:xpamb" ) ) found = 1;
    else found = 0;

    if ( names[0] ) free( names[0] );
    if ( messages[0] ) free( messages[0] );

    return found;
}

const char * version( const char* class ) {
    const char* version = XPA_VERSION;
    return version;
}

MODULE = TA_MODULE PACKAGE = TA_MODULE

int connected(class);
    const char *class;

const char* version(class);
    const char *class;
