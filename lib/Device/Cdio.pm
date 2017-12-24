package Device::Cdio;
require 5.10.1;
#
#  See end for copyright and license.

=pod

=head1 NAME

Device::Cdio - Module for CD Input and Control library.

=cut

use version; $VERSION = qv('2.0.0');

=pod

=head1 SYNOPSIS

This encapsulates CD-ROM reading and control. Applications wishing to
be oblivious of the OS- and device-dependent properties of a CD-ROM
can use this library.

    use Device::Cdio;
    use Device::Cdio::Device;

    $cd_drives = Device::Cdio::get_devices($perlcdio::DRIVER_DEVICE);
    $cd_drives = Device::Cdio::get_devices_with_cap($perlcdio::FS_AUDIO, 0);
    foreach my $drive (@$cd_drives) {
       print "Drive $drive\n";
    }
    foreach my $driver_name (sort keys(%Device::Cdio::drivers)) {
       print "Driver $driver_name is installed.\n"
	  if Device::Cdio::have_driver($driver_name) and
  	  $driver_name !~ m{device|Unknown};
    }


=head1 DESCRIPTION

This is an Perl Object-Oriented interface to the GNU CD Input and
Control library, C<libcdio>, written in C. The library encapsulates
CD-ROM reading and control. Perl programs wishing to be oblivious of
the OS- and device-dependent properties of a CD-ROM can use this
library.

The encapsulation is done in two parts. The lower-level Perl
interface is called L<perlcdio> and is generated by SWIG.

This module uses C<perlcdio>. Actually, there are no objects in
module, but there are in its sub modules L<Device::Cdio::Device> and
L<Device::Cdio::Track>.

Although C<perlcdio> is perfectly usable on its own, it is expected
that Cdio is what most people will use. As C<perlcdio> more closely
models the C interface C<libcdio>, it is conceivable (if unlikely)
that die-hard libcdio C users who are very familiar with that
interface could prefer that.

=head2 CALLING ROUTINES

Routines accept named parameters as well as positional parameters.
For named parameters, each argument name is preceded by a dash. For
example:

    Device::Cdio::have_driver(-driver_id=>'GNU/Linux')

Each argument name is preceded by a dash.  Neither case nor order
matters in the argument list.  C<-driver_id>, C<-Driver_ID>, and
C<-DRIVER_ID> are all acceptable.  In fact, only the first argument
needs to begin with a dash.  If a dash is present in the first
argument, we assume dashes for the subsequent parameters.

In the documentation below and elsewhere in this package the parameter
name that can be used in this style of call is given in the parameter
list. For example, for C<close_tray> the documentation below reads:

   close_tray(drive=undef, driver_id=$perlcdio::DRIVER_UNKNOWN)
    -> ($drc, $driver_id)

So the parameter names are "drive", and "driver_id". Neither parameter
is required. If "drive" is not specified, a value of "undef" will be
used. And if "driver_id" is not specified, a value of
$perlcdio::DRIVER_UNKNOWN is used.

The older, more traditional style of positional parameters is also
supported. So the C<have_driver> example from above can also be written:

    Device::Cdio::have_driver('GNU/Linux')

Finally, since no parameter name can be confused with a an integer,
negative values will not get confused as a named parameter.

=cut

use warnings;
use strict;
use perlcdio;
use Carp;

use vars qw($VERSION @EXPORT_OK @EXPORT @ISA %drivers);
use Device::Cdio::Util qw( _check_arg_count _extra_args _rearrange );

@ISA = qw(Exporter);
@EXPORT    = qw(close_tray have_driver is_binfile is_cuefile is_nrg is_device
		is_tocfile convert_drive_cap_misc convert_drive_cap_read
		convert_drive_cap_write);
@EXPORT_OK = qw(_rearrange drivers);

# Note: the keys below match those the names returned by
# cdio_get_driver_name()

%Device::Cdio::drivers = (
    'Unknown'   => $perlcdio::DRIVER_UNKNOWN,
    'AIX'       => $perlcdio::DRIVER_AIX,
    'BSDI'      => $perlcdio::DRIVER_BSDI,
    'FreeBSD'   => $perlcdio::DRIVER_FREEBSD,
    'GNU/Linux' => $perlcdio::DRIVER_LINUX,
    'Solaris'   => $perlcdio::DRIVER_SOLARIS,
    'OS X'      => $perlcdio::DRIVER_OSX,
    'WIN32'     => $perlcdio::DRIVER_WIN32,
    'CDRDAO'    => $perlcdio::DRIVER_CDRDAO,
    'BIN/CUE'   => $perlcdio::DRIVER_BINCUE,
    'NRG'       => $perlcdio::DRIVER_NRG,
    'device'    => $perlcdio::DRIVER_DEVICE
    );

%Device::Cdio::read_mode2blocksize = (
    $perlcdio::READ_MODE_AUDIO => $perlcdio::CD_FRAMESIZE_RAW,
    $perlcdio::READ_MODE_M1F1  => $perlcdio::M2RAW_SECTOR_SIZE,
    $perlcdio::READ_MODE_M1F2  => $perlcdio::CD_FRAMESIZE,
    $perlcdio::READ_MODE_M2F1  => $perlcdio::M2RAW_SECTOR_SIZE,
    $perlcdio::READ_MODE_M2F2  => $perlcdio::CD_FRAMESIZE
    );

=pod

=head1 SUBROUTINES

=head2 close_tray

close_tray(drive=undef, driver_id=$perlcdio::DRIVER_UNKNOWN)
 -> ($drc, $driver_id)

close media tray in CD drive if there is a routine to do so.

In an array context, the driver return-code status and the
name of the driver used are returned.
In a scalar context, just the return code status is returned.

=cut

sub close_tray {
    my (@p) = @_;
    my($drive, $driver_id, @args) = _rearrange(['DRIVE','DRIVER_ID'], @p);
    return undef if _extra_args(@args);
    $driver_id = $perlcdio::DRIVER_UNKNOWN if !defined($driver_id);

    my ($drc, $found_driver_id) = perlcdio::close_tray($drive, $driver_id);
    ## Use wantarray to determine if we want one output or two.
    return wantarray ? ($drc, $found_driver_id) : $drc;
}

=pod

=head2 driver_strerror

driver_strerror(rc)->$errmsg

Convert a driver return code into a string text message.

=cut

sub driver_strerror {

    my (@p) = @_;
    my($drc, @args) = _rearrange(['RC'], @p);
    return undef if _extra_args(@args);

    if ($drc == $perlcdio::DRIVER_OP_SUCCESS) {
        return "No error";
    }
    if ($drc == $perlcdio::DRIVER_OP_ERROR) {
        return "Unspecified driver error";
    }
    if ($drc == $perlcdio::DRIVER_OP_UNINIT) {
        return "driver not initialized";
    }
    if ($drc == $perlcdio::DRIVER_OP_UNSUPPORTED) {
        return "Operation not supported on driver";
    }
    if ($drc == $perlcdio::DRIVER_OP_NOT_PERMITTED) {
        return "Operation not permitted with this driver";
    }
    if ($drc == $perlcdio::DRIVER_OP_BAD_PARAMETER) {
        return "Bad parameter passed in operation";
    }
    if ($drc == $perlcdio::DRIVER_OP_BAD_POINTER) {
        return "Invalid internal pointer";
    }
    if ($drc == $perlcdio::DRIVER_OP_NO_DRIVER) {
        return "No driver";
    }
    return sprintf  "Unclassifed driver return code %d", $drc;
}

=pod

=head2 get_default_device_driver

get_default_device_driver(driver_id=DRIVER_DEVICE)-> ($device, $driver)

Return a string containing the default CD device if none is specified.
if driver_id is DRIVER_UNKNOWN or DRIVER_DEVICE then find a suitable
one set the default device for that.

undef is returned as the driver if we couldn't get a default device.

=cut

sub get_default_device_driver {
    my (@p) = @_;
    my($driver_id, @args) = _rearrange(['DRIVER_ID'], @p);
    return undef if _extra_args(@args);
    $driver_id = $perlcdio::DRIVER_DEVICE if !defined($driver_id);
    my($drive, $out_driver_id) =
	perlcdio::get_default_device_driver($driver_id);
    return wantarray ? ($drive, $out_driver_id) : $drive;
}

=pod

=head2 get_devices

$revices = get_devices(driver_id=$Cdio::DRIVER_UNKNOWN);

Return an array of device names. If you want a specific devices for a
driver, give that device. If you want hardware devices, give
$perlcdio::DRIVER_DEVICE and if you want all possible devices, image
drivers and hardware drivers give $perlcdio::DRIVER_UNKNOWN.  undef is
returned if we couldn't return a list of devices.

In some situations of drivers or OS's we can't find a CD device if
there is no media in it and it is possible for this routine to return
undef even though there may be a hardware CD-ROM.

=cut

sub get_devices {
    my (@p) = @_;
    my($driver_id, @args) = _rearrange(['DRIVER_ID'], @p);
    return undef if _extra_args(@args);
    $driver_id = $perlcdio::DRIVER_DEVICE if !defined($driver_id);
    my $ret = perlcdio::get_devices($driver_id);
    return wantarray ? @$ret : $ret;
}

=pod

=head2 get_devices_ret

get_devices_ret($driver_id)->(@devices, $driver_id)

Like get_devices, but we may change the p_driver_id if we were given
$perlcdio::DRIVER_DEVICE or $perlcdio::DRIVER_UNKNOWN.  This is
because often one wants to get a drive name and then I<open> it
afterwords. Giving the driver back facilitates this, and speeds things
up for libcdio as well.

=cut

sub get_devices_ret {
    my (@p) = @_;
    my($driver_id, @args) = _rearrange(['DRIVER_ID'], @p);
    return undef if _extra_args(@args);
    $driver_id = $perlcdio::DRIVER_DEVICE if !defined($driver_id);
    my $ret = perlcdio::get_devices_ret($driver_id);
    return wantarray ? @$ret : $ret;
}

=pod

=head2 get_devices_with_cap

$devices = get_devices_with_cap($capabilities, $any);

Get an array of device names in search_devices that have at least
the capabilities listed by the capabilities parameter.

If "any" is set false then ALL capabilities listed in the extended
portion of capabilities (i.e. not the basic filesystem) must be
satisfied. If "any" is set true, then if any of the capabilities
matches, we call that a success.

To find a CD-drive of any type, use the mask $perlcdio::FS_MATCH_ALL.

The array of device names is returned or undef if we couldn't get a
default device.  It is also possible to return a () but after
This means nothing was found.

=cut

sub get_devices_with_cap {
    my (@p) = @_;
    my($cap, $any, @args) = _rearrange(['CAPABILITIES', 'ANY'], @p);
    return undef if _extra_args(@args);
    $any = 1 if !defined($any);
    my $ret = perlcdio::get_devices_with_cap($cap, $any);
    return wantarray ? @$ret : $ret;
}

=pod

=head2 get_devices_with_cap_ret

Like get_devices_with_cap but we return the driver we found as
well. This is because often one wants to search for kind of drive and
then *open* it afterward. Giving the driver back facilitates this,
and speeds things up for libcdio as well.

=cut

sub get_devices_with_cap_ret {
    my (@p) = @_;
    my($cap, $any, @args) = _rearrange(['CAPABILITIES', 'ANY'], @p);
    return undef if _extra_args(@args);
    $any = 1 if !defined($any);
    my $ret = perlcdio::get_devices_with_cap($cap, $any);
    return wantarray ? @$ret : $ret;
}

=pod

=head2 have_driver

have_driver(driver_id) -> bool

Return 1 if we have driver driver_id. undef is returned if driver_id
is invalid. driver_id can either be an integer driver name defined in
perlcdio or a string as defined in the hash %drivers.

=cut

sub have_driver {
    my (@p) = @_;
    my($driver_id) = _rearrange(['DRIVER_ID'], @p);
    # driver_id can be an integer representing an enum value
    # or a string of the driver name in the drivers dictionary.
    return perlcdio::have_driver($driver_id)
	if $driver_id =~ m/^\d+$/;
    return perlcdio::have_driver($drivers{$driver_id})
	if defined($drivers{$driver_id});
    return undef;
}

=pod

=head2 is_binfile

is_binfile(binfile)->cue_name

Determine if binfile is the BIN file part of a CDRWIN Compact
Disc image.

Return the corresponding CUE file if bin_name is a BIN file or
undef if not a BIN file.

=cut

sub is_binfile {
    my (@p) = @_;
    my($file_name) = _rearrange(['BINFILE'], @p);
    return perlcdio::is_binfile($file_name);
}

=pod

=head2 is_cuefile

is_cuefile(cuefile)->bin_name

Determine if cuefile is the CUE file part of a CDRWIN Compact
Disc image.

Return the corresponding BIN file if cue_name is a CUE file or
undef if not a CUE file.

=cut

sub is_cuefile {
    my (@p) = @_;
    my($file_name) = _rearrange(['CUEFILE'], @p);
    return perlcdio::is_cuefile($file_name);
}

=pod

=head2 is_device

is_device(source, driver_id=$perlcdio::DRIVER_UNKNOWN)->bool

Return True if source refers to a real hardware CD-ROM.

=cut

sub is_device {

    my (@p) = @_;
    my($source, $driver_id) = _rearrange(['SOURCE', 'DRIVER_ID'], @p);

    $driver_id=$perlcdio::DRIVER_UNKNOWN if !defined($driver_id);
    return perlcdio::is_device($source, $driver_id);
}

=pod

=head2 is_nrg

is_nrg(nrgfile)->bool

Determine if nrgfile is a Nero NRG file disc image.

=cut

sub is_nrg {
    my (@p) = @_;
    my($file_name) = _rearrange(['NRGFILE'], @p);
    return perlcdio::is_nrg($file_name);
}

=pod

=head2 is_tocfile

is_tocfile(tocfile_name)->bool

Determine if tocfile_name is a cdrdao CD disc image.

=cut

sub is_tocfile {

    my (@p) = @_;
    my($tocfile) = _rearrange(['TOCFILE'], @p);
    return perlcdio::is_tocfile($tocfile);
}

=pod

=head2 convert_drive_cap_misc

convert_drive_cap_misc(bitmask)->hash_ref

Convert bit mask for miscellaneous drive properties
into a hash reference of drive capabilities

=cut

sub convert_drive_cap_misc {

    my (@p) = @_;
    my($bitmask) = _rearrange(['BITMASK'], @p);

    my %result=();
    $result{DRIVE_CAP_ERROR} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_ERROR;
    $result{DRIVE_CAP_UNKNOWN} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_UNKNOWN;
    $result{DRIVE_CAP_MISC_CLOSE_TRAY} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_CLOSE_TRAY;
    $result{DRIVE_CAP_MISC_EJECT} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_EJECT;
    $result{DRIVE_CAP_MISC_LOCK} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_LOCK;
    $result{DRIVE_CAP_MISC_SELECT_SPEED} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_SELECT_SPEED;
    $result{DRIVE_CAP_MISC_SELECT_DISC} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_SELECT_DISC;
    $result{DRIVE_CAP_MISC_MULTI_SESSION} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_MULTI_SESSION;
    $result{DRIVE_CAP_MISC_MEDIA_CHANGED} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_MEDIA_CHANGED;
    $result{DRIVE_CAP_MISC_RESET} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_RESET;
    $result{DRIVE_CAP_MISC_FILE} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_MISC_FILE;
    my $ref = \%result;
    return $ref;
}

=pod

=head2 convert_drive_cap_read

convert_drive_cap_read($bitmask)->hash_ref

Convert bit mask for read drive properties
into a hash reference of drive capabilities

=cut

sub convert_drive_cap_read {

    my (@p) = @_;
    my($bitmask) = _rearrange(['BITMASK'], @p);

    my %result=();
    $result{DRIVE_CAP_READ_AUDIO} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_AUDIO;
    $result{DRIVE_CAP_READ_CD_DA} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_CD_DA;
    $result{DRIVE_CAP_READ_CD_G} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_CD_G;
    $result{DRIVE_CAP_READ_CD_R} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_CD_R;
    $result{DRIVE_CAP_READ_CD_RW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_CD_RW;
    $result{DRIVE_CAP_READ_DVD_R} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_R;
    $result{DRIVE_CAP_READ_DVD_PR} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_PR;
    $result{DRIVE_CAP_READ_DVD_RAM} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_RAM;
    $result{DRIVE_CAP_READ_DVD_ROM} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_ROM;
    $result{DRIVE_CAP_READ_DVD_RW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_RW;
    $result{DRIVE_CAP_READ_DVD_RPW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_DVD_RPW;
    $result{DRIVE_CAP_READ_C2_ERRS} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_C2_ERRS;
    $result{DRIVE_CAP_READ_MODE2_FORM1} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_MODE2_FORM1;
    $result{DRIVE_CAP_READ_MODE2_FORM2} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_MODE2_FORM2;
    $result{DRIVE_CAP_READ_MCN} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_MCN;
    $result{DRIVE_CAP_READ_ISRC} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_READ_ISRC;
    my $ref = \%result;
    return $ref;
}

=pod

=head2 convert_drive_cap_write

convert_drive_cap_write($bitmask)->hash_ref

=cut

sub convert_drive_cap_write {

    my (@p) = @_;
    my($bitmask) = _rearrange(['BITMASK'], @p);

    my %result=();
    $result{DRIVE_CAP_WRITE_CD_R} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_CD_R;
    $result{DRIVE_CAP_WRITE_CD_RW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_CD_RW;
    $result{DRIVE_CAP_WRITE_DVD_R} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_DVD_R;
    $result{DRIVE_CAP_WRITE_DVD_PR} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_DVD_PR;
    $result{DRIVE_CAP_WRITE_DVD_RAM} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_DVD_RAM;
    $result{DRIVE_CAP_WRITE_DVD_RW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_DVD_RW;
    $result{DRIVE_CAP_WRITE_DVD_RPW} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_DVD_RPW;
    $result{DRIVE_CAP_WRITE_MT_RAINIER} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_MT_RAINIER;
    $result{DRIVE_CAP_WRITE_BURN_PROOF} = 1
	if $bitmask & $perlcdio::DRIVE_CAP_WRITE_BURN_PROOF;
    my $ref = \%result;
    return $ref;
}

1; # Magic true value requred at the end of a module

__END__

=pod

=head1 SEE ALSO

L<Device::Cdio::Device> for device objects and L<Device::Cdio::Track>
for track objects and L<Device::Cdio::ISO9660> for working with ISO 9660
filesystems.

L<perlcdio> is the lower-level interface to libcdio.

L<http://www.gnu.org/software/libcdio/doxygen/files.html> is
documentation via doxygen for C<libcdio>.

=head1 AUTHORS

Rocky Bernstein

=head1 COPYRIGHT

Copyright (C) 2006, 2011 Rocky Bernstein <rocky@cpan.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<The GNU General Public
License|http://www.gnu.org/licenses/#GPL>.

=cut
