package AnyEvent::CNN;

use 5.008008;
use parent 'AnyEvent::Object';
use common::sense 2;m{
use strict;
use warnings;
};
use Carp;
use Scalar::Util 'weaken';
use Devel::Refcount 'refcount';
=head1 NAME

AnyEvent::CNN - ...

=cut

our $VERSION = '0.01'; $VERSION = eval($VERSION);

=head1 SYNOPSIS

    package Sample;
    use AnyEvent::CNN;

    ...

=head1 DESCRIPTION

    ...

=cut

use Event::Emitter;
use AnyEvent::Socket ();
use constant {
	INIT           => 1,
	CONNECTING     => 2,
	CONNECTED      => 4,
	DISCONNECTING  => 8,
	RECONNECTING   => 16,
	RESOLVE        => 32,
};

sub init {
	my $self = shift;
	$self->{debug} //= 1;
	$self->{timeout} ||= 30;
	$self->{reconnect} = 0.1 unless exists $self->{reconnect};
	if (exists $self->{server}) {
		($self->{host},$self->{port}) = split ':',$self->{server},2;
	} else {
		$self->{server} = join ':',$self->{host},$self->{port};
	}
}

use uni::perl ':dumper';
use AnyEvent::DNS;
use List::Util qw(min max);

sub _resolve {
	weaken( my $self = shift );
	my $cb = shift;
	$self->{_}{resolve} = AnyEvent::DNS::resolver->resolve($self->{host}, 'a', sub {
		$self or return;
		if (@_) {
			my $time = time;
			my @addrs;
			my $ttl = 2**32;
			for my $r (@_) {
				#  [$name, $type, $class, $ttl, @data],
				$ttl = min( $ttl, $time + $r->[3] );
				push @addrs, $r->[4];
			}
			$self->{addrs} = \@addrs;
			warn "Resolved $self->{host} into @addrs\n" if $self->{debug};
			$self->{addrs_ttr} = $ttl;
			$cb->(1);
		} else {
			$cb->(undef, "Not resolved `$self->{host}' ".($!? ": $!" : ""));
		}
		#warn dumper \@_;
	});
}

sub connect {
	weaken( my $self = shift );
	my $cb;$cb = pop if @_ and ref $_[-1] eq 'CODE';
	$self->{state} == CONNECTING and return;
	$self->state( CONNECTING );
	warn "Connecting to $self->{host}:$self->{port} with timeout $self->{timeout} (by @{[ (caller)[1,2] ]})...\n" if $self->{debug};
	# @rewrite s/sub {/cb connect {/;
	my $addr;
	if (my $addrs = $self->{addrs}) {
		if (time > $self->{addrs_ttr}) {
			warn "TTR $self->{addrs_ttr} expired (".time.")\n" if $self->{debug} > 1;
			delete $self->{addrs};
			$self->_resolve(sub {
				warn "Resolved: @_" if $self->{debug};
				$self or return;
				if (shift) {
					$self->state( INIT );
					$self->connect($cb);
				} else {
					$self->_on_connreset(@_);
				}
			});
			return;
		}
		push @$addrs,($addr = shift @$addrs);
		warn "Have addresses: @{ $addrs }, current $addr" if $self->{debug} > 1;
	}
	else {
		if ( $self->{host} =~ /\.\d+$/ and my $paddr = pack C4 => split '\.', $self->{host},4 ) {
			$self->{addrs} = [ $addr = Socket::inet_aton( $paddr ) ];
			$self->{addrs_ttr} = 2**32;
		} else {
			warn "Have no addrs, resolve $self->{host}\n" if $self->{debug};
			$self->_resolve(sub {
				warn "Resolved: @_" if $self->{debug};
				$self or return;
				if (shift) {
					$self->state( INIT );
					$self->connect($cb);
				} else {
					$self->_on_connreset(@_);
				}
			});
			return;
		}
	}
	warn "Connecting to $addr:$self->{port} with timeout $self->{timeout} (by @{[ (caller)[1,2] ]})...\n" if $self->{debug};
	$self->{_}{con} = AnyEvent::Socket::tcp_connect
		$addr,$self->{port},
		sub {
			$self or return;
			pop;
			warn "Connect: @_...\n" if $self->{debug};
			
			my ($fh,$host,$port) = @_;
			$self->_on_connect($fh,$host,$port,$cb);
		},
		sub {
			$self or return;
			$self->{timeout};
		};
	return;
}

sub _on_connect {
	my ($self,$fh,$host,$port,$cb) = @_;
	if ($fh) {
		$self->state( CONNECTED );
		$self->{fh} = $fh;
		$self->_on_connect_success($fh,$host,$port,$cb);
		#$self->{rw} = AnyEvent::RW->
	} else {
		warn "Connect failed: $!";
		if ($self->{reconnect}) {
			$self->event( connfail => "$!" );
		} else {
			$self->event( disconnected => "$!" );
		}
		$self->_reconnect_after;
		#warn "$!";
	}
}

sub _on_connreset {
	my ($self,$error) = @_;
	$self->disconnect($error);
	$self->_reconnect_after;
}

sub _on_connected_prepare {
	my ($self,$fh,$host,$port) = @_;
	
}

sub _on_connect_success {
	my ($self,$fh,$host,$port,$cb) = @_;
	$self->_on_connected_prepare($fh,$host,$port);
	$cb->($host,$port) if $cb;
	if ($self->handles('connected')) {
		$self->event( connected => ($host,$port) );
	}
	elsif (!$cb) {
		warn "connected not handled!" ;
	}
}

sub _reconnect_after {
	weaken( my $self = shift );
	if ($self->{reconnect}) {
		# Want to reconnect
		$self->state( RECONNECTING );
		warn "Reconnecting (state=$self->{state}) to $self->{host}:$self->{port} after $self->{reconnect}...\n" if $self->{debug};
		$self->{timers}{reconnect} = AE::timer $self->{reconnect},0, sub {
			$self or return;
			$self->state(INIT);
			$self->connect;
		};
	} else {
		$self->state(INIT);
		return;
	}
}

sub reconnect {
	my $self = shift;
	$self->disconnect;
	$self->state(RECONNECTING);
	$self->connect;
}

sub disconnect {
	my $self = shift;
	$self->state(DISCONNECTING);
	warn "Disconnecting (state=$self->{state}, pstate=$self->{pstate}) by @{[ (caller)[1,2] ]}\n" if $self->{debug};
	if ( $self->{pstate} &(  CONNECTED | CONNECTING ) ) {
		delete $self->{con};
	}
	$self->{h} and $self->{h}->destroy;
	delete $self->{_};
	delete $self->{timers};
	if ( $self->{pstate} == CONNECTED ) {
		warn "emit event disconnected";
		$self->event(disconnected => @_);
	}
	elsif ( $self->{pstate} == CONNECTING ) {
		$self->event(connfail => @_);
	}
	return;
}

sub state {
	my $self = shift;
	$self->{pstate} = $self->{state} if $self->{pstate} != $self->{state};
	$self->{state} = shift;
}



=head1 METHODS

=over 4

=item ...()

...

=back

=cut


=head1 AUTHOR

Mons Anderson, C<< <mons@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2012 Mons Anderson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=cut

1;
