package AnyEvent::Object;

use strict;
use AE;
use Scalar::Util 'weaken';

sub new {
	my $pk = shift;
	my $self = bless {@_},$pk;
	$self->init();
	$self;
}

# Timers bound to object life

sub periodic_stop;
sub periodic {
	weaken( my $self = shift );
	my $interval = shift;
	my $cb = shift;
	#warn "Create periodic $interval";
	$self->{timers}{int $cb} = AnyEvent->timer(
		after => $interval,
		interval => $interval,
		cb => sub {
			local *periodic_stop = sub {
				warn "Stopping periodic ".int $cb;
				delete $self->{timers}{int $cb}; undef $cb
			};
			$self or return;
			$cb->();
		},
	);
	defined wantarray and return AnyEvent::Util::guard(sub {
		delete $self->{timers}{int $cb};
		undef $cb;
	});
	return;
}

sub after {
	weaken( my $self = shift );
	my $interval = shift;
	my $cb = shift;
	#warn "Create after $interval";
	$self->{timers}{int $cb} = AnyEvent->timer(
		after => $interval,
		cb => sub {
			$self or return;
			delete $self->{timers}{int $cb};
			$cb->();
			undef $cb;
		},
	);
	defined wantarray and return AnyEvent::Util::guard(sub {
		delete $self->{timers}{int $cb};
		undef $cb;
	});
	return;
}

sub destroy {
	my ($self) = @_;
	$self->DESTROY;
	my $pk = ref $self;
	defined &{$pk.'::destroyed::AUTOLOAD'} or *{$pk.'::destroyed::AUTOLOAD'} = sub {};
	bless $self, "$pk::destroyed";
}

sub DESTROY {
	my $self = shift;
	warn "(".int($self).") Destroying $self" if $self->{debug};
	%$self = ();
}

1;