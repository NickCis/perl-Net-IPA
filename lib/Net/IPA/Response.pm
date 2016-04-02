# Net::IPA.pm -- Perl 5 interface of the (Free)IPA JSON-RPC API
#
#   for more information about this api see: https://vda.li/en/posts/2015/05/28/talking-to-freeipa-api-with-sessions/
#
#   written by Nicolas Cisco (https://github.com/nickcis)
#   https://github.com/nickcis/perl-Net-IPA
#
#     Copyright (c) 2016 Nicolas Cisco. All rights reserved.
#     Licensed under the GPLv2, see LICENSE file for more information.

package Net::IPA::Response;

use strict;
use JSON;

use vars qw($AUTOLOAD);
use constant {
	InternalServerError => -500,
	ReadTimeout => -520,
	OptionError => 3005,
	RequirementError => 3007,
	NotFound => 4001,
	DuplicateEntry => 4002,
	EmptyModlist => 4202, # e.g: user_mod with no modifications to the db
};

#** Static method for creating a Response from an http response
sub from_http_response
{
	my ($class, $response) = @_;
	$response = $class if(1 == scalar @_);
	return new Net::IPA::Response(from_json($response->decoded_content)) if($response->is_success);

	my %error = (
		code => 0-($response->code),
		name => 'HttpError',
		message => 'Code: ' . $response->code . ' (' . $response->message() . ')',
	);

	$error{code} = Net::IPA::Response::ReadTimeout if($response->code() == 500 && $response->message() =~ /read timeout/);
	return new Net::IPA::Response({
		error => \%error
	});
}

sub new
{
	my ($proto, $result) = @_;
	my $class = ref($proto) || $proto;
	my $self = $result || {};
	bless $self, $class;
	return $self;
}

#** Returns a string explaining the error.
# If it's not an error, it returns an empty string
# @return String explaining the error
#*
sub error_string
{
	my ($self) = @_;
	return "" unless($self->is_error());
	return "undef" unless(%$self);
	return "code: " . $self->error_code() ." (" . $self->error_name() .") " . $self->error_message();
}

sub error_code
{
	my ($self) = @_;
	return $self->{error_code} if($self->{error_code});
	return $self->{error}->{code} if(ref($self->{error}) eq 'HASH' and $self->{error}->{code});
	return 0;
}

sub error_name
{
	my ($self) = @_;
	return $self->{error_name} if($self->{error_name});
	return $self->{error}->{name} if(ref($self->{error}) eq 'HASH' and $self->{error}->{name});
	return '';
}

sub error_message
{
	my ($self) = @_;
	return $self->{error}->{message} if(ref($self->{error}) eq 'HASH' and $self->{error}->{message});
	return $self->{error} if($self->{error});
	return '';
}

#** Checks if the response is an error.
# @returns 1: If error, 0: if not error
#*
sub is_error
{
	my ($self) = @_;
	return 1 if(
		not(%$self) ||
		$self->error_code() ||
		$self->error_name() ||
		$self->error_message()
	);
	return 0;
}

sub AUTOLOAD
{
	my ($self) = @_;

	my $sub = $AUTOLOAD;
	(my $name = $sub) =~ s/.*:://;

	if(ref($self->{result}) eq 'HASH'){
		my $value = $self->{result}->{$name};
		return  ref($value) eq 'ARRAY' ? $value->[0] : $value;
	};


	return undef;
}

package Net::IPA::Response::Batch;
use parent qw(Net::IPA::Response);
use JSON;

sub from_http_response
{
	my ($class, $response) = @_;
	$response = $class if(1 == scalar @_);
	return Net::IPA::Response::from_http_response($response) unless($response->is_success);

	return new Net::IPA::Response::Batch(from_json($response->decoded_content));
}

sub count
{
	my ($self) = @_;
	return scalar @{$self->{result}->{results}};
}

sub length
{
	my ($self) = @_;
	return $self->count;
}

sub get
{
	my ($self, $i) = @_;
	return map { new Net::IPA::Response($_) } @{$self->{result}->{results}} if(1 == scalar @_);
	return undef if($self->count >= $i);
	return new Net::IPA::Response($self->{result}->{results}->{$i});
}

1;
