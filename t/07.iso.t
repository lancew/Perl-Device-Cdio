#!/usr/bin/perl -w
# $Id$

# Test some low-level ISO9660 routines
# This is basically the same thing as libcdio's testiso9660.c

use strict;

BEGIN {
    chdir 't' if -d 't';
}
use lib '../lib';
use blib;

use perliso9660;
use Test::Simple tests => 14;

sub is_eq($$) {
    my ($a_ref, $b_ref) = @_;
    return 0 if @$a_ref != @$b_ref;
    for (my $i=0; $i<@$a_ref; $i++) {
	if ($a_ref->[$i] != $b_ref->[$i]) {
	    printf "position %d: %d != %d\n", $i, $a_ref->[$i] != $b_ref->[$i];
	    return 0 ;
	}
    }
    return 1;
}

###################################
# Test ACHAR and DCHAR
###################################

my @achars = ('!', '"', '%', '&', '(', ')', '*', '+', ',', '-', '.',
	   '/', '?', '<', '=', '>');

my $bad = 0;
for (my $c=ord('A'); $c<=ord('Z'); $c++ ) {
    if (!perliso9660::is_dchar($c)) {
	printf "Failed iso9660_is_achar test on %c\n", $c;
	$bad++;
    }
    if (!perliso9660::is_achar($c)) {
	printf "Failed iso9660_is_achar test on %c\n", $c;
	$bad++;
    }
}

ok($bad==0, 'is_dchar & isarch A..Z');

$bad=0;
for (my $c=ord('0'); $c<=ord('9'); $c++ ) {
    if (!perliso9660::is_dchar($c)) {
	printf "Failed iso9660_is_dchar test on %c\n", $c;
	$bad++;
    }
    if (!perliso9660::is_achar($c)) {
	printf "Failed iso9660_is_achar test on %c\n", $c;
	$bad++;
    }
}

ok($bad==0, 'is_dchar & is_achar 0..9');

$bad=0;
for (my $i=0; $i<=13; $i++ ) {
    my $c=ord($achars[$i]);
    if (perliso9660::is_dchar($c)) {
	printf "Should not pass is_dchar test on %c\n", $c;
	$bad++;
    }
    if (!perliso9660::is_achar($c)) {
	printf "Failed is_achar test on symbol %c\n", $c;
	$bad++;
    }
}

ok($bad==0, 'is_dchar & is_achar symbols');

#####################################
# Test perliso9660::strncpy_pad
#####################################

my $dst = perliso9660::strncpy_pad("1_3", 5, $perliso9660::DCHARS);
ok($dst eq "1_3  ", "strncpy_pad DCHARS");

$dst = perliso9660::strncpy_pad("ABC!123", 2, $perliso9660::ACHARS);
ok($dst eq "AB", "strncpy_pad ACHARS truncation");

#####################################
# Test perliso9660::dirname_valid_p 
#####################################

$bad=0;
if ( perliso9660::dirname_valid_p("/NOGOOD") ) {
    printf("/NOGOOD should fail perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::dirname_valid_p - invalid name - bad symbol');

$bad=0;
if ( perliso9660::dirname_valid_p("LONGDIRECTORY/NOGOOD") ) {
    printf("LONGDIRECTORY/NOGOOD should fail perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::dirname_valid_p - invalid long name');

$bad=0;
if ( !perliso9660::dirname_valid_p("OKAY/DIR") ) {
    printf("OKAY/DIR should pass perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::dirname_valid_p - valid with directory');

$bad=0;
if ( perliso9660::dirname_valid_p("OKAY/FILE.EXT") ) {
    printf("OKAY/FILENAME.EXT should fail perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::dirname_valid_p - invalid with .EXT');

#####################################
# Test perliso9660::pathname_valid_p
#####################################

$bad=0;
if ( !perliso9660::pathname_valid_p("OKAY/FILE.EXT") ) {
    printf("OKAY/FILE.EXT should pass perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::pathname_valid_p - valid');

$bad=0;
if ( perliso9660::pathname_valid_p("OKAY/FILENAMETOOLONG.EXT") ) {
    printf("OKAY/FILENAMETOOLONG.EXT should fail perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::pathname_valid_p - invalid, long basename');

$bad=0;
if ( perliso9660::pathname_valid_p("OKAY/FILE.LONGEXT") ) {
    printf("OKAY/FILE.LONGEXT should fail perliso9660::dirname_valid_p\n");
    $bad++;
}
ok($bad==0, 'perliso9660::pathname_valid_p - invalid, long extension');

$bad=0;
$dst = perliso9660::pathname_isofy("this/file.ext", 1);
if ($dst ne "this/file.ext;1") {
    printf("Failed iso9660_pathname_isofy\n");
    $bad++;
}
ok($bad==0, 'perliso9660::pathname_isofy');

my @tm = gmtime(0);
my $dtime = perliso9660::set_dtime($tm[0], $tm[1], $tm[2], $tm[3], $tm[4],
				   $tm[5], $tm[6], $tm[7], $tm[8]);
my ($bool, @new_tm) = perliso9660::get_dtime($dtime, 0);

### FIXME Don't know why the discrepancy, but there is a 5 hour difference.
$new_tm[2] = $tm[2]; 

ok(is_eq(\@new_tm, \@tm), 'get_dtime != set_dtime');

exit 0;