#! perl

use Test2::Bundle::Extended;
use Test::Alien;

use Alien::XPA;
use System::Command;

# this modifies @PATH appropriately
alien_ok 'Alien::XPA';


run_ok( [ 'xpamb', '--version' ] )->exit_is( 0 )->err_like( qr/2.1.18/ );

my $xs = do { local $/; <DATA> };

xs_ok $xs, with_subtest {
    my ( $module ) = @_;
    my $xpamb = System::Command->new( 'xpamb' );
    ok $module->connected;
};

done_testing;

__DATA__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <xpa.h>
 
const char *
version(const char *class)
{
    char *names[1];
    char *messages[1];

    int found =
      XPAAccess( NULL,
                 'XPAMB:*',
                 NULL,
                 "g",
                 names,
                 messages,
                 1 );

    if ( names[1] ) free( names[1] );
    if ( messages[1] ) free( messages[1] );

    return found;
}
 
MODULE = TA_MODULE PACKAGE = TA_MODULE
 
int connected(class);
    const char *class;
